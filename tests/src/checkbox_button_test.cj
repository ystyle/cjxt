package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// CheckboxButton 按钮形态复选框测试。
// 对齐点（EP checkbox-button.vue + checkbox-button.scss）：
//   - 根是 label.el-checkbox-button，选中加 is-checked、禁用加 is-disabled
//   - 隐藏 input 用 el-checkbox-button__original，与 __inner 相邻
//   - 与 RadioButton 的关键差异：选中类叫 is-checked（RadioButton 是 is-active），
//     且可多选（组信号是 ArrayList<String>，点击是「切换」而不是「赋值」）
@Test
public class CheckboxButtonTest {
    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    func renderWithHandlers(node: IComponent): (String, HashMap<String, ActionHandler>) {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        (out, handlerMap)
    }

    func ctx(): ActionContext {
        ActionContext("s-cb", HashMap<String, String>(), HashMap<String, String>(), Router("s-cb", { _ => () }))
    }

    func fireAll(handlers: HashMap<String, ActionHandler>): Unit {
        let c = this.ctx()
        for ((_, h) in handlers) {
            let _ = h(c)
        }
    }

    @TestCase
    public func testStructureMatchesEp(): Unit {
        // DOM 层级：label.el-checkbox-button > input.el-checkbox-button__original + span.el-checkbox-button__inner
        let cb = CheckboxButton([text("选项A")], "a")
        let out = this.json(cb)
        @Expect(out.contains("el-checkbox-button"), true)
        @Expect(out.contains("el-checkbox-button__original"), true)
        @Expect(out.contains("el-checkbox-button__inner"), true)
        @Expect(out.contains("\"label\""), true)
        @Expect(out.contains("\"type\":\"checkbox\""), true)
        @Expect(out.contains("选项A"), true)
        // 不能混入普通 Checkbox 的类名
        @Expect(out.contains("el-checkbox__original"), false)
        @Expect(out.contains("el-checkbox__inner"), false)
    }

    @TestCase
    public func testCheckedUsesIsChecked(): Unit {
        // 选中态类是 is-checked（与 RadioButton 的 is-active 不同，各自 scss 口径）
        let sig = Signal<Bool>(true)
        let cb = CheckboxButton([text("A")], "a").bind(sig)
        let out = this.json(cb)
        @Expect(out.contains("is-checked"), true)
        @Expect(out.contains("\"checked\":\"checked\""), true)
    }

    @TestCase
    public func testDisabledRendersClassAndNativeDisabled(): Unit {
        let cb = CheckboxButton([text("A")], "a").disabled()
        let out = this.json(cb)
        @Expect(out.contains("is-disabled"), true)
        @Expect(out.contains("\"disabled\":\"disabled\""), true)
    }

    @TestCase
    public func testSizeModifierClass(): Unit {
        let large = this.json(CheckboxButton([text("A")], "a").size(ComponentSize.Large))
        @Expect(large.contains("el-checkbox-button--large"), true)
        let small = this.json(CheckboxButton([text("A")], "a").size(ComponentSize.Small))
        @Expect(small.contains("el-checkbox-button--small"), true)
        // 默认尺寸不产生修饰类
        let def = this.json(CheckboxButton([text("A")], "a").size(ComponentSize.Default))
        @Expect(def.contains("el-checkbox-button--"), false)
    }

    @TestCase
    public func testStandaloneBindToggles(): Unit {
        // 独立复选：点击翻转 Bool 信号
        let sig = Signal<Bool>(false)
        let cb = CheckboxButton([text("A")], "a").bind(sig)
        let (_, h1) = this.renderWithHandlers(cb)
        this.fireAll(h1)
        @Expect(sig.get(), true)
        // 再点一次翻回去（切换语义，不是赋值）
        let (_, h2) = this.renderWithHandlers(cb)
        this.fireAll(h2)
        @Expect(sig.get(), false)
    }

    @TestCase
    public func testDisabledClickDoesNothing(): Unit {
        let sig = Signal<Bool>(false)
        let cb = CheckboxButton([text("A")], "a").bind(sig).disabled()
        let (_, handlers) = this.renderWithHandlers(cb)
        this.fireAll(handlers)
        @Expect(sig.get(), false)
    }

    @TestCase
    public func testGroupAllowsMultiSelect(): Unit {
        // 组内可多选：初始选中 a，点击后集合变成 {a, b}
        let sig = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
        let group = CheckboxGroup([
            CheckboxButton([text("A")], "a"),
            CheckboxButton([text("B")], "b"),
        ]).bind(sig)
        let out = this.json(group)
        @Expect(out.contains("el-checkbox-group"), true)
        @Expect(out.contains("el-checkbox-button"), true)
        // 只有 a 选中
        @Expect(probeCountClass(out, "el-checkbox-button is-checked"), 1)

        let (_, handlers) = this.renderWithHandlers(group)
        this.fireAll(handlers)
        // 两个都点：a 被移除、b 被加入
        @Expect(sig.get().size, 1)
        @Expect(listHas(sig.get(), "b"), true)
    }

    @TestCase
    public func testGroupToggleRemovesWhenAlreadyChecked(): Unit {
        // 已选中的再点 → 从集合移除（EP checkbox 的 toggle 语义）
        let sig = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
        let group = CheckboxGroup([
            CheckboxButton([text("A")], "a"),
        ]).bind(sig)
        let (_, handlers) = this.renderWithHandlers(group)
        this.fireAll(handlers)
        @Expect(sig.get().size, 0)
    }

    @TestCase
    public func testGroupMixesPlainCheckboxAndButton(): Unit {
        let sig = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
        let group = CheckboxGroup([
            Checkbox([text("普通")], "a"),
            CheckboxButton([text("按钮")], "b"),
        ]).bind(sig)
        let out = this.json(group)
        @Expect(out.contains("el-checkbox__inner"), true)
        @Expect(out.contains("el-checkbox-button__inner"), true)
        // 混排时：普通 Checkbox 用 el-checkbox is-checked，按钮形态用 el-checkbox-button ...
        @Expect(probeCountClass(out, "el-checkbox is-checked"), 1)
        @Expect(probeCountClass(out, "el-checkbox-button is-checked"), 0)
    }
}
