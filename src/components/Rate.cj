package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Rate <: Component {
    var _signal: Option<Signal<Int64>> = None
    var _max: Int64 = 5
    var _allowHalf: Bool = false
    var _showText: Bool = false
    var _disabled: Bool = false
    var _texts: Array<String> = []

    public init() {}
    public func bind(signal: Signal<Int64>): Rate { this._signal = Some(signal); this }
    public func max(v: Int64): Rate { this._max = v; this }
    public func allowHalf(): Rate { this._allowHalf = true; this }
    public func showText(): Rate { this._showText = true; this }
    public func disabled(): Rate { this._disabled = true; this }
    public func texts(v: Array<String>): Rate { this._texts = v; this }

    public func render(): IComponent {
        let value = match (this._signal) {
            case Some(s) => s.get()
            case None => 0
        }
        let outerCls = if (this._disabled) { "el-rate is-disabled" } else { "el-rate" }
        let items = ArrayList<IComponent>()
        var idx: Int64 = 1
        while (idx <= this._max) {
            let isActive = idx <= value
            let iconName = if (isActive) { "star-filled" } else { "star" }
            let iconColor = if (isActive) { "#e6a23c" } else { "#c6d1de" }
            let starIcon = VNode("span", [Icon(iconName).size("18px")], attrs: Some(HashMap<String, String>([("class", "el-rate__icon"), ("style", "color:${iconColor}")])))
            let star = VNode("span", [starIcon], attrs: Some(HashMap<String, String>([("class", "el-rate__item"), ("style", "cursor:pointer")])))
            let captureIdx = idx
            match (this._signal) {
                case Some(s) => items.add(star.onClick({ ctx => s.set(captureIdx); PatchResult.ReRender }))
                case None => items.add(star)
            }
            idx = idx + 1
        }
        if (this._showText && this._texts.size > 0) {
            let labelIdx = if (value > 0 && value <= this._texts.size) { value - 1 } else { 0 }
            let label = this._texts[labelIdx]
            items.add(VNode("span", [text(label)], attrs: Some(HashMap<String, String>([("class", "el-rate__text")]))))
        }
        VNode("div", items.toArray(), attrs: Some(HashMap<String, String>([("class", outerCls)])))
    }
}
