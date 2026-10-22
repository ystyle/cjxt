package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// InputTag 标签化输入测试。
// 对齐点（EP input-tag.vue + input-tag.scss）：
//   - 根 div.el-input-tag(+.is-focused/.is-disabled)
//   - div.el-input-tag__inner 里是 span.el-tag × N + div.el-input-tag__input-wrapper > input.el-input-tag__input
//     （scss 的 gap/flex-wrap 挂在 __inner 上，input 必须包在 __input-wrapper 里）
//   - clearable 且有值时才渲染 __suffix > __clear
//   - 值语义 ArrayList<String>：回车/分隔符追加、标签 × 删除、空输入退格删末位
//
// 交互一律走 probeFire（按元素自身 action 派发），与前端行为一致。
@Test
public class InputTagTest {
    func json(node: IComponent): String {
        let (out, _) = probeRender(node)
        out
    }

    // 输入框的 bind：前端把 input 当前文本放在 params.value
    func typeIntoInput(json: String, handlers: HashMap<String, ActionHandler>, value: String): Bool {
        let ctx = probeCtxValue("s-it", value)
        probeFire(json, handlers, "el-input-tag__input\"", "bind", ctx)
    }

    // 输入框的 keydown
    func keyInInput(json: String, handlers: HashMap<String, ActionHandler>, key: String, value: String): Bool {
        let ctx = probeCtxKey("s-it", key, value)
        probeFire(json, handlers, "el-input-tag__input\"", "keydown", ctx)
    }

    @TestCase
    public func testStructureMatchesEp(): Unit {
        let sig = Signal<ArrayList<String>>(ArrayList<String>(["a", "b"]))
        let out = this.json(InputTag().bind(sig))
        @Expect(out.contains("el-input-tag"), true)
        @Expect(out.contains("el-input-tag__inner"), true)
        @Expect(out.contains("el-input-tag__input-wrapper"), true)
        @Expect(out.contains("el-input-tag__input\""), true)
        // 恰好 2 个标签根节点（probeCountClass 能把 el-tag 与 el-tag--info 区分开）
        @Expect(probeCountClass(out, "el-tag"), 2)
        @Expect(out.contains("a"), true)
        @Expect(out.contains("b"), true)
    }

    @TestCase
    public func testPlaceholderOnlyWhenEmpty(): Unit {
        // EP：已有 tag 时 placeholder 让位（只有空列表才传 placeholder）
        let empty = this.json(InputTag().placeholder("请输入").bind(Signal<ArrayList<String>>(ArrayList<String>())))
        @Expect(empty.contains("\"placeholder\":\"请输入\""), true)

        let filled = this.json(InputTag().placeholder("请输入").bind(Signal<ArrayList<String>>(ArrayList<String>(["x"]))))
        @Expect(filled.contains("\"placeholder\":\"请输入\""), false)
    }

    @TestCase
    public func testDisabledRendersClassAndNativeDisabled(): Unit {
        let out = this.json(InputTag().disabled().bind(Signal<ArrayList<String>>(ArrayList<String>())))
        @Expect(out.contains("is-disabled"), true)
        @Expect(out.contains("\"disabled\":\"disabled\""), true)
        // 禁用时不渲染可点击的关闭按钮
        @Expect(out.contains("el-tag__close"), false)
    }

    @TestCase
    public func testClearableShowsClearOnlyWithValues(): Unit {
        let withValues = this.json(InputTag().clearable().bind(Signal<ArrayList<String>>(ArrayList<String>(["a"]))))
        @Expect(withValues.contains("el-input-tag__clear"), true)
        @Expect(withValues.contains("el-input-tag__suffix"), true)

        let empty = this.json(InputTag().clearable().bind(Signal<ArrayList<String>>(ArrayList<String>())))
        @Expect(empty.contains("el-input-tag__clear"), false)

        let notClearable = this.json(InputTag().bind(Signal<ArrayList<String>>(ArrayList<String>(["a"]))))
        @Expect(notClearable.contains("el-input-tag__clear"), false)
    }

    @TestCase
    public func testEnterAppendsTag(): Unit {
        // 输入框 keydown Enter + 当前文本 "hello" → 追加成 tag（EP handleKeydown 的 Enter 分支）
        let sig = Signal<ArrayList<String>>(ArrayList<String>())
        let it = InputTag().bind(sig)
        let (out, handlers) = probeRender(it)
        @Expect(this.keyInInput(out, handlers, "Enter", "hello"), true)
        @Expect(sig.get().size, 1)
        @Expect(listHas(sig.get(), "hello"), true)
    }

    @TestCase
    public func testEnterIgnoresBlankInput(): Unit {
        // 纯空白不应成 tag（EP 对输入 trim 后判空）
        let sig = Signal<ArrayList<String>>(ArrayList<String>())
        let (out, handlers) = probeRender(InputTag().bind(sig))
        let _ = this.keyInInput(out, handlers, "Enter", "   ")
        @Expect(sig.get().size, 0)
    }

