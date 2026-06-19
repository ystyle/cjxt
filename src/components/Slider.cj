package cjxt.components

import cjxt.*
import std.collection.HashMap

public class Slider <: Component {
    var _signal: Option<Signal<Int64>> = None
    var _min: Int64 = 0
    var _max: Int64 = 100
    var _step: Int64 = 1
    var _showStops: Bool = false
    var _disabled: Bool = false

    public init() {}
    public func bind(signal: Signal<Int64>): Slider { this._signal = Some(signal); this }
    public func min(v: Int64): Slider { this._min = v; this }
    public func max(v: Int64): Slider { this._max = v; this }
    public func step(v: Int64): Slider { this._step = v; this }
    public func showStops(): Slider { this._showStops = true; this }
    public func disabled(): Slider { this._disabled = true; this }

    public func render(): IComponent {
        let value = match (this._signal) {
            case Some(s) => s.get()
            case None => this._min
        }
        let range = this._max - this._min
        let pct = if (range > 0) { "${(value - this._min) * 100 / range}%" } else { "0%" }

        var cls = "el-slider"
        if (this._disabled) { cls = "${cls} is-disabled" }

        let inputAttrs = HashMap<String, String>([
            ("type", "range"),
            ("min", "${this._min}"),
            ("max", "${this._max}"),
            ("step", "${this._step}"),
            ("value", "${value}"),
            ("style", "--pct:${pct}")
        ])
        if (this._disabled) { inputAttrs["disabled"] = "disabled" }

        var rangeInput = VNode("input", [], attrs: Some(inputAttrs))
        match (this._signal) {
            case Some(s) => rangeInput = rangeInput.bind(s)
            case None => ()
        }

        VNode("div", [rangeInput], attrs: Some(HashMap<String, String>([("class", cls)])))
    }
}
