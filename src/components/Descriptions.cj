package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}
import std.convert

public class DescriptionsItem {
    var _children: Array<IComponent> = []
    var _label: String = ""
    var _span: Int64 = 1
    var _width: String = ""
    var _minWidth: String = ""
    var _labelWidth: String = ""
    var _align: DescriptionsAlign = DescriptionsAlign.Left
    var _labelAlign: DescriptionsAlign = DescriptionsAlign.Left
    var _className: String = ""
    var _labelClassName: String = ""

    public init() {}
    public func children(v: Array<IComponent>): DescriptionsItem { this._children = v; this }
    public func label(v: String): DescriptionsItem { this._label = v; this }
    public func span(v: Int64): DescriptionsItem { this._span = v; this }
    public func width(v: String): DescriptionsItem { this._width = v; this }
    public func minWidth(v: String): DescriptionsItem { this._minWidth = v; this }
    public func labelWidth(v: String): DescriptionsItem { this._labelWidth = v; this }
    public func align(v: DescriptionsAlign): DescriptionsItem { this._align = v; this }
    public func labelAlign(v: DescriptionsAlign): DescriptionsItem { this._labelAlign = v; this }
    public func className(v: String): DescriptionsItem { this._className = v; this }
    public func labelClassName(v: String): DescriptionsItem { this._labelClassName = v; this }
}

public class Descriptions <: Component {
    var _children: Array<IComponent> = []
    var _items: ArrayList<DescriptionsItem> = ArrayList<DescriptionsItem>()
    var _border: Bool = false
    var _column: Int64 = 3
    var _direction: DescriptionsDirection = DescriptionsDirection.Horizontal
    var _size: String = ""
    var _title: String = ""
    var _extra: String = ""
    var _labelWidth: String = ""
    var _titleSlot: Array<IComponent> = []
    var _extraSlot: Array<IComponent> = []

    public init() {}
    public func children(v: Array<IComponent>): Descriptions { this._children = v; this }
    public func add(item: DescriptionsItem): Descriptions { this._items.add(item); this }
    public func border(): Descriptions { this._border = true; this }
    public func column(v: Int64): Descriptions { this._column = v; this }
    public func direction(v: DescriptionsDirection): Descriptions { this._direction = v; this }
    public func size(v: String): Descriptions { this._size = v; this }
    public func title(v: String): Descriptions { this._title = v; this }
    public func extra(v: String): Descriptions { this._extra = v; this }
    public func labelWidth(v: String): Descriptions { this._labelWidth = v; this }
    public func slotTitle(v: Array<IComponent>): Descriptions { this._titleSlot = v; this }
    public func slotExtra(v: Array<IComponent>): Descriptions { this._extraSlot = v; this }

