package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Splitter 测试。
// 对齐点：
// - DOM：.el-splitter.el-splitter__<layout> > .el-splitter-panel + .el-splitter-bar
//   > .el-splitter-bar__dragger.el-splitter-bar__dragger-<layout>
// - 面板尺寸走 flex-basis（不依赖容器像素宽度的等效表达，详见 Splitter.cj 文件头）
// - 折叠：面板 basis=0/grow=0，空间由相邻面板吸收
@Test
public class SplitterTest {
    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    func twoPanels(): Splitter {
        Splitter([
            SplitterPanel([text("left")]),
            SplitterPanel([text("right")]),
        ])
    }

    @TestCase
    public func testHorizontalStructure(): Unit {
        // 根类 + 横向修饰类 + 两个面板 + 一条 bar（n 个面板 → n-1 条 bar）
        let out = this.json(this.twoPanels())
        @Expect(out.contains("el-splitter el-splitter__horizontal"), true)
        @Expect(countOccurrences(out, "el-splitter-panel"), 2)
        @Expect(countOccurrences(out, "el-splitter-bar\""), 1)
        @Expect(out.contains("el-splitter-bar__dragger el-splitter-bar__dragger-horizontal"), true)
    }

    @TestCase
    public func testVerticalLayoutSwitchesClasses(): Unit {
        // 纵向：根类与 dragger 的方向类都跟着换
        let out = this.json(this.twoPanels().layout(SplitterLayout.Vertical))
        @Expect(out.contains("el-splitter__vertical"), true)
        @Expect(out.contains("el-splitter-bar__dragger-vertical"), true)
        @Expect(out.contains("el-splitter__horizontal"), false)
    }

    @TestCase
    public func testThreePanelsHaveTwoBars(): Unit {
        // n 面板 → n-1 条 bar（最后一块不需要 bar，EP 的 isShowBar）
        let s = Splitter([
            SplitterPanel([text("a")]),
            SplitterPanel([text("b")]),
            SplitterPanel([text("c")]),
        ])
        let out = this.json(s)
        @Expect(countOccurrences(out, "el-splitter-panel"), 3)
        @Expect(countOccurrences(out, "el-splitter-bar\""), 2)
    }

    @TestCase
    public func testExplicitSizeBecomesFlexBasis(): Unit {
        // 显式 size → flex-basis 固定 + grow:0
        let s = Splitter([
            SplitterPanel([text("left")]).size("240px"),
            SplitterPanel([text("right")]),
        ])
        let out = this.json(s)
        @Expect(out.contains("flex-basis:240px"), true)
    }

    @TestCase
    public func testPercentSizePreserved(): Unit {
        // 百分比原样保留，不硬转 px
        let s = Splitter([
            SplitterPanel([text("left")]).size("30%"),
            SplitterPanel([text("right")]),
        ])
        let out = this.json(s)
        @Expect(out.contains("flex-basis:30%"), true)
    }

    @TestCase
    public func testBareNumberSizeBecomesPx(): Unit {
        // 裸数字按 px（与 EP 的 Number(itemSize) 一致）
        let s = Splitter([
            SplitterPanel([text("left")]).size("200"),
            SplitterPanel([text("right")]),
        ])
        let out = this.json(s)
        @Expect(out.contains("flex-basis:200px"), true)
    }

    @TestCase
    public func testPanelWithoutSizeGrows(): Unit {
        // 未给 size 的面板：flex-basis:0 + flex-grow:1（平分剩余空间）
        let out = this.json(this.twoPanels())
        @Expect(out.contains("flex-basis:0"), true)
        @Expect(out.contains("flex-grow:1"), true)
    }

    @TestCase
    public func testExplicitSizePanelDoesNotGrow(): Unit {
        // 给了 size 的面板 grow:0，不与邻居争抢
        let s = Splitter([
            SplitterPanel([text("left")]).size("300px"),
            SplitterPanel([text("right")]).size("100px"),
        ])
        let out = this.json(s)
        @Expect(out.contains("flex-grow:0"), true)
        @Expect(out.contains("flex-grow:1"), false)
    }

