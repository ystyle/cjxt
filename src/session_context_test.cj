// 会话上下文视图测试（cjreg Q2「登录后才显示管理入口」的框架地基）
//
// 覆盖四件事：
// 1. SessionContext 接口的默认实现（属性/方法派生）+ 默认类 SessionContextState 的响应式
// 2. 写入路径（ActionContext.setContext / 令牌恢复）会通知订阅者 → 驱动重渲染
// 3. 注入：App 不配置时用默认实现；App.sessionContext<T>() 可换成应用自己的实现
// 4. 令牌恢复后的就地重渲能读到新上下文（刷新带 token 的公开页 → 入口出现）
package cjxt

import std.collection.*
import std.reflect.*
import std.unittest.*
import std.unittest.testmacro.*

// 测试用应用态（验证 initStates 同时初始化应用态与会话上下文）
class CtxTestState <: AppState {
    var flag: Int64 = 0
}

// ---- 应用自定义实现：演示"接口可替换" ----
// 在默认行为之上加：类型化角色属性 + 上下文变更审计
class MySessionContext <: SessionContext {
    let data: HashMap<String, String>
    let version: Signal<Int64>
    var changedTotal = Signal<Int64>(0)

    public init(data: HashMap<String, String>) {
        this.data = data
        this.version = Signal<Int64>(1)
    }

    public func get(key: String): Option<String> {
        this.version.get()
        this.data.get(key)
    }

    public prop raw: HashMap<String, String> {
        get() {
            this.data
        }
    }

    public func onContextChanged(): Unit {
        this.version.update({ n => n + 1 })
        this.changedTotal.update({ n => n + 1 })
    }

    public func subscribe(fn: () -> Unit): Int64 {
        this.version.subscribe(fn)
    }

    // 自定义扩展：类型化角色
    public prop role: String {
        get() {
            match (this.get("role")) {
                case Some(v) => if (v == "") { "guest" } else { v }
                case None => "guest"
            }
        }
    }
}

// 测试用页面：render 期读会话上下文（模拟 cjreg publicNav 的 isAdmin 判断）
class CtxProbePage <: Component {
    var sctx: Option<SessionContext> = None

    public func onMount(ctx: LifecycleContext): Unit {
        this.sctx = ctx.getSessionContext()
    }

    public func render(): IComponent {
        let admin = match (this.sctx) {
            case Some(s) => s.isAdmin
            case None => false
        }
        if (admin) {
            div([text("管理后台")])
        } else {
            div([text("登录")])
        }
    }
}

@Test
public class SessionContextStateTest {

    // ---------- 默认实现：与 Session.context 同源 ----------

    @TestCase
    public func testDefaultImplSharesSessionContextMap(): Unit {
        let session = Session("s1", div([]), div([]))
        let sctx: SessionContext = SessionContextState(session.context)
        session.context["uid"] = "7"
        // 共享同一 HashMap 实例：会话侧写入，视图侧立即可见
        @Expect(sctx.get("uid").getOrThrow(), "7")
        @Expect(sctx.raw.get("uid").getOrThrow(), "7")
        // 反向：视图侧写入，会话侧可见（鉴权权威存储不变）
        match (sctx) {
            case d: SessionContextState => d.write("username", "alice")
            case _ => @Fail("expected default impl")
        }
        @Expect(session.context.get("username").getOrThrow(), "alice")
    }

    @TestCase
    public func testDefaultPropsFromGet(): Unit {
        let session = Session("s2", div([]), div([]))
        let sctx: SessionContext = SessionContextState(session.context)
        // 默认实现（接口里的默认 getter）
        @Expect(sctx.isAdmin, false)
        @Expect(sctx.uid, 0)
        @Expect(sctx.username, "")
        @Expect(sctx.token, "")
        @Expect(sctx.has("uid"), false)

        session.context["isAdmin"] = "1"
        session.context["uid"] = "42"
        session.context["username"] = "bob"
        session.context[TOKEN_KEY] = "tok-1"
        @Expect(sctx.isAdmin, true)
        @Expect(sctx.uid, 42)
        @Expect(sctx.username, "bob")
        @Expect(sctx.token, "tok-1")
        @Expect(sctx.has("uid"), true)

        // 登出写空串（cjreg logoutMenuItem 的写法）
        session.context["isAdmin"] = ""
        @Expect(sctx.isAdmin, false)
        // 非法 uid 不炸
        session.context["uid"] = "not-a-number"
        @Expect(sctx.uid, 0)
    }

    @TestCase
    public func testSnapshotIsCopy(): Unit {
        let session = Session("s3", div([]), div([]))
        let sctx: SessionContext = SessionContextState(session.context)
        session.context["uid"] = "1"
        let snap = sctx.snapshot()
        snap["uid"] = "999"
        @Expect(sctx.get("uid").getOrThrow(), "1")   // 改副本不影响权威存储
    }

    // ---------- 通知（写入 → 订阅者被通知） ----------

