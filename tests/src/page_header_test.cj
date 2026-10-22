package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// PageHeader 渲染结构测试。
// 对齐点：EP page-header.vue 的
//   `.el-page-header[.is-contentful]` > `__breadcrumb`? + `__header` > `__left`
//     > `__back[role=button][tabindex=0]` > (`__icon` + `__title`) + `el-divider--vertical` + `__content`
//     + `__extra`?
//   + `__main`?
// title 缺省取 locale 文案（zh-cn: 「返回」）；back 是 action（cjxt 的 route.push 模型），
// 不是浏览器的 history.back()。
func renderPageHeaderJson(t: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(t, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

func makePhCtx(): ActionContext {
    ActionContext("s-ph", HashMap<String, String>(), HashMap<String, String>(),
        Router("s-ph", { _ => () }))
}

@Test
public class PageHeaderTest {
    @TestCase
    public func testBasicStructure(): Unit {
        let (json, _) = renderPageHeaderJson(
            PageHeader("订单详情", "订单号 1234")
        )
        @Expect(json.contains("el-page-header"), true)
        @Expect(json.contains("el-page-header__header"), true)
        @Expect(json.contains("el-page-header__left"), true)
        @Expect(json.contains("el-page-header__back"), true)
        @Expect(json.contains("el-page-header__icon"), true)
        @Expect(json.contains("el-page-header__title"), true)
        @Expect(json.contains("el-page-header__content"), true)
        // title 与 content 都要出现在 DOM 里
        @Expect(json.contains("订单详情"), true)
        @Expect(json.contains("订单号 1234"), true)
        // EP 在 left 里放一个竖向 divider
        @Expect(json.contains("el-divider--vertical"), true)
    }

    @TestCase
    public func testBackIsKeyboardAccessible(): Unit {
        // EP back: role="button" tabindex="0"；键盘可达性由 cjxt 补齐 Enter/Space
        let (json, _) = renderPageHeaderJson(PageHeader("t", "c"))
        @Expect(json.contains("\"role\":\"button\""), true)
        @Expect(json.contains("\"tabindex\":\"0\""), true)
    }

    @TestCase
    public func testDefaultTitleFallsBackToLocale(): Unit {
        // EP: title 空时取 t('el.pageHeader.title')，zh-cn 是「返回」
        let (json, _) = renderPageHeaderJson(PageHeader().content("内容"))
        @Expect(json.contains("返回"), true)
        @Expect(json.contains("内容"), true)
    }

    @TestCase
    public func testNoHandlerWhenNoOnBack(): Unit {
        // 未给 onBack 不挂 click：避免渲染出点了没反应的返回按钮
        let (_, handlers) = renderPageHeaderJson(PageHeader("t", "c"))
        @Expect(handlers.size, 0)
    }

    @TestCase
    public func testBackClickFiresHandlerTwiceForClickAndKey(): Unit {
        // 给了 onBack：click 与 keydown 各挂一个 handler（键盘 Enter/Space 触发）
        let hits = Box<Int64>(0)
        let h: ActionHandler = { ctx => hits.value += 1; PatchResult.ReRender }
        let (json, handlers) = renderPageHeaderJson(PageHeader("t", "c").onBack(h))
        @Expect(json.contains("\"click\""), true)
        @Expect(json.contains("\"keydown\""), true)
        @Expect(handlers.size, 2)

        // 逐个触发：click handler 与 keydown handler 都执行，但计数用统一入口
        for ((_, fn) in handlers) { let _ = fn(makePhCtx()) }
        // keydown handler 在无 KeyEvent 时只 ReRender（不触发回退），故只计 1 次
        @Expect(hits.value, 1)
    }

    @TestCase
    public func testContentfulAddsMainAndClass(): Unit {
        // EP: 默认插槽非空 → 渲染 __main 且根加 is-contentful（scss 靠它画分隔线）
        let (j0, _) = renderPageHeaderJson(PageHeader("t", "c"))
        @Expect(j0.contains("is-contentful"), false)
        @Expect(j0.contains("el-page-header__main"), false)

        let (j1, _) = renderPageHeaderJson(PageHeader("t", "c").mainContent([text("主体内容")]))
        @Expect(j1.contains("is-contentful"), true)
        @Expect(j1.contains("el-page-header__main"), true)
        @Expect(j1.contains("主体内容"), true)
    }

    @TestCase
    public func testBreadcrumbSlot(): Unit {
        // EP: breadcrumb 插槽 → __breadcrumb + 根类 --has-breadcrumb
        let (json, _) = renderPageHeaderJson(
            PageHeader("t", "c").breadcrumb([Span("首页")])
        )
        @Expect(json.contains("el-page-header__breadcrumb"), true)
        @Expect(json.contains("el-page-header--has-breadcrumb"), true)
        @Expect(json.contains("首页"), true)
    }

    @TestCase
    public func testExtraSlot(): Unit {
        // EP: extra 插槽 → __extra + 根类 --has-extra（与 left 同一行、靠右）
        let (json, _) = renderPageHeaderJson(
            PageHeader("t", "c").extra([text("右侧操作")])
        )
        @Expect(json.contains("el-page-header__extra"), true)
        @Expect(json.contains("el-page-header--has-extra"), true)
        @Expect(json.contains("右侧操作"), true)
    }

    @TestCase
    public func testCustomBackIcon(): Unit {
        // EP icon prop 可换；这里用 Icon 名（仓内图标表）
        let (json, _) = renderPageHeaderJson(PageHeader("t", "c").backIcon("arrow-right"))
        @Expect(json.contains("el-page-header__icon"), true)
        @Expect(json.contains("\"path\""), true)
    }
}

// 测试内小工具：直接产出 span 文本节点（避免在各用例里重复拼 HashMap）
class Span <: Component {
    let _t: String
    init(t: String) { this._t = t }
    public func render(): IComponent {
        VNode("span", [text(this._t)], attrs: Some(HashMap<String, String>([("class", "test-span")])))
    }
}
