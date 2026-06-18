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

    public init() {}
    public func placeholder(v: String): Input { this._placeholder = v; this }
    public func size(v: ComponentSize): Input { this._size = Some(v); this }
    public func clearable(): Input { this._clearable = true; this }
    public func disabled(): Input { this._disabled = true; this }
    public func password(): Input { this._inputType = "password"; this }
    public func prefixIcon(v: String): Input { this._prefixIcon = v; this }
    public func suffixIcon(v: String): Input { this._suffixIcon = v; this }
    public func bind(signal: Signal<String>): Input { this._signal = Some(signal); this }

    public func render(): IComponent {
        var cls = "el-input"
        match (this._size) {
            case Some(s) => cls = "${cls} el-input--${s.asClass()}"
            case None => ()
        }
        if (this._disabled) { cls = "${cls} is-disabled" }
        if (this._clearable) { cls = "${cls} is-clearable" }
        if (this._prefixIcon != "") { cls = "${cls} el-input--prefix" }
        if (this._suffixIcon != "") { cls = "${cls} el-input--suffix" }
        let innerAttrs = HashMap<String, String>([("class", "el-input__inner"), ("type", this._inputType)])
        if (this._placeholder != "") { innerAttrs["placeholder"] = this._placeholder }
        if (this._disabled) { innerAttrs["disabled"] = "disabled" }
        let inner = this.maybeBind(VNode("input", [], attrs: Some(innerAttrs)))
        let children = ArrayList<IComponent>()
        if (this._prefixIcon != "") { children.add(this.makePrefix()) }
        children.add(inner)
        if (this._clearable || this._suffixIcon != "") { children.add(this.makeSuffix()) }
        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
    }

    func maybeBind(v: VNode): VNode {
        match (this._signal) {
            case Some(s) => v.bind(s)
            case None => v
        }
    }

    func makePrefix(): IComponent {
        let icon = i([], attrs: Some(HashMap<String, String>([("class", "el-input__icon el-icon-${this._prefixIcon}")])))
        VNode("span", [icon], attrs: Some(HashMap<String, String>([("class", "el-input__prefix")])))
    }

    func makeSuffix(): IComponent {
        let items = ArrayList<IComponent>()
        if (this._clearable) {
            let clearIcon = i([], attrs: Some(HashMap<String, String>([("class", "el-input__icon el-icon-circle-close el-input__clear")])))
            items.add(clearIcon)
        }
        if (this._suffixIcon != "") {
            let suffixIcon = i([], attrs: Some(HashMap<String, String>([("class", "el-input__icon el-icon-${this._suffixIcon}")])))
            items.add(suffixIcon)
        }
        VNode("span", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-input__suffix")])))
    }
}
