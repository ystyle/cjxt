package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

/// 泛型列配置：文本取值用 accessor（支持排序），富渲染用 render
public class TableColumn<T> {
    var _colType: TableColumnType = TableColumnType.Default
    var _accessor: Option<(T) -> String> = None
    var _label: String = ""
    var _width: Int64 = 0
    var _minWidth: Int64 = 0
    var _fixed: Option<TableFixed> = None
    var _sortable: Bool = false
    var _align: TableAlign = TableAlign.Left
    var _showOverflowTooltip: Bool = false
    var _className: String = ""
    var _formatter: Option<(String) -> String> = None
    var _render: Option<(T, Int64) -> IComponent> = None
    var _reserveSelection: Bool = false
    var _selectable: Option<(T) -> Bool> = None

    public init() {}

    public func colType(v: TableColumnType): TableColumn<T> { this._colType = v; this }
    public func accessor(fn: (T) -> String): TableColumn<T> { this._accessor = Some(fn); this }
    public func label(v: String): TableColumn<T> { this._label = v; this }
    public func width(v: Int64): TableColumn<T> { this._width = v; this }
    public func minWidth(v: Int64): TableColumn<T> { this._minWidth = v; this }
    public func fixed(v: TableFixed): TableColumn<T> { this._fixed = Some(v); this }
    public func sortable(): TableColumn<T> { this._sortable = true; this }
    public func align(v: TableAlign): TableColumn<T> { this._align = v; this }
    public func showOverflowTooltip(): TableColumn<T> { this._showOverflowTooltip = true; this }
    public func className(v: String): TableColumn<T> { this._className = v; this }
    public func formatter(f: (String) -> String): TableColumn<T> { this._formatter = Some(f); this }
    // 自定义单元格渲染（row, rowIndex）→ IComponent；优先于 accessor/formatter
    public func render(fn: (T, Int64) -> IComponent): TableColumn<T> { this._render = Some(fn); this }
    public func reserveSelection(): TableColumn<T> { this._reserveSelection = true; this }
    public func selectable(f: (T) -> Bool): TableColumn<T> { this._selectable = Some(f); this }
}

/// 泛型表格：行类型 T，列值经 accessor/render 回调访问
public class Table<T> <: Component {
    var _data: Signal<ArrayList<T>>
    var _columns: ArrayList<TableColumn<T>>
    var _stripe: Bool = false
    var _border: Bool = false
    var _height: String = ""
    var _maxHeight: String = ""
    var _size: ComponentSize2 = ComponentSize2.Default
    var _fit: Bool = true
    var _showHeader: Bool = true
    var _highlight: Bool = false
    var _emptyText: String = "No Data"
    var _showSummary: Bool = false
    var _sumText: String = "Sum"

    // 行/单元格/表头自定义 class 与 style 回调
    var _rowClassName: Option<(T, Int64) -> String> = None
    var _rowStyle: Option<(T, Int64) -> String> = None
    var _cellClassName: Option<(T, TableColumn<T>, Int64, Int64) -> String> = None
    var _cellStyle: Option<(T, TableColumn<T>, Int64, Int64) -> String> = None
    var _headerRowClassName: Option<(Int64) -> String> = None
    var _headerCellClassName: Option<(TableColumn<T>, Int64) -> String> = None
    var _headerRowStyle: Option<(Int64) -> String> = None
    var _headerCellStyle: Option<(TableColumn<T>, Int64) -> String> = None

    // 行唯一键（selection/currentRow 用；必须提供才能启用选择/当前行功能）
    var _rowKey: Option<(T) -> String> = None

    // 外部状态信号（可选）。Table 内部信号在父组件重渲染时会丢失状态，
    // 因此需要持久化的状态（排序、选中、当前行）建议通过外部 Signal 传入。
    var _sortColumnSignal: Option<Signal<String>> = None
    var _sortOrderSignal: Option<Signal<SortOrder>> = None
    var _selectedRowsSignal: Option<Signal<ArrayList<T>>> = None
    var _currentRowSignal: Option<Signal<Option<T>>> = None

    // 行点击回调（row, rowIndex, ctx）→ PatchResult；与 highlight()（仅高亮当前行）并存
    var _onRowClick: Option<(T, Int64, ActionContext) -> PatchResult> = None

