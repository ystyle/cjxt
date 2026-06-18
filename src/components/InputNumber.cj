package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}
import std.convert.*

public class InputNumber <: Component {
    var _signal: Option<Signal<Int64>> = None
    var _min: Int64 = -9223372036854775808
    var _max: Int64 = 9223372036854775807
    var _step: Int64 = 1
    var _size: Option<ComponentSize> = None
    var _disabled: Bool = false
    var _controls: Bool = true

    public init() {}
    public func min(v: Int64): InputNumber { this._min = v; this }
    public func max(v: Int64): InputNumber { this._max = v; this }
    public func step(v: Int64): InputNumber { this._step = v; this }
    public func size(v: ComponentSize): InputNumber { this._size = Some(v); this }
    public func disabled(): InputNumber { this._disabled = true; this }
    public func noControls(): InputNumber { this._controls = false; this }
    public func bind(signal: Signal<Int64>): InputNumber { this._signal = Some(signal); this }

    public func render(): IComponent {
        var cls = "el-input-number"
        match (this._size) {
            case Some(s) => cls = "${cls} el-input-number--${s.asClass()}"
            case None => ()
        }
        if (this._disabled) { cls = "${cls} is-disabled" }
        if (!this._controls) { cls = "${cls} el-input-number--no-controls" }
        let innerAttrs = HashMap<String, String>([("class", "el-input__inner"), ("type", "text")])
        if (this._disabled) { innerAttrs["disabled"] = "disabled" }
        let inner = this.buildInput(innerAttrs)
        let children = ArrayList<IComponent>()
        if (this._controls) {
            let step = this._step
            let decHandler: ActionHandler = { ctx => this.doStep(-step); PatchResult.ReRender }
            let incHandler: ActionHandler = { ctx => this.doStep(step); PatchResult.ReRender }
            children.add(VNode("span", [Icon("minus").render()], attrs: Some(HashMap<String, String>([("class", "el-input-number__decrease")]))).onClick(decHandler))
            children.add(VNode("div", [inner], attrs: Some(HashMap<String, String>([("class", "el-input-number__input")]))))
            children.add(VNode("span", [Icon("plus").render()], attrs: Some(HashMap<String, String>([("class", "el-input-number__increase")]))).onClick(incHandler))
            VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
        } else {
            VNode("div", [VNode("div", [inner], attrs: Some(HashMap<String, String>([("class", "el-input-number__input")])))], attrs: Some(HashMap<String, String>([("class", cls)])))
        }
    }

    func buildInput(attrs: HashMap<String, String>): IComponent {
        match (this._signal) {
            case Some(s) => this.buildBoundInput(attrs, s)
            case None => VNode("input", [], attrs: Some(attrs))
        }
    }

    func buildBoundInput(attrs: HashMap<String, String>, s: Signal<Int64>): VNode {
        let v = s.get().toString()
        let pa = HashMap<String, String>([("class", "el-input__inner"), ("type", "text"), ("value", v)])
        if (this._disabled) { pa["disabled"] = "disabled" }
        let bid = nextBid()
        pa["data-bind-id"] = bid
        let hmap = HashMap<String, ActionHandler>()
        hmap[bid] = { ctx =>
            let raw = match (ctx.params.get("value")) { case Some(x) => x case None => "" }
            let parsed = doParseInt(raw)
            s.set(parsed)
            PatchResult.ReRender
        }
        VNode("input", [], attrs: Some(pa), handlers: Some(hmap))
    }

    func doStep(dir: Int64): Unit {
        this.applyStep(dir)
    }

    func applyStep(dir: Int64): Unit {
        match (this._signal) {
            case Some(s) => this.adjustValue(s, dir)
            case None => ()
        }
    }

    func adjustValue(s: Signal<Int64>, dir: Int64): Unit {
        let v = s.get() + dir
        if (v >= this._min && v <= this._max) { s.set(v) }
    }
}

func doParseInt(raw: String): Int64 {
    Int64.parse(raw, radix: 10)
}