    @TestCase
    public func testDelimiterSplitsInput(): Unit {
        // 分隔符 "," 出现即切分成多个 tag（EP delimiter 语义），走输入框 bind 而不是 keydown
        let sig = Signal<ArrayList<String>>(ArrayList<String>())
        let (out, handlers) = probeRender(InputTag().delimiter(",").bind(sig))
        @Expect(this.typeIntoInput(out, handlers, "a,b,c"), true)
        @Expect(sig.get().size, 3)
        @Expect(listHas(sig.get(), "a"), true)
        @Expect(listHas(sig.get(), "c"), true)
    }

    @TestCase
    public func testMaxLimitStopsAdding(): Unit {
        // max(2)：已有 2 个时不再追加
        let sig = Signal<ArrayList<String>>(ArrayList<String>(["a", "b"]))
        let (out, handlers) = probeRender(InputTag().max(2).delimiter(",").bind(sig))
        let _ = this.typeIntoInput(out, handlers, "c")
        let _ = this.keyInInput(out, handlers, "Enter", "c")
        @Expect(sig.get().size, 2)
        @Expect(listHas(sig.get(), "c"), false)
    }

    @TestCase
    public func testDuplicateNotAdded(): Unit {
        // 重复值不重复入列（EP 无此约束，但 appendValue 去重更符合表单预期，
        // 这条用例钉住该行为，避免以后被误改）
        let sig = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
        let (out, handlers) = probeRender(InputTag().bind(sig))
        let _ = this.keyInInput(out, handlers, "Enter", "a")
        @Expect(sig.get().size, 1)
    }

    @TestCase
    public func testBackspaceOnEmptyInputRemovesLastTag(): Unit {
        // 空输入时 Backspace → 删末位标签（EP handleKeydown 的 backspace 分支）
        let sig = Signal<ArrayList<String>>(ArrayList<String>(["a", "b"]))
        let (out, handlers) = probeRender(InputTag().bind(sig))
        @Expect(this.keyInInput(out, handlers, "Backspace", ""), true)
        @Expect(sig.get().size, 1)
        @Expect(listHas(sig.get(), "b"), false)
        @Expect(listHas(sig.get(), "a"), true)
    }

    @TestCase
    public func testBackspaceWithTextDoesNotRemoveTag(): Unit {
        // 输入框有文字时 Backspace 是删字符，不该删标签
        let sig = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
        let (out, handlers) = probeRender(InputTag().bind(sig))
        let _ = this.keyInInput(out, handlers, "Backspace", "xy")
        @Expect(sig.get().size, 1)
    }

    @TestCase
    public func testCloseButtonRemovesOnlyThatTag(): Unit {
        // 点第一个标签的 × → 只删那一个（按元素派发，不会误触其它标签）
        let sig = Signal<ArrayList<String>>(ArrayList<String>(["a", "b"]))
        let (out, handlers) = probeRender(InputTag().bind(sig))
        @Expect(probeFire(out, handlers, "el-tag__close", "click", probeCtx("s-it")), true)
        @Expect(sig.get().size, 1)
        @Expect(listHas(sig.get(), "a"), false)
        @Expect(listHas(sig.get(), "b"), true)
    }

    @TestCase
    public func testClearEmptiesAllTags(): Unit {
        let sig = Signal<ArrayList<String>>(ArrayList<String>(["a", "b"]))
        let (out, handlers) = probeRender(InputTag().clearable().bind(sig))
        @Expect(out.contains("el-input-tag__clear"), true)
        @Expect(probeFire(out, handlers, "el-input-tag__clear", "click", probeCtx("s-it")), true)
        @Expect(sig.get().size, 0)
    }

    @TestCase
    public func testSizeModifierClass(): Unit {
        @Expect(this.json(InputTag().size(ComponentSize.Large).bind(Signal<ArrayList<String>>(ArrayList<String>()))).contains("el-input-tag--large"), true)
        @Expect(this.json(InputTag().size(ComponentSize.Small).bind(Signal<ArrayList<String>>(ArrayList<String>()))).contains("el-input-tag--small"), true)
    }

    @TestCase
    public func testFocusedSignalDrivesClass(): Unit {
        // 外置焦点信号驱动 is-focused（scss 的聚焦描边）
        let focus = Signal<Bool>(true)
        let out = this.json(InputTag().focused(focus).bind(Signal<ArrayList<String>>(ArrayList<String>())))
        @Expect(out.contains("is-focused"), true)
        let off = Signal<Bool>(false)
        let out2 = this.json(InputTag().focused(off).bind(Signal<ArrayList<String>>(ArrayList<String>())))
        @Expect(out2.contains("is-focused"), false)
    }
}
