package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Checkbox <: Component {
    var _children: Array<IComponent>
    var _value: String
    var _disabled: Bool = false
    var _standalone: Option<Signal<Bool>> = None
    var _groupSignal: Option<Signal<ArrayList<String>>> = None

    public init(children: Array<IComponent>, value: String) {
        this._children = children
        this._value = value
    }
    public func disabled(): Checkbox { this._disabled = true; this }
    // 独立单选复选框：bind(Signal<Bool>)，点击自身翻转
    public func bind(signal: Signal<Bool>): Checkbox { this._standalone = Some(signal); this }

    func setGroupSignal(s: Signal<ArrayList<String>>): Unit { this._groupSignal = Some(s) }

    public func render(): IComponent {
        let checked = this.resolveChecked()
        let onClick = this.resolveOnClick()
        this.renderChecked(checked, onClick)
    }

    func resolveChecked(): Bool {
        match (this._groupSignal) {
            case Some(s) => this.listContains(s.get(), this._value)
            case None =>
                match (this._standalone) {
                    case Some(s) => s.get()
                    case None => false
                }
        }
    }

    func resolveOnClick(): Option<ActionHandler> {
        if (this._disabled) { return None }
        match (this._groupSignal) {
            case Some(s) => return Some({ ctx =>
                this.toggleList(s, this._value)
                PatchResult.ReRender
            })
            case None => ()
        }
        match (this._standalone) {
            case Some(s2) => Some({ ctx =>
                s2.set(!s2.get())
                PatchResult.ReRender
            })
            case None => None
        }
    }

    func renderChecked(checked: Bool, onClick: Option<ActionHandler>): IComponent {
        var cls = "el-checkbox"
        if (checked) { cls = "${cls} is-checked" }
        if (this._disabled) { cls = "${cls} is-disabled" }

        let inputAttrs = HashMap<String, String>([("class", "el-checkbox__original"), ("type", "checkbox")])
        if (this._disabled) { inputAttrs["disabled"] = "disabled" }
        if (checked) { inputAttrs["checked"] = "checked" }
        let inputEl = VNode("input", [], attrs: Some(inputAttrs))
        let innerSpan = VNode("span", [], attrs: Some(HashMap<String, String>([("class", "el-checkbox__inner")])))
        var inputCls = "el-checkbox__input"
        if (checked) { inputCls = "${inputCls} is-checked" }
        if (this._disabled) { inputCls = "${inputCls} is-disabled" }
        let inputSpan = VNode("span", [inputEl, innerSpan], attrs: Some(HashMap<String, String>([("class", inputCls)])))
        let labelEl = VNode("span", this._children, attrs: Some(HashMap<String, String>([("class", "el-checkbox__label")])))

        // onClick 挂 label（隐藏 input 不可点击；委托已过滤 label 内合成 input click）
        let label = VNode("label", [inputSpan, labelEl], attrs: Some(HashMap<String, String>([("class", cls)])))
        match (onClick) {
            case Some(h) => label.onClick(h)
            case None => label
        }
    }

    func listContains(list: ArrayList<String>, value: String): Bool {
        for (v in list) { if (v == value) { return true } }
        false
    }

    func toggleList(s: Signal<ArrayList<String>>, value: String): Unit {
        let list = s.get()
        let found = this.listContains(list, value)
        if (found) {
            let idx = this.findIndex(list, value)
            if (idx >= 0) { list.remove(idx..idx + 1) }
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

public class CheckboxGroup <: Component {
    var _children: Array<IComponent>
    var _signal: Option<Signal<ArrayList<String>>> = None

    public init(children: Array<IComponent>) { this._children = children }
    public func bind(signal: Signal<ArrayList<String>>): CheckboxGroup { this._signal = Some(signal); this }

    public func render(): IComponent {
        let items = ArrayList<IComponent>()
        let s = match (this._signal) { case Some(sig) => sig; case None => Signal<ArrayList<String>>(ArrayList<String>()) }
        for (c in this._children) {
            match (c) {
                case cb: Checkbox =>
                    cb.setGroupSignal(s)
                    items.add(cb.render())
                case _ => items.add(c)
            }
        }
        VNode("div", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-checkbox-group"), ("role", "group")])))
    }
}