    // 内部 fallback 信号
    var _sortColumn: Signal<String>
    var _sortOrder: Signal<SortOrder>
    var _selectedRows: Signal<ArrayList<T>>
    var _currentRow: Signal<Option<T>>

    public init() {
        this._data = Signal<ArrayList<T>>(ArrayList<T>())
        this._columns = ArrayList<TableColumn<T>>()
        this._sortColumn = Signal<String>("")
        this._sortOrder = Signal<SortOrder>(SortOrder.None)
        this._selectedRows = Signal<ArrayList<T>>(ArrayList<T>())
        let noneVal: Option<T> = None
        this._currentRow = Signal<Option<T>>(noneVal)
    }

    public func data(signal: Signal<ArrayList<T>>): Table<T> {
        this._data = signal
        this
    }

    public func add(col: TableColumn<T>): Table<T> { this._columns.add(col); this }
    public func stripe(): Table<T> { this._stripe = true; this }
    public func border(): Table<T> { this._border = true; this }
    public func height(v: String): Table<T> { this._height = v; this }
    public func maxHeight(v: String): Table<T> { this._maxHeight = v; this }
    public func size(v: ComponentSize2): Table<T> { this._size = v; this }
    public func fit(v: Bool): Table<T> { this._fit = v; this }
    public func showHeader(v: Bool): Table<T> { this._showHeader = v; this }
    public func highlight(): Table<T> { this._highlight = true; this }
    public func emptyText(v: String): Table<T> { this._emptyText = v; this }
    public func showSummary(): Table<T> { this._showSummary = true; this }
    public func sumText(v: String): Table<T> { this._sumText = v; this }

    public func rowClassName(fn: (T, Int64) -> String): Table<T> {
        this._rowClassName = Some(fn); this
    }
    public func rowStyle(fn: (T, Int64) -> String): Table<T> {
        this._rowStyle = Some(fn); this
    }
    public func cellClassName(fn: (T, TableColumn<T>, Int64, Int64) -> String): Table<T> {
        this._cellClassName = Some(fn); this
    }
    public func cellStyle(fn: (T, TableColumn<T>, Int64, Int64) -> String): Table<T> {
        this._cellStyle = Some(fn); this
    }
    public func headerRowClassName(fn: (Int64) -> String): Table<T> {
        this._headerRowClassName = Some(fn); this
    }
    public func headerCellClassName(fn: (TableColumn<T>, Int64) -> String): Table<T> {
        this._headerCellClassName = Some(fn); this
    }
    public func headerRowStyle(fn: (Int64) -> String): Table<T> {
        this._headerRowStyle = Some(fn); this
    }
    public func headerCellStyle(fn: (TableColumn<T>, Int64) -> String): Table<T> {
        this._headerCellStyle = Some(fn); this
    }

    public func rowKey(fn: (T) -> String): Table<T> { this._rowKey = Some(fn); this }

    public func sortColumn(signal: Signal<String>): Table<T> { this._sortColumnSignal = Some(signal); this }
    public func sortOrder(signal: Signal<SortOrder>): Table<T> { this._sortOrderSignal = Some(signal); this }
    public func selectedRows(signal: Signal<ArrayList<T>>): Table<T> { this._selectedRowsSignal = Some(signal); this }
    public func currentRow(signal: Signal<Option<T>>): Table<T> { this._currentRowSignal = Some(signal); this }
    public func onRowClick(fn: (T, Int64, ActionContext) -> PatchResult): Table<T> { this._onRowClick = Some(fn); this }

    private func getRowKey(row: T): String {
        match (this._rowKey) {
            case Some(f) => f(row)
            case None => ""
        }
    }

