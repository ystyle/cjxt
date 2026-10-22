package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// ColorPicker 测试。
// 对齐点：EP color-picker.vue 的触发器 DOM
//   .el-color-picker > __trigger > __color > __color-inner[style=background-color]
//      + __icon（有值）/ __empty（无值）
//   面板：.el-color-picker__panel > .el-color-picker-panel > 色板 + __footer（清空/确定）
// 简化点：EP 面板是饱和度区+色相条+alpha（需 pointer 拖拽），这里改为预设色板网格。
@Test
public class ColorPickerTest {
    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    @TestCase
    public func testTriggerStructure(): Unit {
        // 触发器三层：__trigger > __color > __color-inner
        let out = this.json(ColorPicker())
        @Expect(out.contains("el-color-picker\""), true)
        @Expect(out.contains("el-color-picker__trigger"), true)
        @Expect(out.contains("el-color-picker__color\""), true)
        @Expect(out.contains("el-color-picker__color-inner"), true)
    }

    @TestCase
    public func testEmptyStateShowsEmptyIcon(): Unit {
        // 无值时显示 __empty（EP 的 close 图标位），不显示 __icon
        let out = this.json(ColorPicker())
        @Expect(out.contains("el-color-picker__empty"), true)
        @Expect(out.contains("el-color-picker__icon"), false)
    }

    @TestCase
    public func testValueStateShowsIconAndBackground(): Unit {
        // 有值：__color-inner 的内联背景色 + __icon（EP 的箭头图标位）
        let sig = Signal<String>("#ff0000")
        let out = this.json(ColorPicker().bind(sig))
        @Expect(out.contains("el-color-picker__icon"), true)
        @Expect(out.contains("background-color:#ff0000"), true)
        @Expect(out.contains("el-color-picker__empty"), false)
    }

    @TestCase
    public func testDisabledAddsClass(): Unit {
        let out = this.json(ColorPicker().disabled())
        @Expect(out.contains("is-disabled"), true)
    }

    @TestCase
    public func testPanelHiddenByDefault(): Unit {
        // 未展开：不渲染面板
        let out = this.json(ColorPicker())
        @Expect(out.contains("el-color-picker__panel"), false)
    }

    @TestCase
    public func testPanelRendersWhenOpen(): Unit {
        // bindOpen(true) → 面板出现，含面板容器与 footer
        let open = Signal<Bool>(true)
        let out = this.json(ColorPicker().bindOpen(open))
        @Expect(out.contains("el-color-picker__panel"), true)
        @Expect(out.contains("el-color-picker-panel\""), true)
        @Expect(out.contains("el-color-picker-panel__footer"), true)
    }

    @TestCase
    public func testPanelHasPresetSwatches(): Unit {
        // 预设色板网格：30 个默认色块
        let open = Signal<Bool>(true)
        let out = this.json(ColorPicker().bindOpen(open))
        @Expect(out.contains("el-color-picker__swatch"), true)
        @Expect(countOccurrences(out, "el-color-picker__swatch"), 30)
    }

    @TestCase
    public func testCurrentColorMarkedSelected(): Unit {
        // 当前值在色板里带 is-selected
        let open = Signal<Bool>(true)
        let out = this.json(ColorPicker().bindOpen(open).bind(Signal<String>("#409eff")))
        @Expect(out.contains("is-selected"), true)
    }

    @TestCase
    public func testCustomPresets(): Unit {
        // 自定义色板替换默认
        let open = Signal<Bool>(true)
        let custom = ArrayList<String>(["#111111", "#222222"])
        let out = this.json(ColorPicker().bindOpen(open).presets(custom))
        @Expect(countOccurrences(out, "el-color-picker__swatch"), 2)
        @Expect(out.contains("background-color:#111111"), true)
    }

    @TestCase
    public func testClearableAddsClearButton(): Unit {
        let open = Signal<Bool>(true)
        let out = this.json(ColorPicker().bindOpen(open).clearable(true))
        @Expect(out.contains("清空"), true)
    }

    @TestCase
    public func testNonClearableOmitsClearButton(): Unit {
        let open = Signal<Bool>(true)
        let out = this.json(ColorPicker().bindOpen(open).clearable(false))
        @Expect(out.contains("清空"), false)
        @Expect(out.contains("确定"), true)
    }

    @TestCase
    public func testSizeAddsModifierClass(): Unit {
        // EP 的 el-color-picker--large / --small
        @Expect(this.json(ColorPicker().size(ComponentSize.Large)).contains("el-color-picker--large"), true)
        @Expect(this.json(ColorPicker().size(ComponentSize.Small)).contains("el-color-picker--small"), true)
        @Expect(this.json(ColorPicker().size(ComponentSize.Default)).contains("el-color-picker--"), false)
    }

    @TestCase
    public func testTriggerAndSwatchHaveClickActions(): Unit {
        // 触发器开面板 + 色块选色，两个 action 都存在
        let open = Signal<Bool>(true)
        let out = this.json(ColorPicker().bindOpen(open))
        @Expect(out.contains("\"click\""), true)
    }

    @TestCase
    public func testDisabledDoesNotOpenPanel(): Unit {
        // disabled 时即使 open 信号为 true 也不渲染面板
        let open = Signal<Bool>(true)
        let out = this.json(ColorPicker().bindOpen(open).disabled())
        @Expect(out.contains("el-color-picker__panel"), false)
    }
}
