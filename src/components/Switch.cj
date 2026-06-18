package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Switch <: Component {
    var _signal: Option<Signal<Bool>> = None
    var _activeText: String = ""
    var _inactiveText: String = ""
    var _activeValue: Bool = true
    var _inactiveValue: Bool = false
    var _disabled: Bool = false
    var _size: Option<ComponentSize> = None

    public init() {}
    public func activeText(v: String): Switch { this._activeText = v; this }
    public func inactiveText(v: String): Switch { this._inactiveText = v; this }
    public func activeValue(v: Bool): Switch { this._activeValue = v; this }
    public func inactiveValue(v: Bool): Switch { this._inactiveValue = v; this }
    public func disabled(): Switch { this._disabled = true; this }
    public func size(v: ComponentSize): Switch { this._size = Some(v); this }
    public func bind(signal: Signal<Bool>): Switch { this._signal = Some(signal); this }

    public func render(): IComponent {
        var cls = "el-switch"
        match (this._size) {
            case Some(s) => cls = "${cls} el-switch--${s.asClass()}"
            case None => ()
        }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let isChecked = this.currentValue()
        if (isChecked) { cls = "${cls} is-checked" }
        let inputAttrs = HashMap<String, String>([("class", "el-switch__input"), ("type", "checkbox")])
        if (this._disabled) { inputAttrs["disabled"] = "disabled" }
        if (isChecked) { inputAttrs["checked"] = "checked" }
        let hiddenInput = VNode("input", [], attrs: Some(inputAttrs))

        let inner = ArrayList<IComponent>()
        if (isChecked && this._activeText != "") {
            inner.add(span([text(this._activeText)], attrs: Some(HashMap<String, String>([("class", "is-text")]))))
        }
        if (!isChecked && this._inactiveText != "") {
            inner.add(span([text(this._inactiveText)], attrs: Some(HashMap<String, String>([("class", "is-text")]))))
        }
        let coreInner = VNode("div", inner.toArray(), attrs: Some(HashMap<String, String>([("class", "el-switch__inner")])))
        let action = VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-switch__action")])))
        let coreEl = VNode("span", [coreInner, action], attrs: Some(HashMap<String, String>([("class", "el-switch__core")])))

        let children = ArrayList<IComponent>()
        children.add(hiddenInput)
        children.add(coreEl)
        if (this._inactiveText != "" || this._activeText != "") {
            let labelText = if (isChecked) { this._inactiveText } else { this._activeText }
            let labelCls = "el-switch__label el-switch__label--left"
            children.add(span([text(labelText)], attrs: Some(HashMap<String, String>([("class", labelCls)]))))
        }

        let switchEl = VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
        match (this._signal) {
            case Some(s) => switchEl.onClick({ ctx =>
                s.set(!isChecked)
                PatchResult.ReRender
            })
            case None => switchEl
        }
    }

    func currentValue(): Bool {
        match (this._signal) {
            case Some(s) => s.get()
            case None => false
        }
    }
}