    private func getSortColumn(): String {
        match (this._sortColumnSignal) {
            case Some(s) => s.get()
            case None => this._sortColumn.get()
        }
    }
    private func setSortColumn(v: String): Unit {
        match (this._sortColumnSignal) {
            case Some(s) => s.set(v)
            case None => this._sortColumn.set(v)
        }
    }
    private func getSortOrder(): SortOrder {
        match (this._sortOrderSignal) {
            case Some(s) => s.get()
            case None => this._sortOrder.get()
        }
    }
    private func setSortOrder(v: SortOrder): Unit {
        match (this._sortOrderSignal) {
            case Some(s) => s.set(v)
            case None => this._sortOrder.set(v)
        }
    }
    private func getSelectedRows(): ArrayList<T> {
        match (this._selectedRowsSignal) {
            case Some(s) => s.get()
            case None => this._selectedRows.get()
        }
    }
    private func setSelectedRows(v: ArrayList<T>): Unit {
        match (this._selectedRowsSignal) {
            case Some(s) => s.set(v)
            case None => this._selectedRows.set(v)
        }
    }
    private func getCurrentRow(): Option<T> {
        match (this._currentRowSignal) {
            case Some(s) => s.get()
            case None => this._currentRow.get()
        }
    }
    private func setCurrentRowValue(v: Option<T>): Unit {
        match (this._currentRowSignal) {
            case Some(s) => s.set(v)
            case None => this._currentRow.set(v)
        }
    }

    // 按列 accessor 排序并写回数据信号
    private func toggleSort(col: TableColumn<T>): Unit {
        let currentCol = this.getSortColumn()
        let currentOrder = this.getSortOrder()
        if (currentCol != col._label) {
            this.setSortColumn(col._label)
            this.setSortOrder(SortOrder.Ascending)
        } else {
            this.setSortOrder(nextOrder(currentOrder))
        }
        let order = this.getSortOrder()
        match (col._accessor) {
            case Some(get) =>
                if (!isNoneOrder(order)) {
                    let sorted = sortByAccessor<T>(this._data.get(), get, order)
                    this._data.set(sorted)
                }
            case None => ()
        }
    }

    private func toggleRowSelection(row: T, selected: Bool): Unit {
        let current = this.getSelectedRows()
        if (selected) {
            current.add(row)
        } else {
            let idx = findRowIndex<T>(current, row, getRowKey)
            if (idx >= 0) { current.remove(idx..idx + 1) }
        }
        this.setSelectedRows(current)
    }

    private func isRowSelected(row: T): Bool {
        let key = this.getRowKey(row)
        for (r in this.getSelectedRows()) {
            if (this.getRowKey(r) == key) { return true }
        }
        false
    }

    private func toggleSelectAll(): Unit {
        let data = this._data.get()
        let selected = this.getSelectedRows()
        let allSelected = data.size > 0 && selected.size == data.size
        if (allSelected) {
            this.setSelectedRows(ArrayList<T>())
        } else {
            let newSel = ArrayList<T>()
            for (r in data) { newSel.add(r) }
            this.setSelectedRows(newSel)
        }
    }

    private func allSelected(): Bool {
        let data = this._data.get()
        let selected = this.getSelectedRows()
        data.size > 0 && selected.size == data.size
    }

    public func render(): IComponent {
        var data = this._data.get()
        var cls = "el-table"
        if (this._stripe) { cls = "${cls} el-table--striped" }
        if (this._border) { cls = "${cls} el-table--border" }
        let sc = this._size.asClass()
        if (sc != "") { cls = "${cls} el-table--${sc}" }
        if (this._fit) { cls = "${cls} el-table--fit" }
        if (!this._showHeader) { cls = "${cls} el-table__header-hidden" }
        if (this._highlight) { cls = "${cls} el-table--highlight-current-row" }
        cls = "${cls} el-table--enable-row-hover el-table--layout-fixed"

        var style = ""
        if (this._height != "") { style = "height: ${this._height}" }
        if (this._maxHeight != "") { style = if (style == "") { "max-height: ${this._maxHeight}" } else { "${style};max-height: ${this._maxHeight}" } }
        let attrs = HashMap<String, String>([("class", cls), ("style", style)])

        let content = ArrayList<IComponent>()

        if (this._showHeader) {
            content.add(this.renderHeader())
        }

        if (data.size == 0) {
            content.add(this.renderEmpty())
        } else {
            let body = this.renderBody(data)
            content.add(body)
        }

        if (this._showSummary && data.size > 0) {
            content.add(this.renderSummary(data))
        }

        // 列宽总和超过容器时，允许 inner-wrapper 水平滚动，保证表头与表体一起滚动，
        // 同时保留外层 .el-table 的 overflow:hidden 以正确显示 EP 伪元素边框。
        let innerStyle = "overflow-x: auto"
        let inner = VNode("div", content.toArray(),
            attrs: Some(HashMap<String, String>([("class", "el-table__inner-wrapper"), ("style", innerStyle)])))
        VNode("div", [inner], attrs: Some(attrs))
    }