    public func render(): IComponent {
        var cls = "el-descriptions"
        if (this._size != "") { cls = "${cls} el-descriptions--${this._size}" }

        let headerParts = ArrayList<IComponent>()
        let titleParts = ArrayList<IComponent>()
        let extraParts = ArrayList<IComponent>()
        if (this._titleSlot.size > 0) { titleParts.add(Fragment(this._titleSlot))
        } else if (this._title != "") { titleParts.add(text(this._title)) }
        if (this._extraSlot.size > 0) { extraParts.add(Fragment(this._extraSlot))
        } else if (this._extra != "") { extraParts.add(text(this._extra)) }

        if (titleParts.size > 0) {
            headerParts.add(VNode("div", titleParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-descriptions__title")]))))
        }
        if (extraParts.size > 0) {
            headerParts.add(VNode("div", extraParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-descriptions__extra")]))))
        }

        let rowsLayout = this.buildRows()
        let tbodyParts = ArrayList<IComponent>()

        this.buildTbody(rowsLayout, tbodyParts, this._direction)

        var tableCls = "el-descriptions__table"
        if (this._border) { tableCls = "${tableCls} is-bordered" }
        let tableAttrs = HashMap<String, String>([
            ("class", tableCls),
            ("border", "0"),
            ("cellpadding", "0"),
            ("cellspacing", "0"),
            ("style", "width:100%")
        ])

        let tbody = VNode("tbody", tbodyParts.toArray())
        let table = VNode("table", [tbody], attrs: Some(tableAttrs))

        let wrapParts = ArrayList<IComponent>()
        if (headerParts.size > 0) {
            wrapParts.add(VNode("div", headerParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-descriptions__header")]))))
        }
        wrapParts.add(table)

        VNode("div", [
            div(wrapParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-descriptions__body")])))
        ], attrs: Some(HashMap<String, String>([("class", cls)])))
    }

    func buildRows(): ArrayList<Array<DescriptionsItem>> {
        let rows = ArrayList<Array<DescriptionsItem>>()
        var currentRow = ArrayList<DescriptionsItem>()
        var colCount: Int64 = 0
        for (item in this._items) {
            let span = if (item._span < 1) { 1 } else { item._span }
            if (colCount + span > this._column && currentRow.size > 0) {
                rows.add(currentRow.toArray())
                currentRow = ArrayList<DescriptionsItem>()
                colCount = 0
            }
            currentRow.add(item)
            colCount += span
        }
        if (currentRow.size > 0) { rows.add(currentRow.toArray()) }
        rows
    }

    func buildTbody(rowsLayout: ArrayList<Array<DescriptionsItem>>, tbodyParts: ArrayList<IComponent>, direction: DescriptionsDirection): Unit {
        match (direction) {
            case DescriptionsDirection.Vertical => this.buildTbodyVertical(rowsLayout, tbodyParts)
            case _ => this.buildTbodyHorizontal(rowsLayout, tbodyParts)
        }
    }

    func buildTbodyVertical(rowsLayout: ArrayList<Array<DescriptionsItem>>, tbodyParts: ArrayList<IComponent>): Unit {
        for (row in rowsLayout) {
            let rows = this.renderVerticalRow(row)
            for (r in rows) { tbodyParts.add(r) }
        }
    }

    func buildTbodyHorizontal(rowsLayout: ArrayList<Array<DescriptionsItem>>, tbodyParts: ArrayList<IComponent>): Unit {
        for (row in rowsLayout) {
            tbodyParts.add(this.renderHorizontalRow(row))
        }
    }

    func getCellStyle(item: DescriptionsItem): String {
        var s = if (item._width != "") { "width:${item._width}" } else { "" }
        let lw = if (item._labelWidth != "") { item._labelWidth } else { this._labelWidth }
        if (lw != "") { s = if (s != "") { "${s};min-width:${lw}" } else { "min-width:${lw}" } }
        if (item._minWidth != "") { s = if (s != "") { "${s};min-width:${item._minWidth}" } else { "min-width:${item._minWidth}" } }
        s
    }

    func renderHorizontalRow(row: Array<DescriptionsItem>): IComponent {
        let cells = ArrayList<IComponent>()
        for (item in row) {
            var labelCls = "el-descriptions__cell el-descriptions__label"
            var contentCls = "el-descriptions__cell el-descriptions__content"
            if (item._align.asClass() != "left") {
                labelCls = "${labelCls} is-${item._align.asClass()}"
                contentCls = "${contentCls} is-${item._align.asClass()}"
            }
            if (item._labelAlign.asClass() != "left") {
                labelCls = "${labelCls} is-${item._labelAlign.asClass()}"
            }
            if (item._labelClassName != "") { labelCls = "${labelCls} ${item._labelClassName}" }
            if (item._className != "") { contentCls = "${contentCls} ${item._className}" }

            let style = this.getCellStyle(item)

            if (this._border) {
                cells.add(VNode("td", [text(item._label)], attrs: Some(HashMap<String, String>([("class", labelCls), ("style", style)]))))
                cells.add(VNode("td", [
                    if (item._children.size > 0) { Fragment(item._children) } else { text("--") }
                ], attrs: Some(HashMap<String, String>([("class", contentCls), ("colspan", (item._span * 2 - 1).toString()), ("style", style)]))))
            } else {
                let bothCls = "el-descriptions__cell"
                cells.add(VNode("td", [
                    span([text(item._label)], attrs: Some(HashMap<String, String>([("class", "el-descriptions__label")]))),
                    span([if (item._children.size > 0) { Fragment(item._children) } else { text("--") }], attrs: Some(HashMap<String, String>([("class", "el-descriptions__content")])))
                ], attrs: Some(HashMap<String, String>([("class", bothCls), ("colspan", item._span.toString()), ("style", style)]))))
            }
        }
        VNode("tr", cells.toArray())
    }

    func renderVerticalRow(row: Array<DescriptionsItem>): ArrayList<IComponent> {
        let labelCells = ArrayList<IComponent>()
        let contentCells = ArrayList<IComponent>()
        for (item in row) {
            var labelCls = "el-descriptions__cell el-descriptions__label"
            var contentCls = "el-descriptions__cell el-descriptions__content"
            if (item._align.asClass() != "left") {
                labelCls = "${labelCls} is-${item._align.asClass()}"
                contentCls = "${contentCls} is-${item._align.asClass()}"
            }
            if (item._labelClassName != "") { labelCls = "${labelCls} ${item._labelClassName}" }
            if (item._className != "") { contentCls = "${contentCls} ${item._className}" }

            let style = this.getCellStyle(item)

            if (this._border) {
                labelCells.add(VNode("th", [text(item._label)], attrs: Some(HashMap<String, String>([("class", labelCls), ("colspan", item._span.toString()), ("style", style)]))))
                contentCells.add(VNode("td", [
                    if (item._children.size > 0) { Fragment(item._children) } else { text("--") }
                ], attrs: Some(HashMap<String, String>([("class", contentCls), ("colspan", item._span.toString()), ("style", style)]))))
            } else {
                labelCells.add(VNode("th", [text(item._label)], attrs: Some(HashMap<String, String>([("class", labelCls), ("colspan", item._span.toString()), ("style", style)]))))
                contentCells.add(VNode("td", [
                    if (item._children.size > 0) { Fragment(item._children) } else { text("--") }
                ], attrs: Some(HashMap<String, String>([("class", contentCls), ("colspan", item._span.toString()), ("style", style)]))))
            }
        }
        ArrayList<IComponent>([VNode("tr", labelCells.toArray()), VNode("tr", contentCells.toArray())])
    }
}
