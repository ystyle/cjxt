package cjxt.components

import cjxt.*
import std.collection.HashMap

public class Switch <: Component {
    var _signal: Option<Signal<Bool>> = None
    var _activeText: String = ""
    var _inactiveText: String = ""
    var _disabled: Bool = false
    var _size: Option<ComponentSize> = None

    public init() {}
    public func activeText(v: String): Switch { this._activeText = v; this }
    public func inactiveText(v: String): Switch { this._inactiveText = v; this }
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
        let coreEl = VNode("span", [], attrs: Some(HashMap<String, String>([("class", "el-switch__core")])))
        let switchEl = VNode("div", [hiddenInput, coreEl], attrs: Some(HashMap<String, String>([("class", cls)])))
        match (this._signal) {
            case Some(s) => switchEl.onClick({ ctx =>
                s.set(!s.get())
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