    private func renderColGroup(): IComponent {
        let cols = ArrayList<IComponent>()
        for (col in this._columns) {
            let attrs = HashMap<String, String>()
            if (col._width > 0) {
                attrs.add("style", "width: ${col._width}px")
            } else if (col._minWidth > 0) {
                attrs.add("style", "min-width: ${col._minWidth}px")
            }
            cols.add(VNode("col", [], attrs: Some(attrs)))
        }
        VNode("colgroup", cols.toArray())
    }

    private func tableWidth(): Int64 {
        var total = 0
        for (col in this._columns) {
            total += if (col._width > 0) { col._width } else { col._minWidth }
        }
        total
    }

    private func renderHeader(): IComponent {
        let headerRow = ArrayList<IComponent>()
        var ci: Int64 = 0
        for (col in this._columns) {
            headerRow.add(this.renderHeaderCell(col, ci))
            ci++
        }
        var hRowCls = "el-table__header-row"
        match (this._headerRowClassName) {
            case Some(fn) =>
                let extra = fn(0)
                if (extra != "") { hRowCls = "${hRowCls} ${extra}" }
            case None => ()
        }
        let hRowAttrs = HashMap<String, String>([("class", hRowCls)])
        match (this._headerRowStyle) {
            case Some(fn) =>
                let sval = fn(0)
                if (sval != "") { hRowAttrs.add("style", sval) }
            case None => ()
        }
        let tableAttrs = HashMap<String, String>([
            ("class", "el-table__header"),
            ("style", "width: max(${this.tableWidth()}px, 100%)"),
            ("border", "0"),
            ("cellpadding", "0"),
            ("cellspacing", "0")
        ])
        let table = VNode("table", [this.renderColGroup(), VNode("thead", [VNode("tr", headerRow.toArray(), attrs: Some(hRowAttrs))])],
            attrs: Some(tableAttrs))
        let scroll = VNode("div", [table],
            attrs: Some(HashMap<String, String>([("class", "el-table__header-wrapper")])))
        scroll
    }

    private func renderHeaderCell(col: TableColumn<T>, ci: Int64): IComponent {
        var cls = "el-table__cell"
        if (isSelectionType(col._colType)) { cls = "${cls} el-table-column--selection" }
        if (col._className != "") { cls = "${cls} ${col._className}" }
        if (col._sortable) { cls = "${cls} is-sortable" }
        let ac = col._align.asClass()
        if (ac != "") { cls = "${cls} is-${ac}" }

        match (this._headerCellClassName) {
            case Some(fn) =>
                let extra = fn(col, ci)
                if (extra != "") { cls = "${cls} ${extra}" }
            case None => ()
        }

        let currentSortCol = this.getSortColumn()
        let currentOrder = this.getSortOrder()
        let sortActive = col._sortable && currentSortCol == col._label && !isNoneOrder(currentOrder)
        if (sortActive) { cls = "${cls} ${currentOrder.asClass()}" }

        let cellAttrs = HashMap<String, String>([("class", cls)])
        if (col._width > 0) { cellAttrs.add("style", "width: ${col._width}px") }
        if (col._minWidth > 0) { cellAttrs.add("style", "min-width: ${col._minWidth}px") }
        this.applyFixedStyle(col, cellAttrs)

        match (this._headerCellStyle) {
            case Some(fn) =>
                let sval = fn(col, ci)
                if (sval != "") {
                    let existing = cellAttrs.get("style")
                    match (existing) {
                        case Some(e) => cellAttrs["style"] = "${e};${sval}"
                        case None => cellAttrs.add("style", sval)
                    }
                }
            case None => ()
        }

        let content = ArrayList<IComponent>()

        if (isSelectionType(col._colType)) {
            this.buildSelectionHeader(content)
        } else if (isIndexType(col._colType)) {
            content.add(text(col._label))
        } else if (col._sortable) {
            this.buildSortableHeader(col, content)
        } else {
            content.add(text(col._label))
        }

        let cell = VNode("div", content.toArray(), attrs: Some(HashMap<String, String>([("class", "cell")])))
        var th = VNode("th", [cell], attrs: Some(cellAttrs))
        if (col._sortable && col._accessor.isSome()) {
            let c = col
            let wrapped: ActionHandler = { ctx => this.toggleSort(c); PatchResult.ReRender }
            th = th.onClick(wrapped)
        }
        th
    }

