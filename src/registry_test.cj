package cjxt

import std.collection.*
import std.io.{ByteBuffer}
import stdx.encoding.json.stream.{JsonWriter}
import std.unittest.*
import std.unittest.testmacro.*

func checkResult(result: Option<HashMap<String, String>>): HashMap<String, String> {
    match (result) {
        case Some(params) => params
        case None => throw Exception("expected match")
    }
}

func checkVal(val: Option<String>, expected: String): Unit {
    match (val) {
        case Some(v) => @Expect(v, expected)
        case None => @Fail("expected value")
    }
}

func checkComponent(page: Option<IComponent>): IComponent {
    match (page) {
        case Some(c) => c
        case None => throw Exception("expected page")
    }
}

func checkLayout(layout: Option<LayoutFn>): LayoutFn {
    match (layout) {
        case Some(fn) => fn
        case None => throw Exception("expected layout")
    }
}

@Test
public class RegistryTest {
    @TestCase
    public func testExactMatch(): Unit {
        let entry = RouteEntry("/order/list")
        let params = checkResult(entry.doMatch("/order/list"))
        @Expect(params.size, 0)
    }

    @TestCase
    public func testDynamicMatch(): Unit {
        let entry = RouteEntry("/order/[id]")
        let params = checkResult(entry.doMatch("/order/123"))
        checkVal(params.get("id"), "123")
    }

    @TestCase
    public func testMismatchPath(): Unit {
        let entry = RouteEntry("/order/list")
        let result = entry.doMatch("/user/list")
        match (result) {
            case Some(_) => @Fail("expected no match")
            case None => @Expect(true, true)
        }
    }

    @TestCase
    public func testMismatchDynamic(): Unit {
        let entry = RouteEntry("/order/[id]")
        let result = entry.doMatch("/order")
        match (result) {
            case Some(_) => @Fail("expected no match")
            case None => @Expect(true, true)
        }
    }

    @TestCase
    public func testMultipleDynamics(): Unit {
        let entry = RouteEntry("/order/[year]/[month]")
        let params = checkResult(entry.doMatch("/order/2026/06"))
        checkVal(params.get("year"), "2026")
        checkVal(params.get("month"), "06")
    }

    @TestCase
    public func testRegisterReplacesSamePath(): Unit {
        let reg = RouteRegistry()
        reg.register("/a", { => div([]) })
        reg.register("/a", { => div([text("second")]) })
        // 同路径后注册者生效：只保留一条，且解析到最新的工厂
        @Expect(reg.entriesSize(), 1)
        let c = reg.create("/a")
        match (c) {
            case Some(page) =>
                let vnode = page.renderWithScope()
                @Expect(serializeTestNode(vnode).contains("second"))
            case None => @Fail("expected /a to resolve")
        }
    }

    @TestCase
    public func testRegisterReplaceKeepsOtherPaths(): Unit {
        let reg = RouteRegistry()
        reg.register("/a", { => div([]) })
        reg.register("/b", { => div([]) })
        reg.register("/a", { => div([text("newA")]) })
        @Expect(reg.entriesSize(), 2)
        let a = reg.create("/a")
        match (a) {
            case Some(page) => @Expect(serializeTestNode(page.renderWithScope()).contains("newA"))
            case None => @Fail("expected /a")
        }
        let b = reg.create("/b")
        match (b) {
            case Some(_) => ()
            case None => @Fail("expected /b")
        }
    }

    @TestCase
    public func testResolveGuardPass(): Unit {
        let reg = RouteRegistry()
        let allow: GuardFn = { _ => None }
        reg.register("/admin", { => div([]) }, "管理", allow)
        @Expect(reg.resolveGuard("/admin", HashMap<String, String>()).isNone(), true)
    }

    @TestCase
    public func testResolveGuardDenyWithTarget(): Unit {
        let reg = RouteRegistry()
        let ctx = HashMap<String, String>()
        ctx["isAdmin"] = "0"
        let adminOnly: GuardFn = { c =>
            match (c.get("isAdmin")) {
                case Some(v) => if (v == "1") { None } else { Some("/admin/login") }
                case None => Some("/admin/login")
            }
        }
        reg.register("/admin", { => div([]) }, "管理", adminOnly)
        // 未登录 → 拒绝并跳转登录页
        checkVal(reg.resolveGuard("/admin", ctx), "/admin/login")
        // 已登录 → 放行
        let ok = HashMap<String, String>()
        ok["isAdmin"] = "1"
        @Expect(reg.resolveGuard("/admin", ok).isNone(), true)
    }

    @TestCase
    public func testResolveGuardPerPathTarget(): Unit {
        // 不同路径的守卫可返回不同跳转目标（应用自管理，框架不感知业务）
        let reg = RouteRegistry()
        let denied: GuardFn = { _ => Some("/login") }
        let vipDenied: GuardFn = { _ => Some("/vip/upgrade") }
        reg.register("/admin", { => div([]) }, "管理", denied)
        reg.register("/vip", { => div([]) }, "VIP", vipDenied)
        checkVal(reg.resolveGuard("/admin", HashMap<String, String>()), "/login")
        checkVal(reg.resolveGuard("/vip", HashMap<String, String>()), "/vip/upgrade")
    }

