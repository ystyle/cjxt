package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Input <: Component {
    var _signal: Option<Signal<String>> = None
    var _placeholder: String = ""
    var _size: Option<ComponentSize> = None
    var _clearable: Bool = false
    var _disabled: Bool = false
    var _inputType: String = "text"
    var _prefixIcon: String = ""
    var _suffixIcon: String = ""
    var _rows: Int64 = 2
    var _textarea: Bool = false
    var _prepend: String = ""
    var _append: String = ""
    var _readonly: Bool = false
    var _maxLength: Int64 = -1

    public init() {}
    public func placeholder(v: String): Input { this._placeholder = v; this }
    public func size(v: ComponentSize): Input { this._size = Some(v); this }
    public func clearable(): Input { this._clearable = true; this }
    public func disabled(): Input { this._disabled = true; this }
    public func password(): Input { this._inputType = "password"; this }
    public func prefixIcon(v: String): Input { this._prefixIcon = v; this }
    public func suffixIcon(v: String): Input { this._suffixIcon = v; this }
    public func textarea(): Input { this._textarea = true; this }
    public func rows(v: Int64): Input { this._rows = v; this }
    public func prepend(v: String): Input { this._prepend = v; this }
    public func append(v: String): Input { this._append = v; this }
    public func readonly(): Input { this._readonly = true; this }
    public func maxLength(v: Int64): Input { this._maxLength = v; this }
    public func bind(signal: Signal<String>): Input { this._signal = Some(signal); this }

    public func render(): IComponent {
        if (this._textarea) { return this.renderTextarea() }
        var cls = "el-input"
        match (this._size) {
            case Some(s) => cls = "${cls} el-input--${s.asClass()}"
            case None => ()
        }
        if (this._disabled) { cls = "${cls} is-disabled" }
        if (this._prefixIcon != "") { cls = "${cls} el-input--prefix" }
        if (this._suffixIcon != "" || this._clearable) { cls = "${cls} el-input--suffix" }

        let wrapperChildren = ArrayList<IComponent>()
        if (this._prefixIcon != "") { wrapperChildren.add(this.makePrefix()) }
        wrapperChildren.add(this.makeInner())
        if (this._suffixIcon != "" || this._clearable) { wrapperChildren.add(this.makeSuffix()) }

        let wrapper = VNode("div", wrapperChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-input__wrapper")])))
        let inputEl = VNode("div", [wrapper], attrs: Some(HashMap<String, String>([("class", cls)])))

        // prepend/append：EP el-input-group + __prepend/__append（DOM 组在外层）
        if (this._prepend == "" && this._append == "") { return inputEl }
        let groupChildren = ArrayList<IComponent>()
        if (this._prepend != "") {
            groupChildren.add(VNode("div", [text(this._prepend)], attrs: Some(HashMap<String, String>([("class", "el-input-group__prepend")]))))
        }
        groupChildren.add(inputEl)
        if (this._append != "") {
            groupChildren.add(VNode("div", [text(this._append)], attrs: Some(HashMap<String, String>([("class", "el-input-group__append")]))))
        }
        VNode("div", groupChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-input-group")])))
    }

    // textarea：.el-textarea > textarea.el-textarea__inner（EP input.vue textarea 分支）
    func renderTextarea(): IComponent {
        var cls = "el-textarea"
        if (this._disabled) { cls = "${cls} is-disabled" }
        let attrs = HashMap<String, String>([("class", "el-textarea__inner"), ("rows", this._rows.toString())])
        if (this._placeholder != "") { attrs["placeholder"] = this._placeholder }
        if (this._disabled) { attrs["disabled"] = "disabled" }
        if (this._readonly) { attrs["readonly"] = "readonly" }
        if (this._maxLength > 0) { attrs["maxlength"] = this._maxLength.toString() }
        let inner = VNode("textarea", [], attrs: Some(attrs))
        match (this._signal) {
            case Some(s) => inner.bind(s)
            case None => inner
        }
        VNode("div", [inner], attrs: Some(HashMap<String, String>([("class", cls)])))
    }

    func makeInner(): IComponent {
        let innerAttrs = HashMap<String, String>([("class", "el-input__inner"), ("type", this._inputType)])
        if (this._placeholder != "") { innerAttrs["placeholder"] = this._placeholder }
        if (this._disabled) { innerAttrs["disabled"] = "disabled" }
        if (this._readonly) { innerAttrs["readonly"] = "readonly" }
        if (this._maxLength > 0) { innerAttrs["maxlength"] = this._maxLength.toString() }
        let inner = VNode("input", [], attrs: Some(innerAttrs))
        match (this._signal) {
            case Some(s) => inner.bind(s)
            case None => inner
        }
    }

    func makePrefix(): IComponent {
        let icon = Icon(this._prefixIcon).cls("el-input__icon").render()
        VNode("span", [VNode("span", [icon], attrs: Some(HashMap<String, String>([("class", "el-input__prefix-inner")])))], attrs: Some(HashMap<String, String>([("class", "el-input__prefix")])))
    }

    // suffix：clearable+有值 → 可点击清除图标（el-input__icon el-input__clear）；
    // 否则 suffixIcon（EP showClearBtn 优先，v-if else 语义）
    func makeSuffix(): IComponent {
        let items = ArrayList<IComponent>()
        let hasValue = match (this._signal) { case Some(s) => s.get() != ""; case None => false }
        if (this._clearable && hasValue) {
            let clearIcon = Icon("circle-close").cls("el-input__icon el-input__clear").render()
            let s2 = this._signal
            let clearEl = VNode("span", [clearIcon], attrs: Some(HashMap<String, String>([("class", "el-input__icon el-input__clear")])))
            match (s2) {
                case Some(sig) => items.add(clearEl.onClick({ ctx =>
                    sig.set("")
                    PatchResult.ReRender
                }))
                case None => ()
            }
        } else if (this._suffixIcon != "") {
            items.add(Icon(this._suffixIcon).cls("el-input__icon").render())
        }
        VNode("span", [VNode("span", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-input__suffix-inner")])))], attrs: Some(HashMap<String, String>([("class", "el-input__suffix")])))
    }
}
