package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Tour 测试。
// 对齐点：EP tour.vue / step.vue 的 DOM
//   .el-tour[.el-tour--primary] > .el-tour__content[data-side]
//     > __arrow / __closebtn > __close / header.__header[.show-close] > __title / __body
//     > footer.__footer > .el-tour-indicators > .el-tour-indicator[.is-active] + .el-tour-buttons
// **重要偏差**：服务端拿不到目标元素的像素位置，内容居中显示（不定位到 target）。
// 详见 Tour.cj 文件头。
@Test
public class TourTest {
    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    func steps(): Array<IComponent> {
        [
            TourStep("第一步", "这是第一步的说明"),
            TourStep("第二步", "这是第二步的说明"),
            TourStep("第三步", "这是第三步的说明"),
        ]
    }

    @TestCase
    public func testHiddenByDefault(): Unit {
        // 未 bindVisible(true)：整体不渲染
        let out = this.json(Tour(this.steps()))
        @Expect(out.contains("el-tour"), false)
    }

    @TestCase
    public func testContentStructureWhenVisible(): Unit {
        // 可见：根 + content + header/body/footer
        let out = this.json(Tour(this.steps()).bindVisible(Signal<Bool>(true)))
        @Expect(out.contains("el-tour\""), true)
        @Expect(out.contains("el-tour__content"), true)
        @Expect(out.contains("el-tour__header"), true)
        @Expect(out.contains("el-tour__body"), true)
        @Expect(out.contains("el-tour__footer"), true)
    }

    @TestCase
    public func testFirstStepShownByDefault(): Unit {
        // 默认当前步 0
        let out = this.json(Tour(this.steps()).bindVisible(Signal<Bool>(true)))
        @Expect(out.contains("第一步"), true)
        @Expect(out.contains("这是第一步的说明"), true)
        @Expect(out.contains("第二步"), false)
    }

    @TestCase
    public func testCurrentStepFromSignal(): Unit {
        // bindCurrent(1) → 显示第二步
        let out = this.json(Tour(this.steps())
            .bindVisible(Signal<Bool>(true))
            .bindCurrent(Signal<Int64>(1)))
        @Expect(out.contains("第二步"), true)
        @Expect(out.contains("第一步"), false)
    }

    @TestCase
    public func testIndicatorsCount(): Unit {
        // 3 步 → 3 个指示点，只有当前那个 is-active
        let out = this.json(Tour(this.steps()).bindVisible(Signal<Bool>(true)))
        // 计数口径：容器类名是 "el-tour-indicators"（复数），它包含子串 "el-tour-indicator"。
        // 所以「总出现次数 - 1（容器）」才是指示点个数；当前项类名后跟 " is-active"，
        // 不能用「类名后必须紧跟引号」的写法（那样会漏掉激活项）。
        @Expect(countOccurrences(out, "el-tour-indicator") - 1, 3)
        @Expect(out.contains("el-tour-indicator is-active"), true)
    }

    @TestCase
    public func testArrowAndCloseRendered(): Unit {
        let out = this.json(Tour(this.steps()).bindVisible(Signal<Bool>(true)))
        @Expect(out.contains("el-tour__arrow"), true)
        @Expect(out.contains("el-tour__closebtn"), true)
        @Expect(out.contains("el-tour__close\""), true)
        @Expect(out.contains("show-close"), true)
    }

    @TestCase
    public func testShowCloseFalseHidesCloseButton(): Unit {
        let out = this.json(Tour(this.steps()).bindVisible(Signal<Bool>(true)).showClose(false))
        @Expect(out.contains("el-tour__closebtn"), false)
        @Expect(out.contains("show-close"), false)
    }

    @TestCase
    public func testShowArrowFalseHidesArrow(): Unit {
        let out = this.json(Tour(this.steps()).bindVisible(Signal<Bool>(true)).showArrow(false))
        @Expect(out.contains("el-tour__arrow"), false)
    }

    @TestCase
    public func testMaskRenderedByDefault(): Unit {
        let out = this.json(Tour(this.steps()).bindVisible(Signal<Bool>(true)))
        @Expect(out.contains("el-tour__mask"), true)
    }

