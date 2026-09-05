package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Space <: Component {
    var _children: Array<IComponent>
    var _size: SpaceSize = SpaceSize.Small
    var _sizePx: Option<Int64> = None
    var _direction: SpaceDirection = SpaceDirection.Horizontal
    var _wrap: Bool = false
    var _alignment: String = "center"
    var _fill: Bool = false
    var _fillRatio: Int64 = 100

    public init(children: Array<IComponent>) { this._children = children }
    public func size(v: Int64): Space { this._sizePx = Some(v); this }
    public func size(v: SpaceSize): Space { this._size = v; this }
    public func direction(v: SpaceDirection): Space { this._direction = v; this }
    public func wrap(): Space { this._wrap = true; this }
    public func align(v: String): Space { this._alignment = v; this }
    public func fill(): Space { this._fill = true; this }
    public func fillRatio(v: Int64): Space { this._fillRatio = v; this }

    public func render(): IComponent {
        var cls = "el-space el-space--${this._direction.asClass()}"
        if (this._wrap) { cls = "${cls} el-space--wrap" }
        let gapPx = match (this._sizePx) {
            case Some(px) => px
            case None => this._size.px()
        }
        // 分轴间隙（EP use-space rowGap/columnGap）：horizontal 行间隙 0（wrap 时均为 gap），vertical 列间隙 0
        var style = "align-items:${this._alignment};"
        if (this._wrap) {
            style = "${style}gap:${gapPx}px"
        } else {
            match (this._direction) {
                case Horizontal => style = "${style}column-gap:${gapPx}px;row-gap:0"
                case Vertical => style = "${style}row-gap:${gapPx}px;column-gap:0"
            }
        }
        let attrs = HashMap<String, String>([("class", cls), ("style", style)])
        let items = ArrayList<IComponent>()
        for (c in this._children) {
            // fill：子项 flexGrow 1 + minWidth fillRatio%（EP use-space）
            let itemStyle = if (this._fill) { "flex-grow:1;min-width:${this._fillRatio}%" } else { "" }
            items.add(div([c], attrs: Some(HashMap<String, String>([("class", "el-space__item"), ("style", itemStyle)]))))
        }
        div(items.toArray(), attrs: Some(attrs))
    }
}