    @TestCase
    public func testMinMaxBecomeCssConstraints(): Unit {
        // 上下限落到 CSS min-width/max-width（横向）
        let s = Splitter([
            SplitterPanel([text("left")]).size("50%").min("120px").max("600px"),
            SplitterPanel([text("right")]),
        ])
        let out = this.json(s)
        @Expect(out.contains("min-width:120px"), true)
        @Expect(out.contains("max-width:600px"), true)
    }

    @TestCase
    public func testVerticalMinMaxUseHeight(): Unit {
        // 纵向时用 min-height/max-height
        let s = Splitter([
            SplitterPanel([text("a")]).size("40%").min("80px"),
            SplitterPanel([text("b")]),
        ]).layout(SplitterLayout.Vertical)
        let out = this.json(s)
        @Expect(out.contains("min-height:80px"), true)
        @Expect(out.contains("min-width"), false)
    }

    @TestCase
    public func testCollapsibleRendersCollapseIcons(): Unit {
        // 相邻面板可折叠 → bar 上有折叠图标（start 在左/上，end 在右/下）
        let s = Splitter([
            SplitterPanel([text("left")]).collapsible(),
            SplitterPanel([text("right")]).collapsible(),
        ])
        let out = this.json(s)
        @Expect(out.contains("el-splitter-bar__collapse-icon"), true)
        @Expect(out.contains("el-splitter-bar__horizontal-collapse-icon-start"), true)
        @Expect(out.contains("el-splitter-bar__horizontal-collapse-icon-end"), true)
    }

    @TestCase
    public func testNoCollapseIconsByDefault(): Unit {
        // 默认不可折叠 → 不渲染折叠图标
        let out = this.json(this.twoPanels())
        @Expect(out.contains("el-splitter-bar__collapse-icon"), false)
    }

    @TestCase
    public func testCollapsedPanelHasZeroBasis(): Unit {
        // 折叠状态（外置信号）：该面板 basis=0/grow=0，邻居 grow:1 吸收空间
        let collapsed = Signal<ArrayList<String>>(ArrayList<String>(["0"]))
        let s = Splitter([
            SplitterPanel([text("left")]).collapsible(),
            SplitterPanel([text("right")]),
        ]).bind(collapsed)
        let out = this.json(s)
        @Expect(out.contains("flex-basis:0"), true)
        @Expect(out.contains("flex-grow:0"), true)
    }

    @TestCase
    public func testCollapseIconHasClickAction(): Unit {
        // 折叠图标可点击（服务端 action 已注册）
        let s = Splitter([
            SplitterPanel([text("left")]).collapsible(),
            SplitterPanel([text("right")]),
        ])
        let out = this.json(s)
        @Expect(out.contains("\"click\""), true)
    }

    @TestCase
    public func testResizableFalseDisablesDragger(): Unit {
        // 任一侧 resizable(false) → dragger 加 is-disabled 且光标 auto
        let s = Splitter([
            SplitterPanel([text("left")]).resizable(false),
            SplitterPanel([text("right")]),
        ])
        let out = this.json(s)
        @Expect(out.contains("is-disabled"), true)
        @Expect(out.contains("cursor:auto"), true)
    }

    @TestCase
    public func testLazyAddsLazyClass(): Unit {
        // lazy 模式：dragger 加 is-lazy（EP 拖拽时只动偏移、松开才落尺寸）
        let out = this.json(this.twoPanels().lazy())
        @Expect(out.contains("is-lazy"), true)
    }

    @TestCase
    public func testDataSplitterAttributes(): Unit {
        // 数据标记（拖拽接线用，不改结构）
        let out = this.json(this.twoPanels())
        @Expect(out.contains("data-splitter"), true)
        @Expect(out.contains("data-splitter-panel"), true)
        @Expect(out.contains("data-splitter-bar"), true)
    }
}
