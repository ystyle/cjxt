package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Radio <: Component {
    var _children: Array<IComponent>
    var _value: String
    var _disabled: Bool = false
    var _standalone: Option<Signal<String>> = None
    var _groupSignal: Option<Signal<String>> = None

    public init(children: Array<IComponent>, value: String) {
        this._children = children
        this._value = value
    }
    public func disabled(): Radio { this._disabled = true; this }
    // 独立单选：bind(Signal<String>)，点击写入自身 value
    public func bind(signal: Signal<String>): Radio { this._standalone = Some(signal); this }

    func setGroupSignal(s: Signal<String>): Unit { this._groupSignal = Some(s) }

    public func render(): IComponent {
        let checked = this.resolveChecked()
        let onClick = this.resolveOnClick()
        this.renderChecked(checked, onClick)
    }

    func resolveChecked(): Bool {
        match (this._groupSignal) {
            case Some(s) => s.get() == this._value
            case None =>
                match (this._standalone) {
                    case Some(s) => s.get() == this._value
                    case None => false
                }
        }
    }

    func resolveOnClick(): Option<ActionHandler> {
        if (this._disabled) { return None }
        match (this._groupSignal) {
            case Some(s) => return Some({ ctx => s.set(this._value); PatchResult.ReRender })
            case None => ()
        }
        match (this._standalone) {
            case Some(s2) => Some({ ctx => s2.set(this._value); PatchResult.ReRender })
            case None => None
        }
    }

    func renderChecked(checked: Bool, onClick: Option<ActionHandler>): IComponent {
        var cls = "el-radio"
        if (checked) { cls = "${cls} is-checked" }
        if (this._disabled) { cls = "${cls} is-disabled" }

        let inputAttrs = HashMap<String, String>([("class", "el-radio__original"), ("type", "radio")])
        if (this._disabled) { inputAttrs["disabled"] = "disabled" }
        if (checked) { inputAttrs["checked"] = "checked" }
        let inputEl = VNode("input", [], attrs: Some(inputAttrs))
        let innerSpan = VNode("span", [], attrs: Some(HashMap<String, String>([("class", "el-radio__inner")])))
        var inputCls = "el-radio__input"
        if (checked) { inputCls = "${inputCls} is-checked" }
        if (this._disabled) { inputCls = "${inputCls} is-disabled" }
        let inputSpan = VNode("span", [inputEl, innerSpan], attrs: Some(HashMap<String, String>([("class", inputCls)])))
        let labelEl = VNode("span", this._children, attrs: Some(HashMap<String, String>([("class", "el-radio__label")])))

        // onClick 挂 label（隐藏 input 不可点击；委托已过滤 label 内合成 input click）
        let label = VNode("label", [inputSpan, labelEl], attrs: Some(HashMap<String, String>([("class", cls)])))
        match (onClick) {
            case Some(h) => label.onClick(h)
            case None => label
        }
    }
}

public class RadioGroup <: Component {
    var _children: Array<IComponent>
    var _signal: Option<Signal<String>> = None

    public init(children: Array<IComponent>) { this._children = children }
    public func bind(signal: Signal<String>): RadioGroup { this._signal = Some(signal); this }

    public func render(): IComponent {
        let items = ArrayList<IComponent>()
        let s = match (this._signal) { case Some(sig) => sig; case None => Signal<String>("") }
        for (c in this._children) {
            match (c) {
                case r: Radio =>
                    r.setGroupSignal(s)
                    items.add(r.render())
                case _ => items.add(c)
            }
        }
        VNode("div", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-radio-group"), ("role", "radiogroup")])))
    }
}