    @TestCase
    public func testMaskCanBeDisabled(): Unit {
        let out = this.json(Tour(this.steps()).bindVisible(Signal<Bool>(true)).mask(false))
        @Expect(out.contains("el-tour__mask"), false)
    }

    @TestCase
    public func testFirstStepHasNoPrevButton(): Unit {
        // EP: v-if="current > 0" 第 0 步不显示「上一步」
        let out = this.json(Tour(this.steps()).bindVisible(Signal<Bool>(true)))
        @Expect(out.contains("上一步"), false)
        @Expect(out.contains("下一步"), true)
    }

    @TestCase
    public func testMiddleStepHasPrevAndNext(): Unit {
        let out = this.json(Tour(this.steps())
            .bindVisible(Signal<Bool>(true))
            .bindCurrent(Signal<Int64>(1)))
        @Expect(out.contains("上一步"), true)
        @Expect(out.contains("下一步"), true)
    }

    @TestCase
    public func testLastStepShowsFinish(): Unit {
        // 最后一步：按钮文案变「完成」（EP 的 onNext → onFinish）
        let out = this.json(Tour(this.steps())
            .bindVisible(Signal<Bool>(true))
            .bindCurrent(Signal<Int64>(2)))
        @Expect(out.contains("完成"), true)
        @Expect(out.contains("下一步"), false)
    }

    @TestCase
    public func testCustomButtonTexts(): Unit {
        let out = this.json(Tour(this.steps())
            .bindVisible(Signal<Bool>(true))
            .bindCurrent(Signal<Int64>(1))
            .buttonTexts("后退", "前进", "结束"))
        @Expect(out.contains("后退"), true)
        @Expect(out.contains("前进"), true)
    }

    @TestCase
    public func testPrimaryThemeAddsClass(): Unit {
        let out = this.json(Tour(this.steps()).bindVisible(Signal<Bool>(true)).primary())
        @Expect(out.contains("el-tour--primary"), true)
    }

    @TestCase
    public func testPlacementInDataSide(): Unit {
        // placement 落到 data-side（EP 靠它决定箭头 border 哪边透明）
        let s: Array<IComponent> = [TourStep("标题", "描述").placement(TourPlacement.Top)]
        let out = this.json(Tour(s).bindVisible(Signal<Bool>(true)))
        // 序列化后的 JSON 里属性值引号是转义的（data-side=\"top\"），
        // 所以断言属性名与取值分别存在，不去拼引号字面量。
        @Expect(out.contains("data-side"), true)
        @Expect(out.contains("top"), true)
    }

    @TestCase
    public func testTargetLandsOnDataAttribute(): Unit {
        // 服务端不定位，但 target 仍落到 data-tour-target（供后续前端接线）
        let s: Array<IComponent> = [TourStep("标题", "描述").target("#my-btn")]
        let out = this.json(Tour(s).bindVisible(Signal<Bool>(true)))
        @Expect(out.contains("data-tour-target"), true)
        @Expect(out.contains("#my-btn"), true)
    }

    @TestCase
    public func testContentIsCenteredNotPositioned(): Unit {
        // 如实钉住偏差：内容用 fixed + center 定位，不是按 target rect 计算
        let out = this.json(Tour(this.steps()).bindVisible(Signal<Bool>(true)))
        @Expect(out.contains("position:fixed"), true)
        @Expect(out.contains("translate(-50%,-50%)"), true)
    }

    @TestCase
    public func testButtonsHaveClickActions(): Unit {
        let out = this.json(Tour(this.steps())
            .bindVisible(Signal<Bool>(true))
            .bindCurrent(Signal<Int64>(1)))
        @Expect(out.contains("\"click\""), true)
    }

    @TestCase
    public func testEmptyStepsDoNotCrash(): Unit {
        // 无步骤：不崩，不渲染 content
        let out = this.json(Tour([]).bindVisible(Signal<Bool>(true)))
        @Expect(out.contains("el-tour__content"), false)
    }

    @TestCase
    public func testCurrentOutOfRangeClamps(): Unit {
        // 越界夹到末步，不崩溃
        let out = this.json(Tour(this.steps())
            .bindVisible(Signal<Bool>(true))
            .bindCurrent(Signal<Int64>(99)))
        @Expect(out.contains("第三步"), true)
        @Expect(out.contains("完成"), true)
    }
}
