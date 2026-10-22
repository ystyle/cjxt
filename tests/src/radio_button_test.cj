package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// RadioButton 按钮形态单选测试。
// 对齐点（EP radio-button.vue + radio-button.scss）：
//   - 根是 label.el-radio-button，选中加 is-active（不是 is-checked）、禁用加 is-disabled
//   - 隐藏 input 用 el-radio-button__original-radio，与 __inner 相邻
//     （scss 的 `.original-radio + .inner` 选中着色与 `:disabled + .inner` 禁用着色都依赖这个相邻关系）
//   - 可见文字在 span.el-radio-button__inner 里
@Test
public class RadioButtonTest {
    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    // 渲染并把所有 handler 收集出来（用于点击后断言信号写入）
    func renderWithHandlers(node: IComponent): (String, HashMap<String, ActionHandler>) {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        (out, handlerMap)
    }

    func ctx(): ActionContext {
        ActionContext("s-rb", HashMap<String, String>(), HashMap<String, String>(), Router("s-rb", { _ => () }))
    }

    // 触发所有 handler（点击类只有 click 一个；本组件每实例最多一个）
    func fireAll(handlers: HashMap<String, ActionHandler>): Unit {
        let c = this.ctx()
        for ((_, h) in handlers) {
            let _ = h(c)
        }
    }

    @TestCase
    public func testStructureMatchesEp(): Unit {
        // DOM 层级：label.el-radio-button > input.el-radio-button__original-radio + span.el-radio-button__inner
        let rb = RadioButton([text("选项A")], "a")
        let out = this.json(rb)
        @Expect(out.contains("el-radio-button"), true)
        @Expect(out.contains("el-radio-button__original-radio"), true)
        @Expect(out.contains("el-radio-button__inner"), true)
        @Expect(out.contains("\"label\""), true)
        @Expect(out.contains("\"type\":\"radio\""), true)
        @Expect(out.contains("选项A"), true)
        // 不能混入普通 Radio 的类名
        @Expect(out.contains("el-radio__original"), false)
        @Expect(out.contains("el-radio__inner"), false)
    }

    @TestCase
    public func testCheckedUsesIsActiveNotIsChecked(): Unit {
        // 选中态类名是 is-active（EP radio-button），不是普通 Radio 的 is-checked
        let sig = Signal<String>("a")
        let rb = RadioButton([text("A")], "a").bind(sig)
        let out = this.json(rb)
        @Expect(out.contains("is-active"), true)
        @Expect(out.contains("is-checked"), false)
        @Expect(out.contains("\"checked\":\"checked\""), true)
    }

    @TestCase
    public func testUncheckedHasNoActiveClass(): Unit {
        let sig = Signal<String>("b")
        let rb = RadioButton([text("A")], "a").bind(sig)
        let out = this.json(rb)
        @Expect(out.contains("is-active"), false)
        @Expect(out.contains("\"checked\""), false)
    }

    @TestCase
    public func testDisabledRendersClassAndNativeDisabled(): Unit {
        // EP：is-disabled 在 label 上，原生 disabled 在 input 上
        // （scss 的 `.original-radio:disabled + .inner` 靠原生属性着色）
        let rb = RadioButton([text("A")], "a").disabled()
        let out = this.json(rb)
        @Expect(out.contains("is-disabled"), true)
        @Expect(out.contains("\"disabled\":\"disabled\""), true)
    }

    @TestCase
    public func testClickWritesSignalValue(): Unit {
        // 点击 → 信号写入自身 value（EP v-model 语义）
        let sig = Signal<String>("b")
        let rb = RadioButton([text("A")], "a").bind(sig)
        let (_, handlers) = this.renderWithHandlers(rb)
        this.fireAll(handlers)
        @Expect(sig.get(), "a")
    }

    @TestCase
    public func testDisabledClickDoesNothing(): Unit {
        // 禁用时 resolveOnClick 返回 None → 不注册 click handler，点不动
        let sig = Signal<String>("b")
        let rb = RadioButton([text("A")], "a").bind(sig).disabled()
        let (_, handlers) = this.renderWithHandlers(rb)
        this.fireAll(handlers)
        @Expect(sig.get(), "b")
    }

    @TestCase
    public func testSizeModifierClass(): Unit {
        // EP ns.bm('button', size)：large/small 产生修饰类，Default 不产生
        let large = this.json(RadioButton([text("A")], "a").size(ComponentSize.Large))
        @Expect(large.contains("el-radio-button--large"), true)
        let small = this.json(RadioButton([text("A")], "a").size(ComponentSize.Small))
        @Expect(small.contains("el-radio-button--small"), true)
        let def = this.json(RadioButton([text("A")], "a").size(ComponentSize.Default))
        @Expect(def.contains("el-radio-button--"), false)
    }

    @TestCase
    public func testGroupSelectsOnlyMatchingValue(): Unit {
        // 组内共用同一信号：只有 value 命中的那个是 is-active
        let sig = Signal<String>("b")
        let group = RadioGroup([
            RadioButton([text("A")], "a"),
            RadioButton([text("B")], "b"),
        ]).bind(sig)
        let out = this.json(group)
        @Expect(out.contains("el-radio-group"), true)
        @Expect(out.contains("el-radio-button"), true)
        // 恰好一个 is-active
        @Expect(probeCountClass(out, "el-radio-button is-active"), 1)
    }

    @TestCase
    public func testGroupClickSwitchesSelection(): Unit {
        // 点组内第二个 → 信号变 b
        let sig = Signal<String>("a")
        let group = RadioGroup([
            RadioButton([text("A")], "a"),
            RadioButton([text("B")], "b"),
        ]).bind(sig)
        let (_, handlers) = this.renderWithHandlers(group)
        this.fireAll(handlers)
        @Expect(sig.get(), "b")
    }

    @TestCase
    public func testGroupMixesPlainRadioAndButton(): Unit {
        // 同一个组里两种形态混用：都受组信号驱动（EP 允许 Radio/RadioButton 混排）
        let sig = Signal<String>("a")
        let group = RadioGroup([
            Radio([text("普通")], "a"),
            RadioButton([text("按钮")], "b"),
        ]).bind(sig)
        let out = this.json(group)
        @Expect(out.contains("el-radio__inner"), true)      // 普通形态仍在
        @Expect(out.contains("el-radio-button__inner"), true) // 按钮形态也在
        @Expect(probeCountClass(out, "el-radio is-checked"), 1)   // 普通形态用 is-checked
        @Expect(probeCountClass(out, "el-radio-button is-active"), 0) // 命中 a，按钮 b 未选中
    }
}
