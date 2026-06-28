package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

let _PI: Float64 = 3.141592653589793

public class Progress <: Component {
    var _children: Array<IComponent> = []
    var _kind: ProgressKind = ProgressKind.Line
    var _percentage: Int64 = 0
    var _status: ProgressStatus = ProgressStatus.None
    var _strokeWidth: Int64 = 6
    var _textInside: Bool = false
    var _width: Int64 = 126
    var _showText: Bool = true
    var _color: String = ""
    var _striped: Bool = false
    var _stripedFlow: Bool = false
    var _indeterminate: Bool = false
    var _duration: Int64 = 3
    var _strokeLinecap: String = "round"

    public init() {}
    public func children(v: Array<IComponent>): Progress { this._children = v; this }
    public func kind(v: ProgressKind): Progress { this._kind = v; this }
    public func percentage(v: Int64): Progress { this._percentage = v; this }
    public func status(v: ProgressStatus): Progress { this._status = v; this }
    public func strokeWidth(v: Int64): Progress { this._strokeWidth = v; this }
    public func textInside(): Progress { this._textInside = true; this }
    public func width(v: Int64): Progress { this._width = v; this }
    public func showText(v: Bool): Progress { this._showText = v; this }
    public func color(v: String): Progress { this._color = v; this }
    public func striped(): Progress { this._striped = true; this }
    public func stripedFlow(): Progress { this._stripedFlow = true; this }
    public func indeterminate(): Progress { this._indeterminate = true; this }
    public func duration(v: Int64): Progress { this._duration = v; this }
    public func strokeLinecap(v: String): Progress { this._strokeLinecap = v; this }

    public func render(): IComponent {
        match (this._kind) {
            case ProgressKind.Line => this.renderLine()
            case _ => this.renderCircle()
        }
    }

    func getStatusColor(): String {
        if (this._color != "") { return this._color }
        match (this._status) {
            case ProgressStatus.Success => return "#13ce66"
            case ProgressStatus.Exception => return "#ff4949"
            case ProgressStatus.Warning => return "#e6a23c"
            case _ => return "#20a0ff"
        }
    }

    func getContentText(): String {
        match (this._status) {
            case ProgressStatus.None => "${this._percentage}%"
            case _ => ""
        }
    }

    func renderLine(): IComponent {
        var cls = "el-progress el-progress--line"
        let sc = this._status.asClass()
        if (sc != "") { cls = "${cls} is-${sc}" }
        if (!this._showText && this._children.size == 0) { cls = "${cls} el-progress--without-text" }
        if (this._textInside) { cls = "${cls} el-progress--text-inside" }

        var barInnerCls = "el-progress-bar__inner"
        if (this._indeterminate) { barInnerCls = "${barInnerCls} el-progress-bar__inner--indeterminate" }
        if (this._striped) { barInnerCls = "${barInnerCls} el-progress-bar__inner--striped" }
        if (this._stripedFlow) { barInnerCls = "${barInnerCls} el-progress-bar__inner--striped-flow" }

        let barStyle = "width:${this._percentage}%;animation-duration:${this._duration}s;background-color:${this.getStatusColor()}"
        let outerStyle = "height:${this._strokeWidth}px"
        var innerBar = VNode("div", [], attrs: Some(HashMap<String, String>([("class", barInnerCls), ("style", barStyle)])))
        if (this._textInside && (this._showText || this._children.size > 0)) {
            let textCls = "el-progress-bar__innerText"
            let textEl = if (this._children.size > 0) {
                div(this._children, attrs: Some(HashMap<String, String>([("class", textCls)])))
            } else {
                VNode("div", [text(this.getContentText())], attrs: Some(HashMap<String, String>([("class", textCls)])))
            }
            innerBar = VNode("div", [innerBar, textEl], attrs: Some(HashMap<String, String>([("class", barInnerCls), ("style", barStyle)])))
        }

        let bar = VNode("div", [VNode("div", [innerBar], attrs: Some(HashMap<String, String>([("class", "el-progress-bar__outer"), ("style", outerStyle)])))], attrs: Some(HashMap<String, String>([("class", "el-progress-bar")])))

        let parts = ArrayList<IComponent>()
        parts.add(bar)

        if (!this._textInside && (this._showText || this._children.size > 0)) {
            let textSize = 12.0 + Float64(this._strokeWidth) * 0.4
            let textStyle = "font-size:${textSize}px"
            let textEl = if (this._children.size > 0) {
                div(this._children, attrs: Some(HashMap<String, String>([("class", "el-progress__text"), ("style", textStyle)])))
            } else {
                VNode("span", [text(this.getContentText())], attrs: Some(HashMap<String, String>([("class", "el-progress__text"), ("style", textStyle)])))
            }
            parts.add(textEl)
        }

        let rootAttrs = HashMap<String, String>([
            ("class", cls),
            ("role", "progressbar"),
            ("aria-valuenow", this._percentage.toString()),
            ("aria-valuemin", "0"),
            ("aria-valuemax", "100")
        ])
        div(parts.toArray(), attrs: Some(rootAttrs))
    }

