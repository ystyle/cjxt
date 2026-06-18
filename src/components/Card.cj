package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Card <: Component {
    var _children: Array<IComponent>
    var _header: Array<IComponent> = []
    var _footer: Array<IComponent> = []
    var _shadow: CardShadow = CardShadow.Always
    var _bodyStyle: String = ""
    var _bodyClass: String = ""

    public init(children: Array<IComponent>) { this._children = children }

    public func header(v: String): Card { this._header = [text(v)]; this }
    public func header(v: Array<IComponent>): Card { this._header = v; this }
    public func footer(v: String): Card { this._footer = [text(v)]; this }
    public func footer(v: Array<IComponent>): Card { this._footer = v; this }
    public func shadow(v: CardShadow): Card { this._shadow = v; this }
    public func bodyStyle(v: String): Card { this._bodyStyle = v; this }
    public func bodyClass(v: String): Card { this._bodyClass = v; this }

    public func render(): IComponent {
        let cls = "el-card is-${this._shadow.asClass()}-shadow"
        let bodyCls = if (this._bodyClass != "") { "el-card__body ${this._bodyClass}" } else { "el-card__body" }
        let bodyAttrs = HashMap<String, String>([("class", bodyCls)])
        if (this._bodyStyle != "") { bodyAttrs["style"] = this._bodyStyle }

        let parts = ArrayList<IComponent>()
        if (this._header.size > 0) {
            parts.add(div(this._header, attrs: Some(HashMap<String, String>([("class", "el-card__header")]))))
        }
        parts.add(div(this._children, attrs: Some(bodyAttrs)))
        if (this._footer.size > 0) {
            parts.add(div(this._footer, attrs: Some(HashMap<String, String>([("class", "el-card__footer")]))))
        }
        div(parts.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
    }
}

public func Row(children: Array<IComponent>, gutter!: Int64 = 0, justify!: RowJustify = RowJustify.Start, align!: RowAlign = RowAlign.Top): IComponent {
    var cls = "el-row"
    let justifyCls = justify.asClass()
    let alignCls = align.asClass()
    if (justifyCls != "start") { cls = "${cls} is-justify-${justifyCls}" }
    if (alignCls != "top") { cls = "${cls} is-align-${alignCls}" }
    let styleStr = if (gutter > 0) { "margin-left:-${gutter / 2}px;margin-right:-${gutter / 2}px" } else { "" }
    let attrs = HashMap<String, String>([("class", cls)])
    if (styleStr != "") { attrs["style"] = styleStr }
    div(children, attrs: Some(attrs))
}

public func Col(children: Array<IComponent>, span!: Int64 = 24, offset!: Int64 = 0, pull!: Int64 = 0, push!: Int64 = 0, gutter!: Int64 = 0): IComponent {
    var cls = "el-col el-col-${span}"
    if (offset > 0) { cls = "${cls} el-col-offset-${offset}" }
    if (pull > 0) { cls = "${cls} el-col-pull-${pull}" }
    if (push > 0) { cls = "${cls} el-col-push-${push}" }
    let styleStr = if (gutter > 0) { "padding-left:${gutter / 2}px;padding-right:${gutter / 2}px" } else { "" }
    let attrs = HashMap<String, String>([("class", cls)])
    if (styleStr != "") { attrs["style"] = styleStr }
    div(children, attrs: Some(attrs))
}