    @TestCase
    public func testWriteNotifiesSubscribers(): Unit {
        let session = Session("s4", div([]), div([]))
        let sctx = SessionContextState(session.context)
        let hits = Box<Int64>(0)
        sctx.subscribe({ => hits.value += 1 })
        sctx.write("isAdmin", "1")
        @Expect(hits.value, 1)
        sctx.writeAll(sessionContextMap([("username", "alice")]))
        @Expect(hits.value, 2)                   // 批量写只通知一次
        @Expect(sctx.username, "alice")
    }

    @TestCase
    public func testGetInsideRenderScopeSubscribes(): Unit {
        // 模拟 render 期读取：读过的属性变化后应触发 scope 回调（组件重渲）
        let session = Session("s5", div([]), div([]))
        let sctx: SessionContext = SessionContextState(session.context)
        let rendered = Box<Int64>(0)
        SignalTracker.enterScope({ => rendered.value += 1 })
        let _ = sctx.isAdmin
        SignalTracker.exitScope()
        notifySessionContext(Some(sctx))
        @Expect(rendered.value, 1)
    }

    // ---------- 写入路径：ActionContext.setContext ----------

    @TestCase
    public func testSetContextNotifiesInjectedContext(): Unit {
        let session = Session("s6", div([]), div([]))
        let sctx = SessionContextState(session.context)
        let router = Router("s6", { _ => () })
        let ctx = ActionContext("s6", session.context, HashMap<String, String>(), router, sessionContext: Some(sctx))
        let hits = Box<Int64>(0)
        sctx.subscribe({ => hits.value += 1 })
        ctx.setContext("isAdmin", "1")
        ctx.setContext("uid", "9")
        @Expect(hits.value, 2)
        @Expect(ctx.getSessionContext().getOrThrow().isAdmin, true)
        @Expect(ctx.getSessionContext().getOrThrow().uid, 9)
        // 权威存储同步（守卫读的就是它）
        @Expect(ctx.getContext().get("isAdmin").getOrThrow(), "1")
    }

    @TestCase
    public func testSetContextWithoutContextIsNoop(): Unit {
        // 未注入上下文（测试态 / 未初始化会话）：setContext 不得抛异常
        let router = Router("s7", { _ => () })
        let ctx = ActionContext("s7", HashMap<String, String>(), HashMap<String, String>(), router)
        ctx.setContext("uid", "1")
        @Expect(ctx.getContext().get("uid").getOrThrow(), "1")
        @Expect(ctx.getSessionContext().isNone(), true)
        notifySessionContext(None)   // no-op
    }

    // ---------- 注入：默认实现 vs 应用自定义实现 ----------

    @TestCase
    public func testInitStatesInjectsDefaultImpl(): Unit {
        let app = App().state<CtxTestState>({ => CtxTestState() })
        let session = Session("s8", div([]), div([]))
        app.initStates(session)
        // 应用态与上下文都在
        @Expect(session.states.get(TypeInfo.of<CtxTestState>().qualifiedName).isSome(), true)
        @Expect(session.sessionContext.isSome(), true)
        // 默认实现类型
        match (session.sessionContext.getOrThrow()) {
            case d: SessionContextState => @Expect(d.isAdmin, false)
            case _ => @Fail("expected default SessionContextState")
        }
        // 幂等：重复 initStates 不重建（订阅不丢）
        let first = session.sessionContext.getOrThrow()
        let hits = Box<Int64>(0)
        first.subscribe({ => hits.value += 1 })
        app.initStates(session)
        first.onContextChanged()
        @Expect(hits.value, 1)
        @Expect(session.sessionContext.getOrThrow().isAdmin, false)
    }

    @TestCase
    public func testAppRegisteredCustomImplementationIsUsed(): Unit {
        // 应用换成自己的实现（泛型约束 T <: SessionContext，无反射）
        let app = App()
            .state<CtxTestState>({ => CtxTestState() })
            .sessionContext<MySessionContext>({ m => MySessionContext(m) })
        let session = Session("s9", div([]), div([]))
        app.initStates(session)

        // 注入的是自定义实现，且共享同一个权威 map
        let sc = match (session.sessionContext.getOrThrow()) {
            case c: MySessionContext => c
            case _ => throw Exception("expected MySessionContext")
        }
        session.context["role"] = "editor"
        @Expect(sc.role, "editor")                       // 自定义扩展属性
        @Expect(sc.uid, 0)                               // 接口默认实现依然可用

        // 框架写入路径会调自定义实现的 onContextChanged（审计计数递增）
        let router = Router("s9", { _ => () })
        let ctx = ActionContext("s9", session.context, HashMap<String, String>(), router, sessionContext: Some(sc))
        @Expect(sc.changedTotal.get(), 0)
        ctx.setContext("isAdmin", "1")
        @Expect(sc.changedTotal.get(), 1)
        @Expect(sc.isAdmin, true)

        // 令牌恢复路径同样通知
        let _ = app.applyRestoredContext(session, Some(sessionContextMap([("uid", "7")])), "tok-9")
        @Expect(sc.changedTotal.get(), 2)
        @Expect(sc.uid, 7)
    }

