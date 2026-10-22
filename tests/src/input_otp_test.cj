package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// InputOtp 验证码输入测试。
// 对齐点（EP input-otp.vue + input-otp.scss）：
//   - 根 div.el-input-otp + role=group，形态修饰类 el-input-otp--{outlined|filled|underlined}
//   - 每位一个 label.el-input-otp__input-field 包着 input.el-input-otp__input
//     （__input-field 不是多余 div：scss 的 :focus-within 聚焦环与 underlined 的 ::after 下划线都挂它）
//   - 位数由 length 决定（默认 6）；value 按 Rune 逐位铺开
@Test
public class InputOtpTest {
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
        ActionContext("s-otp", HashMap<String, String>(), HashMap<String, String>(), Router("s-otp", { _ => () }))
    }

    @TestCase
    public func testStructureMatchesEp(): Unit {
        let otp = InputOtp()
        let out = this.json(otp)
        @Expect(out.contains("el-input-otp"), true)
        @Expect(out.contains("el-input-otp__input-field"), true)
        @Expect(out.contains("el-input-otp__input"), true)
        @Expect(out.contains("\"role\":\"group\""), true)
        // 默认形态 outlined
        @Expect(out.contains("el-input-otp--outlined"), true)
        // 不能是别的东西的类名
        @Expect(out.contains("el-input__inner"), false)
    }

    @TestCase
    public func testDefaultLengthIsSix(): Unit {
        // EP 默认 length=6 → 6 个 __input-field（不是 5 也不是 7）
        let out = this.json(InputOtp())
        @Expect(probeCountClass(out, "el-input-otp__input-field"), 6)
        // 每位的 input 都带 maxlength=1（__input 是 __input-field 的前缀子串，
        // 不能直接数类名，改用这个只有 input 才有的属性做计数）
        @Expect(countOccurrences(out, "\"maxlength\":\"1\""), 6)
    }

    @TestCase
    public func testCustomLength(): Unit {
        @Expect(probeCountClass(this.json(InputOtp().length(4)), "el-input-otp__input-field"), 4)
    }

    @TestCase
    public func testLengthEight(): Unit {
        @Expect(probeCountClass(this.json(InputOtp().length(8)), "el-input-otp__input-field"), 8)
    }

    @TestCase
    public func testValueSpreadAcrossFields(): Unit {
        // 信号 "123" → 前三位有值，后三位空（EP initialValue 语义）
        let sig = Signal<String>("123")
        let out = this.json(InputOtp().bind(sig))
        @Expect(out.contains("\"value\":\"1\""), true)
        @Expect(out.contains("\"value\":\"2\""), true)
        @Expect(out.contains("\"value\":\"3\""), true)
        @Expect(countOccurrences(out, "\"value\":\"\""), 3)
    }

    @TestCase
    public func testTypeModifierClasses(): Unit {
        // 三种外框形态各自产生修饰类（scss 口径：outlined 描边 / filled 底色 / underlined 下划线）
        @Expect(this.json(InputOtp().kind(InputOtpType.Outlined)).contains("el-input-otp--outlined"), true)
        @Expect(this.json(InputOtp().kind(InputOtpType.Filled)).contains("el-input-otp--filled"), true)
        @Expect(this.json(InputOtp().kind(InputOtpType.Underlined)).contains("el-input-otp--underlined"), true)
    }

    @TestCase
    public func testDisabledClassAndNativeDisabled(): Unit {
        let out = this.json(InputOtp().disabled())
        @Expect(out.contains("is-disabled"), true)
        @Expect(countOccurrences(out, "\"disabled\":\"disabled\""), 6)
    }

    @TestCase
    public func testMaskUsesPasswordType(): Unit {
        // mask 时原生 input 的 type 一律 password（EP :type="mask ? 'password' : 'text'"）
        let out = this.json(InputOtp().mask())
        @Expect(countOccurrences(out, "\"type\":\"password\""), 6)
        // 未 mask 时是 text
        let plain = this.json(InputOtp())
        @Expect(countOccurrences(plain, "\"type\":\"text\""), 6)
    }

    @TestCase
    public func testSizeModifierClass(): Unit {
        @Expect(this.json(InputOtp().size(ComponentSize.Large)).contains("el-input-otp--large"), true)
        @Expect(this.json(InputOtp().size(ComponentSize.Small)).contains("el-input-otp--small"), true)
    }

    @TestCase
    public func testTypingWritesSignal(): Unit {
        // 单位输入：length(1) 只有一个字段，bind handler 唯一，写入确定。
        // 前端 bind 消息只回传 value，所以用带 value 的 ctx 模拟"用户在这一位敲了 9"。
        let sig = Signal<String>("")
        let otp = InputOtp().length(1).bind(sig)
        let (_, handlers) = this.renderWithHandlers(otp)
        @Expect(handlers.size, 1)
        let c = this.ctxWithValue("9")
        for ((_, h) in handlers) {
            let _ = h(c)
        }
        @Expect(sig.get(), "9")
    }

    // 构造带 value 的 ctx（模拟前端 bind 消息回传输入框当前值）
    func ctxWithValue(v: String): ActionContext {
        let p = HashMap<String, String>()
        p["value"] = v
        ActionContext("s-otp", HashMap<String, String>(), p, Router("s-otp", { _ => () }))
    }

    @TestCase
    public func testPasteFillsConsecutiveFields(): Unit {
        // 粘贴 "1234" 到第 1 位（index=0）→ 顺序铺满前 4 位（EP handleInput 的 value.length > 1 分支）。
        // length(4) 下 4 个 handler 都会跑，但只有 index=0 的那个会把整串写进去；
        // 后面 3 个各自把"当前值"再写一遍（幂等），最终结果仍是 "1234"。
        let sig = Signal<String>("")
        let otp = InputOtp().length(4).bind(sig)
        let (_, handlers) = this.renderWithHandlers(otp)
        @Expect(handlers.size, 4)
        let c = this.ctxWithValue("1234")
        for ((_, h) in handlers) {
            let _ = h(c)
        }
        @Expect(sig.get().size, 4)
    }

    @TestCase
    public func testSeparatorRenderedBetweenFields(): Unit {
        // 有 separator 时，位与位之间有分隔元素；末位之后没有 → length-1 个
        let out = this.json(InputOtp().length(4).separator("-"))
        @Expect(out.contains("el-input-otp__separator"), true)
        @Expect(countOccurrences(out, "el-input-otp__separator"), 3)
    }

    @TestCase
    public func testNoSeparatorByDefault(): Unit {
        let out = this.json(InputOtp())
        @Expect(out.contains("el-input-otp__separator"), false)
    }

    @TestCase
    public func testPerFieldBindIdIsDistinct(): Unit {
        // 每位一个 bind（bind 消息只回传 value、不含下标，必须靠不同的 bid 区分是哪一位）
        let sig = Signal<String>("")
        let out = this.json(InputOtp().bind(sig))
        @Expect(countOccurrences(out, "data-bind-id"), 6)
    }
}
