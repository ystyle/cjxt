package cjxt.components

import cjxt.*
import std.collection.HashMap

public class Icon <: Component {
    var _name: String
    var _size: String = "1em"
    var _color: String = ""

    public init(name: String) { this._name = name }
    public func size(v: String): Icon { this._size = v; this }
    public func color(v: String): Icon { this._color = v; this }

    public func render(): IComponent {
        let pathData = getIconSvg(this._name)
        let svgStyle = "width:${this._size};height:${this._size}"
        var iconStyle = "font-size:${this._size}"
        if (this._color != "") { iconStyle = "${iconStyle};color:${this._color}" }
        let iconCls = HashMap<String, String>([("class", "el-icon"), ("style", iconStyle)])
        let svgAttrs = HashMap<String, String>([
            ("xmlns", "http://www.w3.org/2000/svg"),
            ("viewBox", "0 0 1024 1024"),
            ("style", svgStyle)
        ])
        let d = if (pathData == "") {
            "M512 64a448 448 0 1 1 0 896 448 448 0 0 1 0-896m0 704a32 32 0 1 0 0-64 32 32 0 0 0 0 64zm64-416H480V320a32 32 0 0 0-64 0v128H320a32 32 0 0 0 0 64h128v128a32 32 0 0 0 64 0V512h128a32 32 0 0 0 0-64z"
        } else {
            pathData
        }
        let pathAttrs = HashMap<String, String>([("fill", "currentColor"), ("d", d)])
        let pathEl = VNode("path", [], attrs: Some(pathAttrs))
        VNode("span", [VNode("svg", [pathEl], attrs: Some(svgAttrs))], attrs: Some(iconCls))
    }
}
