package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ConfigProvider 测试。
// 对齐点：EP 的 config-provider 只做 provide/inject，不输出元素；cjxt 没有上下文通道，
// 改用 CSS 变量继承（必须有一个包裹元素，`class="el-config-provider"`）。
// size → `--el-component-size`（主题变量表默认 32px，large 40px / small 24px）。
@Test
public class ConfigProviderTest {
    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    @TestCase
    public func testRendersContainerWithClass(): Unit {
        // 包裹元素 + 子节点透传
        let out = this.json(ConfigProvider([text("inner")]))
        @Expect(out.contains("el-config-provider"), true)
        @Expect(out.contains("\"div\""), true)
        @Expect(out.contains("inner"), true)
    }

    @TestCase
    public func testNoStyleWhenNothingConfigured(): Unit {
        // 没有任何配置时不写 style，避免 style="" 覆盖主题默认值
        let out = this.json(ConfigProvider([text("x")]))
        @Expect(out.contains("\"style\""), false)
    }

    @TestCase
    public func testSizeLargeInjectsComponentSizeVar(): Unit {
        // 主题变量表：--el-component-size-large: 40px
        let out = this.json(ConfigProvider([]).size(ComponentSize.Large))
        @Expect(out.contains("--el-component-size:40px"), true)
    }

    @TestCase
    public func testSizeDefaultAndSmall(): Unit {
        // 三档高度与主题变量表一致：40 / 32 / 24
        @Expect(this.json(ConfigProvider([]).size(ComponentSize.Default)).contains("--el-component-size:32px"), true)
        @Expect(this.json(ConfigProvider([]).size(ComponentSize.Small)).contains("--el-component-size:24px"), true)
    }

    @TestCase
    public func testZIndexInjectsPopperIndex(): Unit {
        // EP 的 configProvider.zIndex 是弹层初始层级，主题对应 --el-index-popper（默认 2000）
        let out = this.json(ConfigProvider([]).zIndex(3000))
        @Expect(out.contains("--el-index-popper:3000"), true)
    }

    @TestCase
    public func testZIndexZeroDoesNotInject(): Unit {
        // 0 = 不注入，沿用主题默认
        let out = this.json(ConfigProvider([]).zIndex(0))
        @Expect(out.contains("--el-index-popper"), false)
    }

    @TestCase
    public func testCssVarAddsElPrefix(): Unit {
        // 只写 name 时自动补 --el- 前缀
        let out = this.json(ConfigProvider([]).cssVar("color-primary", "#ff0000"))
        @Expect(out.contains("--el-color-primary:#ff0000"), true)
    }

    @TestCase
    public func testCssVarKeepsExplicitPrefix(): Unit {
        // 已经带 -- 前缀时原样使用（支持非 --el- 的变量，如 --my-token）
        let out = this.json(ConfigProvider([]).cssVar("--my-token", "abc"))
        @Expect(out.contains("--my-token:abc"), true)
        @Expect(out.contains("--el---my-token"), false)
    }

    @TestCase
    public func testMultipleCssVarsJoinedBySemicolon(): Unit {
        // 多个变量按插入顺序、分号分隔
        let out = this.json(ConfigProvider([]).cssVar("color-primary", "#00ff00").cssVar("border-radius-base", "8px"))
        @Expect(out.contains("--el-color-primary:#00ff00;--el-border-radius-base:8px"), true)
    }

    @TestCase
    public func testExtraStyleAppendedLast(): Unit {
        // 调用方自定义 style 追加在最后（可覆盖前面的变量）
        let out = this.json(ConfigProvider([]).size(ComponentSize.Small).style("padding:4px"))
        @Expect(out.contains("--el-component-size:24px;padding:4px"), true)
    }
}