    @TestCase
    public func testResolveGuardNoGuardPasses(): Unit {
        let reg = RouteRegistry()
        reg.register("/public", { => div([]) })
        @Expect(reg.resolveGuard("/public", HashMap<String, String>()).isNone(), true)
        // 未注册守卫的路径也放行
        @Expect(reg.resolveGuard("/unknown", HashMap<String, String>()).isNone(), true)
    }

    // ===== 静态路径优先于同深度的参数路径 =====
    //
    // 契约：`/plans/create` 这类**字面路径**比 `/plans/[id]` 更具体，命中时必须优先；
    // 与两条路由的注册先后无关。
    //
    // 回归背景：`/admin/publish-plans/create` 与 `/admin/publish-plans/[id]` 同级，
    // 而顶层 `@Page` 的注册顺序由编译器决定（跨文件初始化顺序）。参数路由先注册时，
    // `resolve` 返回的是参数路由 → 静态页被吃掉：点「创建发布计划」打开的是详情页，
    // `[id]` 拿到 "create" 解析失败、计划 id 留在 0，页面显示"计划不存在或已删除"。
    @TestCase
    public func testStaticRoutePrecedesParamRouteWhenParamRegisteredFirst(): Unit {
        let reg = RouteRegistry()
        reg.register("/plans/[id]", { => div([text("detail")]) })
        reg.register("/plans/create", { => div([text("create")]) })
        let page = checkComponent(reg.create("/plans/create"))
        @Expect(serializeTestNode(page.renderWithScope()).contains("create"), true)
    }

    @TestCase
    public func testStaticRoutePrecedesParamRouteWhenStaticRegisteredFirst(): Unit {
        let reg = RouteRegistry()
        reg.register("/plans/create", { => div([text("create")]) })
        reg.register("/plans/[id]", { => div([text("detail")]) })
        let page = checkComponent(reg.create("/plans/create"))
        @Expect(serializeTestNode(page.renderWithScope()).contains("create"), true)
    }

    // 参数路由本身仍然要能命中（静态优先不能把参数路由挡死）
    @TestCase
    public func testParamRouteStillResolvesAfterStaticPriority(): Unit {
        let reg = RouteRegistry()
        reg.register("/plans/[id]", { => div([text("detail")]) })
        reg.register("/plans/create", { => div([text("create")]) })
        let page = checkComponent(reg.create("/plans/7"))
        @Expect(serializeTestNode(page.renderWithScope()).contains("detail"), true)
    }

    // 标题查表同样按字面路径优先：否则标题取自哪个路由取决于 HashMap 迭代顺序，
    // 静态页的浏览器标题会串成参数页的。
    @TestCase
    public func testTitlePrefersLiteralPath(): Unit {
        let reg = RouteRegistry()
        reg.register("/plans/[id]", { => div([]) }, "详情")
        reg.register("/plans/create", { => div([]) }, "创建")
        checkVal(reg.getTitle("/plans/create"), "创建")
        checkVal(reg.getTitle("/plans/7"), "详情")
    }

    // 守卫同理：静态页与参数页可能挂不同守卫，命错守卫就是"该放行的被拦下/该拦的放过去"。
    @TestCase
    public func testGuardPrefersLiteralPath(): Unit {
        let reg = RouteRegistry()
        let deny: GuardFn = { _ => Some("/detail-denied") }
        let allow: GuardFn = { _ => None }
        reg.register("/plans/[id]", { => div([]) }, "详情", deny)
        reg.register("/plans/create", { => div([]) }, "创建", allow)
        @Expect(reg.resolveGuard("/plans/create", HashMap<String, String>()).isNone(), true)
        checkVal(reg.resolveGuard("/plans/7", HashMap<String, String>()), "/detail-denied")
    }

    // 布局同理：命错布局会让静态页套上参数页的外壳。
    @TestCase
    public func testLayoutPrefersLiteralPath(): Unit {
        let reg = RouteRegistry()
        let detailLayout: LayoutFn = { page => div([text("detail-layout"), page]) }
        let createLayout: LayoutFn = { page => div([text("create-layout"), page]) }
        let allow: GuardFn = { _ => None }
        reg.register("/plans/[id]", { => div([]) }, "详情", allow, detailLayout)
        reg.register("/plans/create", { => div([]) }, "创建", allow, createLayout)
        let layout = checkLayout(reg.getLayout("/plans/create"))
        let wrapped = serializeTestNode(layout(div([])))
        @Expect(wrapped.contains("create-layout"), true)
        @Expect(wrapped.contains("detail-layout"), false)
    }
}

/** 把 IComponent 序列化为 JSON 字符串（测试断言用） */
func serializeTestNode(c: IComponent): String {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    c.toJson(w)
    w.flush()
    buf.flush()
    String.fromUtf8(buf.bytes())
}
