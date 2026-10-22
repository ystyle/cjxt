package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// 验证码输入的外框形态（EP input-otp 的 `type` prop：outlined / filled / underlined）。
// 与原生 input 的 type 无关——后者由 InputOtp.inputType 指定。
public enum InputOtpType {
    | Outlined | Filled | Underlined

    public func asClass(): String {
        match (this) {
            case Outlined => "outlined"
            case Filled => "filled"
            case Underlined => "underlined"
        }
    }
}

// 验证码输入（EP input-otp.vue）。DOM 与 EP 一致：
//   div.el-input-otp(.el-input-otp--{type})(.--large/--small)(.is-disabled)[role=group]
//     > label.el-input-otp__input-field        ← 每位一个，scss 的宽度/边框/聚焦环挂在这一层
//         > input.el-input-otp__input[type][value][maxlength=1]
//     > (可选) span.el-input-otp__separator     ← 位间分隔符
// 注意：`__input-field` 是必要的包裹层（**不是**多余的 div）——scss 用它的
// `:focus-within` / `:hover` 画聚焦环与下划线，input 自身是 `border:none`。
public class InputOtp <: Component {
    var _signal: Option<Signal<String>> = None
    var _length: Int64 = 6
    var _typ: InputOtpType = InputOtpType.Outlined
    var _size: Option<ComponentSize> = None
    var _inputType: String = "text"
    var _mask: Bool = false
    var _disabled: Bool = false
    var _readonly: Bool = false
    var _inputmode: String = "numeric"
    var _separator: String = ""
    var _ariaLabel: String = ""

    public init() {}
    // 绑定整体值（Signal<String>，长度不足 length 时高位留空）
    public func bind(signal: Signal<String>): InputOtp { this._signal = Some(signal); this }
    public func length(v: Int64): InputOtp { this._length = v; this }
    // EP 的 `type` prop（外框形态）。`type` 是仓颉关键字，方法名换成 kind
    // （与原生 input 的 inputType(String) 区分开：那个是 HTML 的 type 属性）
    public func kind(v: InputOtpType): InputOtp { this._typ = v; this }
    public func size(v: ComponentSize): InputOtp { this._size = Some(v); this }
    // 原生 input 的 type（text/number/tel…）；mask 为真时统一 password
    public func inputType(v: String): InputOtp { this._inputType = v; this }
    public func mask(): InputOtp { this._mask = true; this }
    public func disabled(): InputOtp { this._disabled = true; this }
    public func readonly(): InputOtp { this._readonly = true; this }
    public func inputmode(v: String): InputOtp { this._inputmode = v; this }
    // 位间分隔符（EP 的 separator slot 的字符串简化形态；末位之后不渲染）
    public func separator(v: String): InputOtp { this._separator = v; this }
    public func ariaLabel(v: String): InputOtp { this._ariaLabel = v; this }

    public func render(): IComponent {
        var cls = "el-input-otp"
        let sc = match (this._size) { case Some(s) => s.asClass(); case None => "" }
        if (sc != "") { cls = "${cls} el-input-otp--${sc}" }
        cls = "${cls} el-input-otp--${this._typ.asClass()}"
        if (this._disabled) { cls = "${cls} is-disabled" }

        let rootAttrs = HashMap<String, String>([("class", cls), ("role", "group")])
        if (this._ariaLabel != "") { rootAttrs["aria-label"] = this._ariaLabel }

        let chars = this.valueChars()
        let children = ArrayList<IComponent>()
        var i = 0
        while (i < this._length) {
            children.add(this.buildField(i, chars[i]))
            if (this._separator != "" && i < this._length - 1) {
                if (this._separator.startsWith("icon:")) {
                    let name = this._separator[5..]
                    children.add(Icon(name).cls("el-input-otp__separator").render())
                } else {
                    children.add(span([text(this._separator)], attrs: Some(HashMap<String, String>([("class", "el-input-otp__separator")]))))
                }
            }
            i += 1
        }
        VNode("div", children.toArray(), attrs: Some(rootAttrs))
    }

    // 按字符（Rune）切位：String.size 是字节数，直接用会切坏非 ASCII 输入
    func valueChars(): ArrayList<String> {
        let raw = match (this._signal) { case Some(s) => s.get(); case None => "" }
        let runes = raw.toRuneArray()
        let out = ArrayList<String>()
        var i = 0
        while (i < this._length) {
            if (i < runes.size) { out.add(String(runes[i..i + 1])) } else { out.add("") }
            i += 1
        }
        out
    }

    func buildField(index: Int64, ch: String): IComponent {
        let inputAttrs = HashMap<String, String>()
        inputAttrs["class"] = "el-input-otp__input"
        inputAttrs["type"] = if (this._mask) { "password" } else { this._inputType }
        inputAttrs["value"] = ch
        inputAttrs["maxlength"] = "1"
        inputAttrs["autocomplete"] = "one-time-code"
        inputAttrs["inputmode"] = this._inputmode
        inputAttrs["aria-label"] = "第 ${index + 1} 位验证码"
        if (this._disabled) { inputAttrs["disabled"] = "disabled" }
        if (this._readonly) { inputAttrs["readonly"] = "readonly" }

        // 每位的 bind handler 各自知道自己的下标：bind 消息只回传 value，没有下标，
        // 靠「每位一个 bid」区分（前端 attachBind 按元素上的 bid 派发）
        var handlers: Option<HashMap<String, ActionHandler>> = None
        match (this._signal) {
            case Some(s) =>
                let bid = nextBid()
                inputAttrs["data-bind-id"] = bid
                let hmap = HashMap<String, ActionHandler>()
                hmap[bid] = { ctx => this.applyInput(index, ctx); PatchResult.ReRender }
                handlers = Some(hmap)
            case None => ()
        }

        let inputEl = VNode("input", [], attrs: Some(inputAttrs), handlers: handlers).ref("otp-${index}")
        let labelEl = VNode("label", [inputEl], attrs: Some(HashMap<String, String>([("class", "el-input-otp__input-field")])))
        // 点击 label 空白处 → 聚焦到这一位的 input（label 的默认行为已能聚焦，
        // 但 input 被 maxlength=1 约束后点击区域只覆盖文字，故显式包一层）
        labelEl
    }

    // 写入逻辑：把 raw 铺到 index 起的位置（粘贴多字符时逐位填充，对齐 EP handleInput），
    // 更长的既有值保持不变；随后把焦点前移到下一个待填位。
    func applyInput(index: Int64, ctx: ActionContext): Unit {
        let raw = match (ctx.params.get("value")) { case Some(v) => v; case None => "" }
        let target = this._signal
        match (target) {
            case None => ()
            case Some(sig) =>
                let chars = this.valueChars()
                let rawRunes = raw.toRuneArray()
                var pos = index
                var k = 0
                while (k < rawRunes.size && pos < this._length) {
                    chars[pos] = String(rawRunes[k..k + 1])
                    pos += 1
                    k += 1
                }
                sig.set(String.join(chars.toArray(), delimiter: ""))

                // 焦点前移：输入后落到下一个空位（全满则停在末位）
                let nextIndex = this.nextFocusIndex(pos)
                match (ctx.dom) {
                    case Some(d) => d.command([domFocus("otp-${nextIndex}")])
                    case None => ()
                }
        }
    }

    func nextFocusIndex(from: Int64): Int64 {
        if (from >= this._length) { return this._length - 1 }
        let chars = this.valueChars()
        var i = from
        while (i < this._length) {
            if (chars[i] == "") { return i }
            i += 1
        }
        this._length - 1
    }
}
