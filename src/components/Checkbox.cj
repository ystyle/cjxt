package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Checkbox <: Component {
    var _children: Array<IComponent>
    var _value: String
    var _disabled: Bool = false
    var _toggleFn: Option<(String) -> Unit> = None

    public init(children: Array<IComponent>, value: String) {
        this._children = children
        this._value = value
    }
    public func disabled(): Checkbox { this._disabled = true; this }
    public func render(): IComponent { this.renderCheckbox(false, this._toggleFn) }

    func setToggle(fn: (String) -> Unit): Unit { this._toggleFn = Some(fn) }

    func renderCheckbox(checked: Bool, toggleFn: Option<(String) -> Unit>): IComponent {
        var cls = "el-checkbox"
        if (checked) { cls = "${cls} is-checked" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let innerAttrs = HashMap<String, String>([("class", "el-checkbox__original"), ("type", "checkbox")])
        if (this._disabled) { innerAttrs["disabled"] = "disabled" }
        if (checked) { innerAttrs["checked"] = "checked" }
        let inputEl = VNode("input", [], attrs: Some(innerAttrs))
        let innerSpan = VNode("span", [], attrs: Some(HashMap<String, String>([("class", "el-checkbox__inner")])))
        let inputSpan = VNode("span", [inputEl, innerSpan], attrs: Some(HashMap<String, String>([("class", "el-checkbox__input")])))
        let labelEl = VNode("span", this._children, attrs: Some(HashMap<String, String>([("class", "el-checkbox__label")])))
        let v = this._value
        let clickableInput = match (toggleFn) {
            case Some(fn) => inputEl.onClick({ ctx => fn(v); PatchResult.ReRender })
            case None => inputEl
        }
        let inputSpan2 = VNode("span", [clickableInput, innerSpan], attrs: Some(HashMap<String, String>([("class", "el-checkbox__input")])))
        VNode("label", [inputSpan2, labelEl], attrs: Some(HashMap<String, String>([("class", cls)])))
    }
}

public class CheckboxGroup <: Component {
    var _children: Array<IComponent>
    var _signal: Option<Signal<ArrayList<String>>> = None

    public init(children: Array<IComponent>) { this._children = children }
    public func bind(signal: Signal<ArrayList<String>>): CheckboxGroup { this._signal = Some(signal); this }

    public func render(): IComponent {
        let selected = match (this._signal) {
            case Some(s) => s.get()
            case None => ArrayList<String>()
        }
        let items = ArrayList<IComponent>()
        for (c in this._children) {
            match (c) {
                case cb: Checkbox => items.add(this.renderGroupCheckbox(selected, cb))
                case _ => items.add(c)
            }
        }
        VNode("div", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-checkbox-group")])))
    }

    func renderGroupCheckbox(selected: ArrayList<String>, cb: Checkbox): IComponent {
        let checked = this.isSelected(selected, cb._value)
        let toggle: (String) -> Unit = { v => this.toggleValue(v) }
        cb.setToggle(toggle)
        cb.renderCheckbox(checked, Some(toggle))
    }

    func isSelected(selected: ArrayList<String>, value: String): Bool {
        for (v in selected) { if (v == value) { return true } }
        false
    }

    func toggleValue(value: String): Unit {
        match (this._signal) {
            case Some(s) => this.doSwitch(s, value)
            case None => ()
        }
    }

    func doSwitch(s: Signal<ArrayList<String>>, value: String): Unit {
        let list = s.get()
        let found = this.isSelected(list, value)
        if (found) {
            list.remove(this.findIndex(list, value)..this.findIndex(list, value) + 1)
        } else {
            list.add(value)
        }
        s.set(list)
    }

    func findIndex(list: ArrayList<String>, value: String): Int64 {
        var i = 0
        for (v in list) { if (v == value) { return i }; i = i + 1 }
        -1
    }
}