    func renderCircle(): IComponent {
        let cls = "el-progress el-progress--${this._kind.asClass()}"

        let relSW = (Float64(this._strokeWidth) / Float64(this._width)) * 100.0
        let rVal = 50.0 - relSW / 2.0
        let perimeter = 2.0 * _PI * rVal
        let rate = match (this._kind) {
            case ProgressKind.Dashboard => 0.75
            case _ => 1.0
        }
        let offset = (-perimeter * (1.0 - rate)) / 2.0
        let dashLen = perimeter * rate * Float64(this._percentage) / 100.0
        let trackDash = "${perimeter * rate}px, ${perimeter}px"
        let pathDash = "${dashLen}px, ${perimeter}px"
        let offsetStr = "${offset}px"

        let rStr = rVal.toString()
        let pathD = this.buildCirclePath(rStr, this._kind)

        let strokeColor = this.getStatusColor()
        let trackColor = "var(--el-fill-color-light, #e5e9f2)"
        let swStr = relSW.toString()

        let trackAttrs = HashMap<String, String>([
            ("class", "el-progress-circle__track"),
            ("d", pathD),
            ("stroke", trackColor),
            ("stroke-linecap", this._strokeLinecap),
            ("stroke-width", swStr),
            ("fill", "none"),
            ("style", "stroke-dasharray:${trackDash};stroke-dashoffset:${offsetStr}")
        ])
        let pathAttrs = HashMap<String, String>([
            ("class", "el-progress-circle__path"),
            ("d", pathD),
            ("stroke", strokeColor),
            ("fill", "none"),
            ("opacity", if (this._percentage > 0) { "1" } else { "0" }),
            ("stroke-linecap", this._strokeLinecap),
            ("stroke-width", swStr),
            ("style", "stroke-dasharray:${pathDash};stroke-dashoffset:${offsetStr};transition: stroke-dasharray 0.6s ease 0s, stroke 0.6s ease, opacity ease 0.6s")
        ])
        let svgAttrs = HashMap<String, String>([("viewBox", "0 0 100 100")])
        let svg = VNode("svg", [
            VNode("path", [], attrs: Some(trackAttrs)),
            VNode("path", [], attrs: Some(pathAttrs))
        ], attrs: Some(svgAttrs))

        let wrapStyle = "width:${this._width}px;height:${this._width}px"
        var wrapCls = cls
        let textSize = Float64(this._width) * 0.111111 + 2.0
        let textStyle = "font-size:${textSize}px"

        let parts = ArrayList<IComponent>()
        parts.add(svg)

        let sc = this._status.asClass()
        if (sc != "") { wrapCls = "${wrapCls} is-${sc}" }

        if (this._showText || this._children.size > 0) {
            let textEl = if (this._children.size > 0) {
                div(this._children, attrs: Some(HashMap<String, String>([("class", "el-progress__text"), ("style", textStyle)])))
            } else {
                VNode("span", [text(this.getContentText())], attrs: Some(HashMap<String, String>([("class", "el-progress__text"), ("style", textStyle)])))
            }
            parts.add(textEl)
        }

        div(parts.toArray(), attrs: Some(HashMap<String, String>([("class", wrapCls), ("style", wrapStyle)])))
    }

    func buildCirclePath(r: String, k: ProgressKind): String {
        match (k) {
            case ProgressKind.Dashboard => "M 50 50 m 0 ${r} a ${r} ${r} 0 1 1 0 -${r * 2} a ${r} ${r} 0 1 1 0 ${r * 2}"
            case _ => "M 50 50 m 0 -${r} a ${r} ${r} 0 1 1 0 ${r * 2} a ${r} ${r} 0 1 1 0 -${r * 2}"
        }
    }
}