    private func applyFixedStyle(col: TableColumn<T>, attrs: HashMap<String, String>): Unit {
        match (col._fixed) {
            case Some(f) => this.applyFixedStyleInner(f, attrs)
            case None => ()
        }
    }

    private func applyFixedStyleInner(f: TableFixed, attrs: HashMap<String, String>): Unit {
        let pos = this.fixedPos(f)
        attrs.add("style", "position: sticky; ${pos}")
    }

    private func fixedPos(f: TableFixed): String {
        if (f.asFixedAttr() == "left") { "left: 0" } else { "right: 0" }
    }

    private func buildSelectionHeader(content: ArrayList<IComponent>): Unit {
        let checked = this.allSelected()
        let wrapped: ActionHandler = { ctx => this.toggleSelectAll(); PatchResult.ReRender }
        content.add(this.renderCheckbox(checked, wrapped))
    }

    private func renderCheckbox(checked: Bool, onClick: ActionHandler): IComponent {
        var labelCls = "el-checkbox"
        if (checked) { labelCls = "${labelCls} is-checked" }
        var inputSpanCls = "el-checkbox__input"
        if (checked) { inputSpanCls = "${inputSpanCls} is-checked" }
        let inputAttrs = HashMap<String, String>([("type", "checkbox"), ("class", "el-checkbox__original")])
        if (checked) { inputAttrs.add("checked", "checked") }
        let inputEl = VNode("input", [], attrs: Some(inputAttrs))
        let innerSpan = VNode("span", [], attrs: Some(HashMap<String, String>([("class", "el-checkbox__inner")])))
        let inputSpan = VNode("span", [inputEl, innerSpan], attrs: Some(HashMap<String, String>([("class", inputSpanCls)])))
        VNode("label", [inputSpan], attrs: Some(HashMap<String, String>([("class", labelCls)]))).onClick(onClick)
    }

    private func buildSortableHeader(col: TableColumn<T>, content: ArrayList<IComponent>): Unit {
        content.add(text(col._label))
        // EP caret wrapper rendered after label
        let caretCls = "caret-wrapper"
        let up = VNode("i", [], attrs: Some(HashMap<String, String>([("class", "sort-caret ascending")])))
        let down = VNode("i", [], attrs: Some(HashMap<String, String>([("class", "sort-caret descending")])))
        let caret = VNode("span", [up, down], attrs: Some(HashMap<String, String>([("class", caretCls)])))
        content.add(caret)
    }

    private func renderBody(data: ArrayList<T>): IComponent {
        let rows = ArrayList<IComponent>()
        var idx: Int64 = 0
        for (row in data) {
            rows.add(this.renderRow(row, idx))
            idx++
        }
        let tableAttrs = HashMap<String, String>([
            ("class", "el-table__body"),
            ("style", "width: max(${this.tableWidth()}px, 100%)"),
            ("border", "0"),
            ("cellpadding", "0"),
            ("cellspacing", "0")
        ])
        let table = VNode("table", [this.renderColGroup(), VNode("tbody", rows.toArray())],
            attrs: Some(tableAttrs))
        let scroll = VNode("div", [table],
            attrs: Some(HashMap<String, String>([("class", "el-table__body-wrapper")])))
        scroll
    }

