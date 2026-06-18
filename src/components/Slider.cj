package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

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
        var cls = "el-slider"
        if (this._disabled) { cls = "${cls} is-disabled" }
        let value = match (this._signal) {
            case Some(s) => s.get()
            case None => this._min
        }
        let range = this._max - this._min
        let percentage = if (range > 0) { (value - this._min) * 100 / range } else { 0 }
        let track = VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-slider__runway")])))
        let bar = VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-slider__bar"), ("style", "width: ${percentage}%")])))
        let button = VNode("div", [VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-slider__button")])))], attrs: Some(HashMap<String, String>([("class", "el-slider__button-wrapper"), ("style", "left: ${percentage}%")])))
        let children = ArrayList<IComponent>()
        let stepVal = this._step
        match (this._signal) {
            case Some(s) => this.addSliderChildren(children, track, bar, button, stepVal, s)
            case None => this.addStaticChildren(children, track, bar, button)
        }
        if (this._showStops && range > 0) {
            this.addStops(children, range)
        }
        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
    }

    func addSliderChildren(children: ArrayList<IComponent>, track: VNode, bar: VNode, button: VNode, stepVal: Int64, s: Signal<Int64>): Unit {
        children.add(track.onClick({ ctx => this.doStep(stepVal); PatchResult.ReRender }))
        children.add(bar.onClick({ ctx => this.doStep(stepVal); PatchResult.ReRender }))
        children.add(button.onClick({ ctx => this.doToggleStep(s, stepVal); PatchResult.ReRender }))
    }

    func addStaticChildren(children: ArrayList<IComponent>, track: VNode, bar: VNode, button: VNode): Unit {
        children.add(track)
        children.add(bar)
        children.add(button)
    }

    func addStops(children: ArrayList<IComponent>, range: Int64): Unit {
        var pos = this._min + this._step
        while (pos < this._max) {
            let stopPct = (pos - this._min) * 100 / range
            children.add(VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-slider__stop"), ("style", "left: ${stopPct}%")]))))
            pos = pos + this._step
        }
    }

    func doStep(stepDir: Int64): Unit {
        match (this._signal) {
            case Some(s) => this.adjustSlider(s, stepDir)
            case None => ()
        }
    }

    func doToggleStep(s: Signal<Int64>, stepVal: Int64): Unit {
        let v = s.get()
        if (v >= this._max) { s.set(this._min) } else { this.adjustSlider(s, stepVal) }
    }

    func adjustSlider(s: Signal<Int64>, stepVal: Int64): Unit {
        let v = s.get() + stepVal
        if (v >= this._min && v <= this._max) { s.set(v) }
    }
}
