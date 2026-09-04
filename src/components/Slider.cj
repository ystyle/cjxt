package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}
import std.convert.*

/**
 * Slider 滑块 — 对齐 Element Plus el-slider 的 DOM 结构与交互语义。
 *
 * DOM：.el-slider > .el-slider__runway（data-slider 标记，前端挂拖动/键盘）
 *   ├─ .el-slider__bar（已选进度）
 *   ├─ .el-slider__button-wrapper（aria/键盘焦点）> .el-slider__button + .el-slider__tip
 *   └─ 步进停靠点 .el-slider__stop × n
 *
 * 交互模型（前端 attachSlider）：
 * - pointerdown/move/up：点击或拖动 → 由位置计算值 → bind 消息回传（rAF 节流）
 * - 键盘（wrapper tabindex=0）：方向键 ±step、PageUp/Down ±10step、Home/End → min/max
 * 服务端自定义 bind handler + Int64.parse（通用 VNode.bind 的 JSON readValue 对 Int64 解析字符串会失败，
 * 对齐 VirtualList 先例）。
 */
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
        let pct = sliderPercent(value, this._min, this._max)
        let pctStr = sliderPercentString(pct)
        let tipStr = "${value}"

        var attrs = HashMap<String, String>()
        var cls = "el-slider"
        if (this._disabled) { cls = "${cls} is-disabled" }
        attrs["class"] = cls

        let runwayAttrs = HashMap<String, String>()
        var runwayCls = "el-slider__runway"
        if (this._disabled) { runwayCls = "${runwayCls} is-disabled" }
        runwayAttrs["class"] = runwayCls
        runwayAttrs["data-slider"] = "1"
        runwayAttrs["data-min"] = "${this._min}"
        runwayAttrs["data-max"] = "${this._max}"
        runwayAttrs["data-step"] = "${this._step}"

        // 服务端自定义 bind：拖动/键盘回传 value（字符串）→ Int64.parse 写信号
        let bid = nextBid()
        runwayAttrs["data-bind-id"] = bid
        let hmap = HashMap<String, ActionHandler>()
        hmap[bid] = { ctx =>
            let raw = match (ctx.params.get("value")) { case Some(x) => x case None => "" }
            if (raw != "") {
                match (this._signal) {
                    case Some(s) => s.set(Int64.parse(raw, radix: 10))
                    case None => ()
                }
            }
            PatchResult.ReRender
        }

        let children = ArrayList<IComponent>()

        // 进度条
        let barAttrs = HashMap<String, String>()
        barAttrs["class"] = "el-slider__bar"
        barAttrs["style"] = "width:${pctStr}"
        children.add(VNode("div", [], attrs: Some(barAttrs)))

        // 拖动按钮（wrapper 承担键盘焦点/ARIA；tip 为当前值浮层）
        let wrapperAttrs = HashMap<String, String>()
        var wrapperCls = "el-slider__button-wrapper"
        if (this._disabled) { wrapperCls = "${wrapperCls} is-disabled" }
        wrapperAttrs["class"] = wrapperCls
        wrapperAttrs["style"] = "left:${pctStr}"
        wrapperAttrs["role"] = "slider"
        wrapperAttrs["aria-valuemin"] = "${this._min}"
        wrapperAttrs["aria-valuemax"] = "${this._max}"
        wrapperAttrs["aria-valuenow"] = "${value}"
        wrapperAttrs["aria-orientation"] = "horizontal"
        if (!this._disabled) {
            wrapperAttrs["tabindex"] = "0"
        } else {
            wrapperAttrs["aria-disabled"] = "true"
        }

        let buttonAttrs = HashMap<String, String>()
        buttonAttrs["class"] = "el-slider__button"
        if (this._disabled) { buttonAttrs["class"] = "el-slider__button is-disabled" }
        let tipAttrs = HashMap<String, String>()
        tipAttrs["class"] = "el-slider__tip"
        let tipTextNode = text(tipStr)
        let wrapper = VNode("div", [
            VNode("div", [], attrs: Some(buttonAttrs)),
            VNode("span", [tipTextNode], attrs: Some(tipAttrs)),
        ], attrs: Some(wrapperAttrs))
        children.add(wrapper)

        // 停靠点
        if (this._showStops) {
            let stops = sliderStopPercents(this._min, this._max, this._step)
            let stopChildren = ArrayList<IComponent>()
            for (p in stops) {
                let stopAttrs = HashMap<String, String>()
                stopAttrs["class"] = "el-slider__stop"
                stopAttrs["style"] = "left:${sliderPercentString(p)}"
                stopChildren.add(VNode("div", [], attrs: Some(stopAttrs)))
            }
            children.add(VNode("div", stopChildren.toArray(), attrs: Some(HashMap<String, String>())))
        }

        VNode("div", [VNode("div", children.toArray(), attrs: Some(runwayAttrs), handlers: Some(hmap))], attrs: Some(attrs))
    }
}