    private func renderRow(row: T, index: Int64): IComponent {
        let cells = ArrayList<IComponent>()
        for (col in this._columns) {
            cells.add(this.renderCell(col, row, index))
        }
        var rowCls = "el-table__row"
        if (this._stripe && index % 2 == 1) {
            rowCls = "${rowCls} el-table__row--striped"
        }
        if (this._highlight && this.isCurrentRow(row)) {
            rowCls = "${rowCls} current-row"
        }
        match (this._rowClassName) {
            case Some(fn) =>
                let extra = fn(row, index)
                if (extra != "") { rowCls = "${rowCls} ${extra}" }
            case None => ()
        }
        let rowAttrs = HashMap<String, String>([("class", rowCls)])
        match (this._rowStyle) {
            case Some(fn) =>
                let sval = fn(row, index)
                if (sval != "") { rowAttrs.add("style", sval) }
            case None => ()
        }
        var tr = VNode("tr", cells.toArray(), attrs: Some(rowAttrs))
        let hasRowClick = match (this._onRowClick) {
            case Some(_) => true
            case None => false
        }
        if (this._highlight || hasRowClick) {
            let r = row
            let wrapped: ActionHandler = { ctx =>
                if (this._highlight) { this.setCurrentRow(r) }
                match (this._onRowClick) {
                    case Some(fn) => fn(r, index, ctx)
                    case None => PatchResult.ReRender
                }
            }
            tr = tr.onClick(wrapped)
        }
        tr
    }

    private func renderCell(col: TableColumn<T>, row: T, index: Int64): IComponent {
        var cls = "el-table__cell"
        if (isSelectionType(col._colType)) { cls = "${cls} el-table-column--selection" }
        if (col._className != "") { cls = "${cls} ${col._className}" }
        let ac = col._align.asClass()
        if (ac != "") { cls = "${cls} is-${ac}" }

        match (this._cellClassName) {
            case Some(fn) =>
                let extra = fn(row, col, index, 0)
                if (extra != "") { cls = "${cls} ${extra}" }
            case None => ()
        }

        let cellAttrs = HashMap<String, String>([("class", cls)])
        if (col._width > 0) { cellAttrs.add("style", "width: ${col._width}px") }
        if (col._minWidth > 0) { cellAttrs.add("style", "min-width: ${col._minWidth}px") }

        match (this._cellStyle) {
            case Some(fn) =>
                let sval = fn(row, col, index, 0)
                if (sval != "") {
                    let existing = cellAttrs.get("style")
                    match (existing) {
                        case Some(e) => cellAttrs["style"] = "${e};${sval}"
                        case None => cellAttrs.add("style", sval)
                    }
                }
            case None => ()
        }

        this.applyFixedStyle(col, cellAttrs)

        let content = ArrayList<IComponent>()

        if (isSelectionType(col._colType)) {
            this.buildSelectionCell(row, content)
        } else if (isIndexType(col._colType)) {
            this.buildIndexCell(index, content)
        } else {
            this.buildDefaultCell(col, row, index, content)
        }

        let cell = VNode("div", content.toArray(), attrs: Some(HashMap<String, String>([("class", "cell"), ("style", "white-space: nowrap; overflow: hidden; text-overflow: ellipsis")])))
        VNode("td", [cell], attrs: Some(cellAttrs))
    }

    private func buildSelectionCell(row: T, content: ArrayList<IComponent>): Unit {
        let selected = this.isRowSelected(row)
        let r = row
        let wrapped: ActionHandler = { ctx => this.toggleRowSelection(r, !selected); PatchResult.ReRender }
        content.add(this.renderCheckbox(selected, wrapped))
    }

    private func buildIndexCell(index: Int64, content: ArrayList<IComponent>): Unit {
        content.add(text("${index + 1}"))
    }

    private func buildDefaultCell(col: TableColumn<T>, row: T, index: Int64, content: ArrayList<IComponent>): Unit {
        match (col._render) {
            case Some(fn) => content.add(fn(row, index))
            case None =>
                let raw = getColVal<T>(col, row)
                let display = match (col._formatter) {
                    case Some(f) => f(raw)
                    case None => raw
                }
                if (col._showOverflowTooltip && display.size > 30) {
                    content.add(text(display[0..27] + "..."))
                } else {
                    content.add(text(display))
                }
        }
    }

