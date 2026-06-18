package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

let _radioGroupId = [0]

func nextRadioGroupName(): String {
    _radioGroupId[0] = _radioGroupId[0] + 1
    "radio-group-${_radioGroupId[0]}"
}

public class Radio <: Component {
    var _children: Array<Component>
    var _value: String
    var _disabled: Bool = false

    public init(children: Array<Component>, value: String) {
        this._children = children
        this._value = value
    }
    public func disabled(): Radio { this._disabled = true; this }
    public func render(): Component { this.renderRadio(false, None, "") }

    func renderRadio(checked: Bool, signal: Option<Signal<String>>, name: String): Component {
        var cls = "el-radio"
        if (checked) { cls = "${cls} is-checked" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let innerAttrs = HashMap<String, String>([("class", "el-radio__original"), ("type", "radio")])
        if (name != "") { innerAttrs["name"] = name }
        if (this._disabled) { innerAttrs["disabled"] = "disabled" }
        if (checked) { innerAttrs["checked"] = "checked" }
        let inputEl = VNode("input", [], attrs: Some(innerAttrs))
        let innerSpan = VNode("span", [], attrs: Some(HashMap<String, String>([("class", "el-radio__inner")])))
        let inputSpan = VNode("span", [inputEl, innerSpan], attrs: Some(HashMap<String, String>([("class", "el-radio__input")])))
        let labelEl = VNode("span", this._children, attrs: Some(HashMap<String, String>([("class", "el-radio__label")])))
        let v = this._value
        let clickableInput = match (signal) {
            case Some(s) => inputEl.onClick({ ctx => s.set(v); PatchResult.ReRender })
            case None => inputEl
        }
        let inputSpan2 = VNode("span", [clickableInput, innerSpan], attrs: Some(HashMap<String, String>([("class", "el-radio__input")])))
        VNode("label", [inputSpan2, labelEl], attrs: Some(HashMap<String, String>([("class", cls)])))
    }
}

public class RadioGroup <: Component {
    var _children: Array<Component>
    var _signal: Option<Signal<String>> = None

    public init(children: Array<Component>) { this._children = children }
    public func bind(signal: Signal<String>): RadioGroup { this._signal = Some(signal); this }

    public func render(): Component {
        let currentValue = match (this._signal) {
            case Some(s) => s.get()
            case None => ""
        }
        let name = nextRadioGroupName()
        let items = ArrayList<Component>()
        for (c in this._children) {
            match (c) {
                case r: Radio => items.add(r.renderRadio(r._value == currentValue, this._signal, name))
                case _ => items.add(c)
            }
        }
        VNode("div", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-radio-group"), ("role", "radiogroup")])))
    }
}
