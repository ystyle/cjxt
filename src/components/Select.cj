package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class SelectOption <: Component {
    var _children: Array<IComponent>
    var _value: String
    var _disabled: Bool = false

    public init(children: Array<IComponent>, value: String) {
        this._children = children
        this._value = value
    }
    public func disabled(): SelectOption { this._disabled = true; this }

    public func render(): IComponent {
        var cls = "el-select__option"
        if (this._disabled) { cls = "${cls} is-disabled" }
        VNode("li", this._children, attrs: Some(HashMap<String, String>([("class", cls)])))
    }
}

public class Select <: Component {
    var _signal: Option<Signal<String>> = None
    var _children: Array<IComponent>
    var _placeholder: String = ""
    var _disabled: Bool = false

    public init(children: Array<IComponent>) { this._children = children }
    public func bind(signal: Signal<String>): Select { this._signal = Some(signal); this }
    public func placeholder(v: String): Select { this._placeholder = v; this }
    public func disabled(): Select { this._disabled = true; this }

    public func render(): IComponent {
        var cls = "el-select"
        if (this._disabled) { cls = "${cls} el-select--disabled" }
        let currentValue = match (this._signal) {
            case Some(s) => s.get()
            case None => ""
        }
        let label = this.findLabel(currentValue)
        let nativeAttrs = HashMap<String, String>([("class", "el-select__native"), ("style", "position:absolute;top:0;left:0;width:100%;height:100%;opacity:0;cursor:pointer;z-index:1")])
        if (this._disabled) { nativeAttrs["disabled"] = "disabled" }
        var native = VNode("select", this.buildOptions(), attrs: Some(nativeAttrs))
        match (this._signal) {
            case Some(s) => native = native.bind(s)
            case None => ()
        }
        let displayValue = if (label != "") { label } else { this._placeholder }
        let children = ArrayList<IComponent>()
        children.add(native)
        children.add(VNode("span", [text(displayValue)], attrs: Some(HashMap<String, String>([("class", if (label == "") { "el-select__placeholder is-placeholder" } else { "el-select__selected" })]))))
        children.add(VNode("span", [Icon("arrow-down").size("14px")], attrs: Some(HashMap<String, String>([("class", "el-select__suffix")]))))
        let wrapperAttrs = HashMap<String, String>([("class", "el-select__wrapper"), ("style", "position:relative")])
        let wrapper = VNode("div", children.toArray(), attrs: Some(wrapperAttrs))
        VNode("div", [wrapper], attrs: Some(HashMap<String, String>([("class", cls)])))
    }

    func findLabel(value: String): String {
        for (c in this._children) {
            match (c) {
                case o: SelectOption => if (o._value == value) { return this.extractLabel(o) }
                case _ => ()
            }
        }
        ""
    }

    func extractLabel(o: SelectOption): String {
        if (o._children.size > 0) {
            match (o._children[0]) {
                case t: TextNode => t._text
                case _ => ""
            }
        } else { "" }
    }

    func buildOptions(): Array<IComponent> {
        let items = ArrayList<IComponent>()
        for (c in this._children) {
            match (c) {
                case o: SelectOption => items.add(this.buildOptionItem(o))
                case _ => items.add(c)
            }
        }
        items.toArray()
    }

    func buildOptionItem(o: SelectOption): IComponent {
        let optAttrs = HashMap<String, String>([("value", o._value)])
        if (o._disabled) { optAttrs["disabled"] = "disabled" }
        VNode("option", o._children, attrs: Some(optAttrs))
    }
}