    @TestCase
    public func testCustomImplementationRoleDefault(): Unit {
        // 自定义实现的扩展属性带自己的默认值
        let sc = MySessionContext(sessionContextMap([("isAdmin", "1")]))
        @Expect(sc.isAdmin, true)      // 未覆写时走接口默认实现
        @Expect(sc.role, "guest")      // 无 role 键 → 自定义默认值
    }

    // ---------- 上下文在生命周期上下文里的可见性 ----------

    @TestCase
    public func testLifecycleContextExposesSessionContext(): Unit {
        let app = App().state<CtxTestState>({ => CtxTestState() })
        let session = Session("s10", div([]), div([]))
        app.initStates(session)
        let lc = LifecycleContext(session.id, HashMap<String, String>(), None, None,
            states: session.states, sessionContext: session.sessionContext)
        @Expect(lc.getSessionContext().isSome(), true)
        @Expect(lc.getSessionContext().getOrThrow().isAdmin, false)
        // 空上下文（onUnmount 等场景）
        let empty = LifecycleContext("", HashMap<String, String>(), None, None)
        @Expect(empty.getSessionContext().isNone(), true)
    }

    // ---------- 恢复后就地重渲（Q2 落地语义） ----------

    @TestCase
    public func testRerenderInPlacePicksUpRestoredContext(): Unit {
        let app = App().state<CtxTestState>({ => CtxTestState() })
        let page = CtxProbePage()
        let session = Session("s11", page, div([]))
        app.initStates(session)
        page.onMount(LifecycleContext(session.id, HashMap<String, String>(), None, None,
            states: session.states, sessionContext: session.sessionContext))

        // HTTP 首屏：无凭据 → 渲染「登录」
        app.rerenderInPlace(session)
        @Expect(treeJson(session.tree).contains("登录"), true)
        @Expect(treeJson(session.tree).contains("管理后台"), false)

        // WS 带 token 恢复：上下文就绪 + 就地重渲 → 渲染「管理后台」
        let _ = app.applyRestoredContext(session, Some(sessionContextMap([("isAdmin", "1"), ("uid", "7")])), "tok-1")
        app.rerenderInPlace(session)
        @Expect(treeJson(session.tree).contains("管理后台"), true)
    }

    @TestCase
    public func testRerenderInPlaceWithoutRestoreKeepsAnonymous(): Unit {
        let app = App()
        let page = CtxProbePage()
        let session = Session("s12", page, div([]))
        app.initStates(session)
        page.onMount(LifecycleContext(session.id, HashMap<String, String>(), None, None,
            states: session.states, sessionContext: session.sessionContext))
        @Expect(app.applyRestoredContext(session, None, "bad"), false)
        app.rerenderInPlace(session)
        @Expect(treeJson(session.tree).contains("管理后台"), false)
        @Expect(treeJson(session.tree).contains("登录"), true)
    }

    @TestCase
    public func testApplyRestoredContextRejected(): Unit {
        let app = App()
        let session = Session("s13", div([]), div([]))
        app.initStates(session)
        let sctx = session.sessionContext.getOrThrow()
        let hits = Box<Int64>(0)
        sctx.subscribe({ => hits.value += 1 })
        @Expect(app.applyRestoredContext(session, None, "bad-token"), false)
        @Expect(sctx.isAdmin, false)
        @Expect(session.context.get(TOKEN_KEY).isNone(), true)   // 校验失败不写上下文
        @Expect(session.syncedToken, "")
        @Expect(hits.value, 0)
    }

    @TestCase
    public func testApplyRestoredContextWritesAndNotifies(): Unit {
        let app = App()
        let session = Session("s14", div([]), div([]))
        app.initStates(session)
        let sctx = session.sessionContext.getOrThrow()
        let hits = Box<Int64>(0)
        sctx.subscribe({ => hits.value += 1 })
        let restored = app.applyRestoredContext(session, Some(sessionContextMap([("uid", "7"), ("username", "admin"), ("isAdmin", "1")])), "tok-abc")
        @Expect(restored, true)
        @Expect(sctx.isAdmin, true)
        @Expect(sctx.uid, 7)
        @Expect(sctx.username, "admin")
        @Expect(session.context.get(TOKEN_KEY).getOrThrow(), "tok-abc")   // 令牌本身也写入
        @Expect(session.syncedToken, "tok-abc")                            // 前端同步基线
        @Expect(hits.value, 1)                                             // 只通知一次
    }

    // ---------- Session 只读访问器 ----------

    @TestCase
    public func testSessionGetContextIsCopy(): Unit {
        let session = Session("s15", div([]), div([]))
        session.context["uid"] = "1"
        let view = session.getContext()
        @Expect(view.get("uid").getOrThrow(), "1")
        view["uid"] = "999"
        @Expect(session.context.get("uid").getOrThrow(), "1")   // 外部改副本不影响鉴权态
    }
}

// ---- 测试辅助 ----

// 由 (key, value) 列表构造上下文 map
func sessionContextMap(pairs: Array<(String, String)>): HashMap<String, String> {
    let m = HashMap<String, String>()
    for ((k, v) in pairs) {
        m[k] = v
    }
    m
}

func treeJson(tree: IComponent): String {
    serializeSubtree(tree, HashMap<String, ActionHandler>())
}
