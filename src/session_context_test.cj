// 会话上下文响应式视图测试（cjreg Q2「登录后才显示管理入口」的框架地基）
//
// 覆盖三件事：
// 1. SessionContextState 与会话 context 同源（共享 map）+ 版本通知（渲染期可读、可订阅）
// 2. 写入路径（ActionContext.setContext / 令牌恢复）会通知订阅者 → 驱动重渲染
// 3. 令牌恢复后的就地重渲能读到新上下文（刷新带 token 的公开页 → 入口出现）
package cjxt

import std.collection.*
import std.reflect.*
import std.unittest.*
import std.unittest.testmacro.*

// 测试用应用态：验证 initStates 同时注入应用态与框架内置的上下文态
class CtxTestState <: AppState {
    var flag: Int64 = 0
}

// 测试用页面：render 期读会话上下文（模拟 cjreg publicNav 的 isAdmin 判断）
class CtxProbePage <: Component {
    var sctx: Option<SessionContextState> = None

    public func onMount(ctx: LifecycleContext): Unit {
        this.sctx = Some(ctx.getState<SessionContextState>())
    }

    public func render(): IComponent {
        let admin = match (this.sctx) {
            case Some(s) => s.isAdmin()
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

    // ---------- 同源 + 读取 ----------

    @TestCase
    public func testSharesSessionContextMap(): Unit {
        let session = Session("s1", div([]), div([]))
        let sctx = SessionContextState(session.context)
        session.context["uid"] = "7"
        // 共享同一 HashMap 实例：会话侧写入，状态侧立即可见
        @Expect(sctx.get("uid").getOrThrow(), "7")
        // 反向：状态侧写入，会话侧可见（鉴权权威存储不变）
        sctx.write("username", "alice")
        @Expect(session.context.get("username").getOrThrow(), "alice")
    }

    @TestCase
    public func testIsAdminVariants(): Unit {
        let session = Session("s2", div([]), div([]))
        let sctx = SessionContextState(session.context)
        @Expect(sctx.isAdmin(), false)          // 缺失
        session.context["isAdmin"] = "0"
        @Expect(sctx.isAdmin(), false)
        session.context["isAdmin"] = "1"
        @Expect(sctx.isAdmin(), true)
        // 登出写空串（cjreg logoutMenuItem 的写法）
        sctx.write("isAdmin", "")
        @Expect(sctx.isAdmin(), false)
    }

    @TestCase
    public func testUidUsernameTokenDefaults(): Unit {
        let session = Session("s3", div([]), div([]))
        let sctx = SessionContextState(session.context)
        @Expect(sctx.uid(), 0)                  // 未登录
        @Expect(sctx.username(), "")            // 框架不替业务编造默认值
        @Expect(sctx.token(), "")
        @Expect(sctx.has("uid"), false)
        sctx.writeAll(sessionContextMap([("uid", "42"), ("username", "bob"), (TOKEN_KEY, "tok-1")]))
        @Expect(sctx.uid(), 42)
        @Expect(sctx.username(), "bob")
        @Expect(sctx.token(), "tok-1")
        @Expect(sctx.has("uid"), true)
        // 非法 uid 不炸
        sctx.write("uid", "not-a-number")
        @Expect(sctx.uid(), 0)
    }

    @TestCase
    public func testSnapshotIsCopy(): Unit {
        let session = Session("s4", div([]), div([]))
        let sctx = SessionContextState(session.context)
        session.context["uid"] = "1"
        let snap = sctx.snapshot()
        snap["uid"] = "999"
        @Expect(sctx.get("uid").getOrThrow(), "1")   // 改副本不影响权威存储
    }

    // ---------- 通知（写入 → 订阅者被通知） ----------

    @TestCase
    public func testBumpNotifiesSubscribers(): Unit {
        let session = Session("s5", div([]), div([]))
        let sctx = SessionContextState(session.context)
        let hits = Box<Int64>(0)
        sctx.subscribe({ => hits.value += 1 })
        sctx.write("isAdmin", "1")
        @Expect(hits.value, 1)
        sctx.writeAll(sessionContextMap([("username", "alice")]))
        @Expect(hits.value, 2)                   // 批量写只 bump 一次
        @Expect(sctx.username(), "alice")
    }

    @TestCase
    public func testGetInsideRenderScopeSubscribes(): Unit {
        // 模拟 render 期读取：读过的 key 变化后应触发 scope 回调（组件重渲）
        let session = Session("s6", div([]), div([]))
        let sctx = SessionContextState(session.context)
        let rendered = Box<Int64>(0)
        SignalTracker.enterScope({ => rendered.value += 1 })
        let _ = sctx.isAdmin()
        SignalTracker.exitScope()
        sctx.write("isAdmin", "1")
        @Expect(rendered.value, 1)
    }

    // ---------- 写入路径：ActionContext.setContext ----------

    @TestCase
    public func testSetContextNotifiesSessionContextState(): Unit {
        let session = Session("s7", div([]), div([]))
        let sctx = SessionContextState(session.context)
        let states = HashMap<String, AppState>()
        states.add(SessionContextState.stateKey(), sctx)
        let router = Router("s7", { _ => () })
        let ctx = ActionContext("s7", session.context, HashMap<String, String>(), router, sessionStates: states)
        let hits = Box<Int64>(0)
        sctx.subscribe({ => hits.value += 1 })
        // 登录动作：写会话上下文（isAdmin 用于渲染期判断入口）
        ctx.setContext("isAdmin", "1")
        ctx.setContext("uid", "9")
        @Expect(hits.value, 2)
        @Expect(sctx.isAdmin(), true)
        @Expect(sctx.uid(), 9)
        // 权威存储同步（守卫读的就是它）
        @Expect(ctx.getContext().get("isAdmin").getOrThrow(), "1")
    }

    @TestCase
    public func testSetContextWithoutStateIsNoop(): Unit {
        // 未注册上下文状态（测试态/未初始化会话）：setContext 不得抛异常
        let router = Router("s8", { _ => () })
        let ctx = ActionContext("s8", HashMap<String, String>(), HashMap<String, String>(), router)
        ctx.setContext("uid", "1")
        @Expect(ctx.getContext().get("uid").getOrThrow(), "1")
        notifySessionContext(HashMap<String, AppState>())   // 空表 no-op
    }

    // ---------- 恢复路径：令牌校验结果 → 上下文 + 通知 ----------

    @TestCase
    public func testApplyRestoredContextWritesAndNotifies(): Unit {
        let app = App()
        let session = Session("s9", div([]), div([]))
        app.initStates(session)
        let sctx = contextStateOf(session)
        let hits = Box<Int64>(0)
        sctx.subscribe({ => hits.value += 1 })
        let restored = app.applyRestoredContext(session, Some(sessionContextMap([("uid", "7"), ("username", "admin"), ("isAdmin", "1")])), "tok-abc")
        @Expect(restored, true)
        @Expect(sctx.isAdmin(), true)
        @Expect(sctx.uid(), 7)
        @Expect(session.context.get(TOKEN_KEY).getOrThrow(), "tok-abc")   // 令牌本身也写入
        @Expect(session.syncedToken, "tok-abc")                            // 前端同步基线
        @Expect(hits.value, 1)                                             // 只 bump 一次
    }

    @TestCase
    public func testApplyRestoredContextRejected(): Unit {
        let app = App()
        let session = Session("s10", div([]), div([]))
        app.initStates(session)
        let sctx = contextStateOf(session)
        let hits = Box<Int64>(0)
        sctx.subscribe({ => hits.value += 1 })
        @Expect(app.applyRestoredContext(session, None, "bad-token"), false)
        @Expect(sctx.isAdmin(), false)
        @Expect(session.context.get(TOKEN_KEY).isNone(), true)   // 校验失败不写上下文
        @Expect(session.syncedToken, "")
        @Expect(hits.value, 0)
    }

    // ---------- 状态注入 ----------

    @TestCase
    public func testInitStatesInjectsContextState(): Unit {
        let app = App().state<CtxTestState>({ => CtxTestState() })
        let session = Session("s11", div([]), div([]))
        app.initStates(session)
        // 应用态与框架态都在（后者是渲染期读上下文的通道）
        @Expect(session.states.get(TypeInfo.of<CtxTestState>().qualifiedName).isSome(), true)
        @Expect(session.states.get(SessionContextState.stateKey()).isSome(), true)
        // onMount 拿得到（初始未登录）
        let lc = LifecycleContext(session.id, HashMap<String, String>(), None, None, states: session.states)
        @Expect(lc.getState<SessionContextState>().isAdmin(), false)
        // 重复 initStates 不重建（否则已建立的订阅会丢）：旧引用仍能通知 + 仍是同一份
        let first = contextStateOf(session)
        let hits = Box<Int64>(0)
        first.subscribe({ => hits.value += 1 })
        app.initStates(session)
        first.write("isAdmin", "1")
        @Expect(hits.value, 1)
        @Expect(contextStateOf(session).isAdmin(), true)
    }

    // ---------- 恢复后就地重渲（Q2 落地语义） ----------

    @TestCase
    public func testRerenderInPlacePicksUpRestoredContext(): Unit {
        let app = App().state<CtxTestState>({ => CtxTestState() })
        let page = CtxProbePage()
        let session = Session("s12", page, div([]))
        app.initStates(session)
        page.onMount(LifecycleContext(session.id, HashMap<String, String>(), None, None, states: session.states))

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
        // 校验失败（None）时不得重渲出管理入口
        let app = App()
        let page = CtxProbePage()
        let session = Session("s13", page, div([]))
        app.initStates(session)
        page.onMount(LifecycleContext(session.id, HashMap<String, String>(), None, None, states: session.states))
        @Expect(app.applyRestoredContext(session, None, "bad"), false)
        app.rerenderInPlace(session)
        @Expect(treeJson(session.tree).contains("管理后台"), false)
        @Expect(treeJson(session.tree).contains("登录"), true)
    }

    // ---------- Session 只读访问器 ----------

    @TestCase
    public func testSessionGetContextIsCopy(): Unit {
        let session = Session("s14", div([]), div([]))
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

func contextStateOf(session: Session): SessionContextState {
    match (session.states.get(SessionContextState.stateKey())) {
        case Some(s) => match (s) {
            case scs: SessionContextState => scs
            case _ => throw Exception("unexpected AppState type")
        }
        case None => throw Exception("SessionContextState not injected")
    }
}

func treeJson(tree: IComponent): String {
    serializeSubtree(tree, HashMap<String, ActionHandler>())
}
