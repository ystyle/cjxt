package cjxt.components

import cjxt.*
import std.collection.HashMap

public func Card(children: Array<IComponent>, header!: String = "", shadow!: CardShadow = CardShadow.Always): IComponent {
    var cls = "el-card is-${shadow.asClass()}-shadow"
    let clsMap = HashMap<String, String>([("class", cls)])

    if (header != "") {
        let hdr = HashMap<String, String>([("class", "el-card__header")])
        let body = HashMap<String, String>([("class", "el-card__body")])
        div([div([text(header)], attrs: Some(hdr)), div(children, attrs: Some(body))], attrs: Some(clsMap))
    } else {
        let body = HashMap<String, String>([("class", "el-card__body")])
        div([div(children, attrs: Some(body))], attrs: Some(clsMap))
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
