package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Container 布局族测试。
// 对齐点：EP container.vue 的方向判定（显式 direction 优先，否则有 Header/Footer 即纵向）、
// 语义标签（section/header/aside/main/footer）、尺寸走 CSS 变量。
@Test
public class ContainerTest {
    // 渲染成 JSON，便于断言结构与属性
    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    @TestCase
    public func testDefaultDirectionIsHorizontalWithoutHeaderFooter(): Unit {
        // 只有 Aside + Main：横向（flex-direction: row，不加 is-vertical）
        let c = Container([
            Aside([text("side")]).width("120px"),
            Main([text("content")]),
        ])
        let out = this.json(c)
        @Expect(out.contains("el-container"), true)
        @Expect(out.contains("is-vertical"), false)
        @Expect(out.contains("\"section\""), true)
    }

    @TestCase
    public func testHeaderMakesContainerVertical(): Unit {
        // 有 Header → 自动纵向
        let c = Container([
            Header([text("head")]),
            Main([text("content")]),
        ])
        let out = this.json(c)
        @Expect(out.contains("is-vertical"), true)
    }

    @TestCase
    public func testFooterMakesContainerVertical(): Unit {
        // Footer 同样触发纵向（EP 判据是 Header 或 Footer）
        let c = Container([
            Main([text("content")]),
            Footer([text("foot")]),
        ])
        let out = this.json(c)
        @Expect(out.contains("is-vertical"), true)
    }

    @TestCase
    public func testExplicitHorizontalOverridesHeader(): Unit {
        // 显式 Horizontal 优先于自动判定
        let c = Container([
            Header([text("head")]),
            Main([text("content")]),
        ]).direction(ContainerDirection.Horizontal)
        let out = this.json(c)
        @Expect(out.contains("is-vertical"), false)
    }

    @TestCase
    public func testExplicitVerticalOverridesNoHeader(): Unit {
        let c = Container([
            Aside([text("side")]),
            Main([text("content")]),
        ]).direction(ContainerDirection.Vertical)
        let out = this.json(c)
        @Expect(out.contains("is-vertical"), true)
    }

    @TestCase
    public func testSemanticTags(): Unit {
        // EP 用 section/header/aside/main/footer 语义标签，不是清一色 div
        @Expect(this.json(Header([text("h")])).contains("\"header\""), true)
        @Expect(this.json(Footer([text("f")])).contains("\"footer\""), true)
        @Expect(this.json(Aside([text("a")])).contains("\"aside\""), true)
        @Expect(this.json(Main([text("m")])).contains("\"main\""), true)
    }

    @TestCase
    public func testHeaderHeightUsesCssVar(): Unit {
        // EP header.vue 的 height 走 --el-header-height，不改内联 height（保留 scss padding 语义）
        let out = this.json(Header([text("h")]).height("40px"))
        @Expect(out.contains("--el-header-height:40px"), true)
        @Expect(out.contains("el-header"), true)
    }

    @TestCase
    public func testFooterHeightUsesCssVar(): Unit {
        let out = this.json(Footer([text("f")]).height("48px"))
        @Expect(out.contains("--el-footer-height:48px"), true)
    }

    @TestCase
    public func testAsideWidthUsesCssVar(): Unit {
        // aside.scss 默认 var(--el-aside-width, 300px)
        let out = this.json(Aside([text("a")]).width("200px"))
        @Expect(out.contains("--el-aside-width:200px"), true)
        @Expect(out.contains("el-aside"), true)
    }

    @TestCase
    public func testNoStyleAttrWhenSizeUnset(): Unit {
        // 不设尺寸时不写 style，让 scss 的默认值（header 60px / aside 300px）生效
        let out = this.json(Header([text("h")]))
        @Expect(out.contains("--el-header-height"), false)
        @Expect(out.contains("el-header"), true)
    }

    @TestCase
    public func testMainHasClass(): Unit {
        let out = this.json(Main([text("m")]))
        @Expect(out.contains("el-main"), true)
    }

    @TestCase
    public func testExtraStyleMergedWithCssVar(): Unit {
        // 尺寸变量与调用方样式共存，用分号分隔
        let out = this.json(Header([text("h")]).height("40px").style("background:red"))
        @Expect(out.contains("--el-header-height:40px"), true)
        @Expect(out.contains("background:red"), true)
    }
}
