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

// 按钮形态单选（EP radio-button.vue）。DOM：
//   label.el-radio-button(+.is-active/+.is-disabled/+--large/--small)
//     > input.el-radio-button__original-radio[type=radio][value]
//     > span.el-radio-button__inner（slot 内容）
// 与 Radio 的区别只在标记结构：选中态用 is-active（不是 is-checked），
// 可见文字在 __inner 里、隐藏 input 与它相邻（scss 用 `original-radio + __inner` 做选中/禁用着色）。
public class RadioButton <: Component {
    var _children: Array<IComponent>
    var _value: String
    var _disabled: Bool = false
    var _size: Option<ComponentSize> = None
    var _standalone: Option<Signal<String>> = None
    var _groupSignal: Option<Signal<String>> = None

    public init(children: Array<IComponent>, value: String) {
        this._children = children
        this._value = value
    }
    public func disabled(): RadioButton { this._disabled = true; this }
    public func size(v: ComponentSize): RadioButton { this._size = Some(v); this }
    // 独立单选：bind(Signal<String>)，点击写入自身 value
    public func bind(signal: Signal<String>): RadioButton { this._standalone = Some(signal); this }

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

    // 尺寸修饰类：EP 的 ns.bm('button', size) 在默认尺寸下不产生修饰类
    func sizeClass(): String {
        match (this._size) {
            case Some(s) => s.asClass()
            case None => ""
        }
    }

    func renderChecked(checked: Bool, onClick: Option<ActionHandler>): IComponent {
        var cls = "el-radio-button"
        let sc = this.sizeClass()
        if (sc != "") { cls = "${cls} el-radio-button--${sc}" }
        if (checked) { cls = "${cls} is-active" }
        if (this._disabled) { cls = "${cls} is-disabled" }

        let inputAttrs = HashMap<String, String>([("class", "el-radio-button__original-radio"), ("type", "radio"), ("value", this._value)])
        if (this._disabled) { inputAttrs["disabled"] = "disabled" }
        if (checked) { inputAttrs["checked"] = "checked" }
        let inputEl = VNode("input", [], attrs: Some(inputAttrs))
        let innerSpan = VNode("span", this._children, attrs: Some(HashMap<String, String>([("class", "el-radio-button__inner")])))

        // onClick 挂 label（隐藏 input 不可点击；委托已过滤 label 内合成 input click）
        let label = VNode("label", [inputEl, innerSpan], attrs: Some(HashMap<String, String>([("class", cls)])))
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
                case rb: RadioButton =>
                    rb.setGroupSignal(s)
                    items.add(rb.render())
                case _ => items.add(c)
            }
        }
        VNode("div", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-radio-group"), ("role", "radiogroup")])))
    }
}
