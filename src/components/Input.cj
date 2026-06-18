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
        if (this._prefixIcon != "") { cls = "${cls} el-input--prefix" }
        if (this._suffixIcon != "" || this._clearable) { cls = "${cls} el-input--suffix" }

        let wrapperChildren = ArrayList<IComponent>()
        if (this._prefixIcon != "") { wrapperChildren.add(this.makePrefix()) }
        wrapperChildren.add(this.makeInner())
        if (this._suffixIcon != "" || this._clearable) { wrapperChildren.add(this.makeSuffix()) }

        let wrapper = VNode("div", wrapperChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-input__wrapper")])))
        VNode("div", [wrapper], attrs: Some(HashMap<String, String>([("class", cls)])))
    }

    func makeInner(): IComponent {
        let innerAttrs = HashMap<String, String>([("class", "el-input__inner"), ("type", this._inputType)])
        if (this._placeholder != "") { innerAttrs["placeholder"] = this._placeholder }
        if (this._disabled) { innerAttrs["disabled"] = "disabled" }
        let inner = VNode("input", [], attrs: Some(innerAttrs))
        match (this._signal) {
            case Some(s) => inner.bind(s)
            case None => inner
        }
    }

    func makePrefix(): IComponent {
        let icon = Icon(this._prefixIcon).render()
        VNode("span", [VNode("span", [icon], attrs: Some(HashMap<String, String>([("class", "el-input__prefix-inner")])))], attrs: Some(HashMap<String, String>([("class", "el-input__prefix")])))
    }

    func makeSuffix(): IComponent {
        let items = ArrayList<IComponent>()
        if (this._clearable) {
            items.add(Icon("circle-close").render())
        }
        if (this._suffixIcon != "") {
            items.add(Icon(this._suffixIcon).render())
        }
        VNode("span", [VNode("span", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-input__suffix-inner")])))], attrs: Some(HashMap<String, String>([("class", "el-input__suffix")])))
    }
}