    private func renderEmpty(): IComponent {
        let empty = VNode("div", [text(this._emptyText)],
            attrs: Some(HashMap<String, String>([("class", "el-table__empty-text")])))
        VNode("div", [empty],
            attrs: Some(HashMap<String, String>([("class", "el-table__body-wrapper el-table__empty-block")])))
    }

    private func renderSummary(data: ArrayList<T>): IComponent {
        let cells = ArrayList<IComponent>()
        var first = true
        for (col in this._columns) {
            let cellAttrs = HashMap<String, String>([("class", "el-table__cell")])
            if (col._width > 0) { cellAttrs.add("style", "width: ${col._width}px") }
            if (first) {
                let cell = VNode("div", [text(this._sumText)], attrs: Some(HashMap<String, String>([("class", "cell")])))
                cells.add(VNode("td", [cell], attrs: Some(cellAttrs)))
                first = false
            } else {
                let cell = VNode("div", [text("")], attrs: Some(HashMap<String, String>([("class", "cell")])))
                cells.add(VNode("td", [cell], attrs: Some(cellAttrs)))
            }
        }
        let tableAttrs = HashMap<String, String>([
            ("class", "el-table__footer"),
            ("style", "width: max(${this.tableWidth()}px, 100%)"),
            ("border", "0"),
            ("cellpadding", "0"),
            ("cellspacing", "0")
        ])
        let table = VNode("table", [this.renderColGroup(), VNode("tfoot", [VNode("tr", cells.toArray())])],
            attrs: Some(tableAttrs))
        let summaryRow = VNode("div", [table],
            attrs: Some(HashMap<String, String>([("class", "el-table__footer-wrapper")])))
        summaryRow
    }

    private func setCurrentRow(row: T): Unit {
        this.setCurrentRowValue(Some(row))
    }

    private func isCurrentRow(row: T): Bool {
        match (this.getCurrentRow()) {
            case Some(r) => this.getRowKey(r) == this.getRowKey(row)
            case None => false
        }
    }
}

// --- 泛型排序（纯逻辑，可单测） ---

/// 按 accessor 取值排序（稳定冒泡；None 保持原序）
public func sortByAccessor<T>(rows: ArrayList<T>, get: (T) -> String, order: SortOrder): ArrayList<T> {
    if (isNoneOrder(order)) { return rows }
    let arr = rows.toArray()
    let n = arr.size
    var i: Int64 = 0
    while (i < n) {
        var j: Int64 = i + 1
        while (j < n) {
            let av = get(arr[i])
            let bv = get(arr[j])
            let cmp = compareStr(av, bv)
            let needSwap = if (isAscending(order)) { cmp > 0 } else { cmp < 0 }
            if (needSwap) {
                let tmp = arr[i]
                arr[i] = arr[j]
                arr[j] = tmp
            }
            j++
        }
        i++
    }
    let result = ArrayList<T>()
    for (r in arr) { result.add(r) }
    result
}

// --- 枚举辅助函数（代替 ==/!=） ---

func isNoneOrder(o: SortOrder): Bool {
    match (o) {
        case None => true
        case _ => false
    }
}

func isAscending(o: SortOrder): Bool {
    match (o) {
        case Ascending => true
        case _ => false
    }
}

func nextOrder(o: SortOrder): SortOrder {
    match (o) {
        case None => SortOrder.Ascending
        case Ascending => SortOrder.Descending
        case Descending => SortOrder.None
    }
}

func isSelectionType(t: TableColumnType): Bool {
    match (t) {
        case Selection => true
        case _ => false
    }
}

func isIndexType(t: TableColumnType): Bool {
    match (t) {
        case Index => true
        case _ => false
    }
}

// --- 通用辅助函数 ---

func compareStr(a: String, b: String): Int64 {
    if (a < b) { -1 }
    else if (a > b) { 1 }
    else { 0 }
}

func getColVal<T>(col: TableColumn<T>, row: T): String {
    match (col._accessor) {
        case Some(f) => f(row)
        case None => ""
    }
}

func findRowIndex<T>(rows: ArrayList<T>, target: T, keyOf: (T) -> String): Int64 {
    let targetKey = keyOf(target)
    var idx: Int64 = 0
    for (r in rows) {
        if (keyOf(r) == targetKey) { return idx }
        idx++
    }
    -1
}
