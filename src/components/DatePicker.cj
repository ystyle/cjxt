package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// ============ DatePicker / DateRangePicker（对齐 Element Plus date-picker） ============

func pickerEditorClass(isOpen: Bool, disabled: Bool, clearable: Bool, hasValue: Bool): String {
    var cls = "el-date-editor el-input el-input--prefix"
    if (clearable && hasValue) { cls = "${cls} el-input--suffix" }
    if (disabled) { cls = "${cls} is-disabled" }
    if (isOpen) { cls = "${cls} is-focused" }
    cls
}

func buildNavBtn(icon: String, label: String, h: ActionHandler): IComponent {
    VNode("button", [Icon(icon).render()], attrs: Some(HashMap<String, String>([("class", "el-picker-panel__icon-btn"), ("type", "button"), ("aria-label", label)]))).onClick(h)
}

// 星期表头行（周日起始，对齐 EP 默认）
func buildWeekdayRow(): IComponent {
    let names = ["日", "一", "二", "三", "四", "五", "六"]
    let cells = ArrayList<IComponent>()
    for (w in names) {
        cells.add(VNode("th", [text(w)], attrs: Some(HashMap<String, String>([("scope", "col")]))))
    }
    VNode("tr", cells.toArray())
}

// 日期网格表格（DatePicker / DateRangePicker 共用）
func buildDayTable(vy: Int64, vm: Int64, currentValue: String, range: Option<(String, String)>, viewYear: Int64, viewMonth: Int64, todayKey: String, disabled: Bool, onPick: (ActionContext, String) -> PatchResult): IComponent {
    let grid = monthGrid(vy, vm)
    let tbodyRows = ArrayList<IComponent>()
    tbodyRows.add(buildWeekdayRow())
    var row = 0
    while (row < 6) {
        let cells = ArrayList<IComponent>()
        for (col in 0..7) {
            let cell = grid[row * 7 + col]
            cells.add(buildDayCell(cell, currentValue, range, viewYear, viewMonth, todayKey, disabled, onPick))
        }
        tbodyRows.add(VNode("tr", cells.toArray()))
        row += 1
    }
    VNode("table", [VNode("tbody", tbodyRows.toArray())], attrs: Some(HashMap<String, String>([("class", "el-date-table")])))
}

func buildDayCell(cell: CalCell, currentValue: String, range: Option<(String, String)>, viewYear: Int64, viewMonth: Int64, todayKey: String, disabled: Bool, onPick: (ActionContext, String) -> PatchResult): IComponent {
    var cls = ""
    let key = formatDate(cell.year, cell.month, cell.day)
    if (cell.inMonth) {
        cls = "available"
        if (isToday(cell.year, cell.month, cell.day, todayKey)) { cls = "${cls} today" }
        if (key == currentValue) { cls = "${cls} current selected" }
        match (range) {
            case Some((s, e)) =>
                if (key == s) {
                    cls = "${cls} start-date in-range current selected"
                } else if (key == e) {
                    cls = "${cls} end-date in-range current selected"
                } else if (dateKeyLess(s, key) && dateKeyLess(key, e)) {
                    cls = "${cls} in-range"
                }
            case None => ()
        }
    } else {
        let viewMk = viewYear * 12 + viewMonth
        let cellMk = cell.year * 12 + cell.month
        cls = if (cellMk < viewMk) { "prev-month" } else { "next-month" }
    }
    if (disabled) { cls = "${cls} disabled" }
    let textEl = VNode("span", [text(cell.text.toString())], attrs: Some(HashMap<String, String>([("class", "el-date-table-cell__text")])))
    let inner = VNode("div", [textEl], attrs: Some(HashMap<String, String>([("class", "el-date-table-cell")])))
    var td = VNode("td", [inner], attrs: Some(HashMap<String, String>([("class", cls)])))
    if (!disabled && cell.inMonth) {
        let ky = key
        td = td.onClick({ ctx => onPick(ctx, ky) })
    }
    td
}

// 计算当前选中/待选区间（用于 range 高亮）：返回 (start, end)，无则 None
func computeRange(startVal: String, endVal: String, pendingStart: Option<String>): Option<(String, String)> {
    if (startVal != "" && endVal != "") {
        if (dateKeyLessOrEq(startVal, endVal)) { Some((startVal, endVal)) } else { Some((endVal, startVal)) }
    } else {
        match (pendingStart) {
            case Some(s) => if (s != "") { Some((s, s)) } else { None }
            case None => None
        }
    }
}

// 日期 key（"yyyy-MM-dd"）按数值比较，避免依赖 String 的 < 运算符
func dateKeyLess(a: String, b: String): Bool {
    match (parseDate(a)) {
        case Some(da) => match (parseDate(b)) {
            case Some(db) => compareDate(da, db) < 0
            case None => false
        }
        case None => false
    }
}

func dateKeyLessOrEq(a: String, b: String): Bool {
    match (parseDate(a)) {
        case Some(da) => match (parseDate(b)) {
            case Some(db) => compareDate(da, db) <= 0
            case None => false
        }
        case None => false
    }
}

// ── DateRangePicker：区间日期 ──

public class DateRangePicker <: Component {
    var _startSignal: Option<Signal<String>> = None
    var _endSignal: Option<Signal<String>> = None
    var _startPlaceholder: String = "开始日期"
    var _endPlaceholder: String = "结束日期"
    var _disabled: Bool = false
    var _clearable: Bool = false
    var _onChangeHandler: Option<ActionHandler> = None
    var _open: Signal<Bool>
    var _viewYear: Signal<Int64>
    var _viewMonth: Signal<Int64>
    var _pendingStart: Signal<Option<String>>
    let _todayKey: String

    public init() {
        this._todayKey = nowDateKey()
        this._open = Signal<Bool>(false)
        this._viewYear = Signal<Int64>(2026)
        this._viewMonth = Signal<Int64>(1)
        this._pendingStart = Signal<Option<String>>(Option<String>.None)
    }

    public func start(signal: Signal<String>): DateRangePicker { this._startSignal = Some(signal); this }
    public func end(signal: Signal<String>): DateRangePicker { this._endSignal = Some(signal); this }
    public func startPlaceholder(v: String): DateRangePicker { this._startPlaceholder = v; this }
    public func endPlaceholder(v: String): DateRangePicker { this._endPlaceholder = v; this }
    public func disabled(): DateRangePicker { this._disabled = true; this }
    public func clearable(): DateRangePicker { this._clearable = true; this }
    public func onChange(h: ActionHandler): DateRangePicker { this._onChangeHandler = Some(h); this }

    private func startVal(): String {
        match (this._startSignal) { case Some(s) => s.get(); case None => "" }
    }

    private func endVal(): String {
        match (this._endSignal) { case Some(s) => s.get(); case None => "" }
    }

    // 显示用起始值：选择中（pendingStart 已设）时显示待选起点、结束置空，
    // 避免把起点写进外部信号导致父组件重渲染 → new 出新实例 → 面板关闭
    private func displayStart(): String {
        match (this._pendingStart.get()) {
            case Some(s) => s
            case None => this.startVal()
        }
    }

    private func displayEnd(): String {
        match (this._pendingStart.get()) {
            case Some(_) => ""
            case None => this.endVal()
        }
    }

    private func setStart(v: String): Unit {
        match (this._startSignal) { case Some(s) => s.set(v); case None => () }
    }

    private func setEnd(v: String): Unit {
        match (this._endSignal) { case Some(s) => s.set(v); case None => () }
    }

    public func render(): IComponent {
        let isOpen = this._open.get()
        let children = ArrayList<IComponent>()
        children.add(this.buildEditor())
        if (this._clearable && (this.startVal() != "" || this.endVal() != "") && !this._disabled) {
            children.add(VNode("span", [Icon("circle-close").render()], attrs: Some(HashMap<String, String>([("class", "el-range__close-icon"), ("style", "position:absolute;right:8px;top:50%;transform:translateY(-50%);cursor:pointer;z-index:2")]))).onClick({ ctx => this.onClear(ctx) }))
        }
        if (isOpen) { children.add(this.buildPanel()) }
        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("style", "position:relative;display:inline-block")])))
    }

    private func buildEditor(): IComponent {
        let children = ArrayList<IComponent>()
        let startAttrs = HashMap<String, String>([("class", "el-range-input"), ("placeholder", this._startPlaceholder), ("readonly", "true")])
        if (this.displayStart() != "") { startAttrs["value"] = this.displayStart() }
        children.add(VNode("input", [], attrs: Some(startAttrs)))
        children.add(VNode("span", [text(" - ")], attrs: Some(HashMap<String, String>([("class", "el-range-separator")]))))
        let endAttrs = HashMap<String, String>([("class", "el-range-input"), ("placeholder", this._endPlaceholder), ("readonly", "true")])
        if (this.displayEnd() != "") { endAttrs["value"] = this.displayEnd() }
        children.add(VNode("input", [], attrs: Some(endAttrs)))
        var cls = "el-date-editor el-range-editor el-input__wrapper"
        if (this._disabled) { cls = "${cls} is-disabled" }
        if (this._open.get()) { cls = "${cls} is-focused" }
        var editor = VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
        if (!this._disabled) {
            editor = editor.onClick({ ctx => this.toggleOpen(ctx) })
        }
        editor
    }

    private func buildPanel(): IComponent {
        let vy = this._viewYear.get()
        let vm = this._viewMonth.get()
        let next = addMonths(vy, vm, 1)
        let range = computeRange(this.displayStart(), this.displayEnd(), this._pendingStart.get())
        let leftContent = this.buildRangeContent(vy, vm, true, range)
        let rightContent = this.buildRangeContent(next[0], next[1], false, range)
        let body = VNode("div", [leftContent, rightContent], attrs: Some(HashMap<String, String>([("class", "el-picker-panel__body")])))
        let panel = VNode("div", [body], attrs: Some(HashMap<String, String>([("class", "el-picker-panel el-date-range-picker")])))
        VNode("div", [panel], attrs: Some(HashMap<String, String>([("class", "el-picker__popper el-popper"), ("style", "position:absolute;top:100%;left:0;z-index:1000;margin-top:4px")])))
    }

    private func buildRangeContent(vy: Int64, vm: Int64, isLeft: Bool, range: Option<(String, String)>): IComponent {
        let headerChildren = ArrayList<IComponent>()
        if (isLeft) {
            headerChildren.add(buildNavBtn("arrow-left", "上个月", { ctx => this.onNavMonth(ctx, -1) }))
            headerChildren.add(VNode("span", [text("${vy} 年 ${vm} 月")], attrs: Some(HashMap<String, String>([("class", "el-date-range-picker__header-label")]))))
        } else {
            headerChildren.add(VNode("span", [text("${vy} 年 ${vm} 月")], attrs: Some(HashMap<String, String>([("class", "el-date-range-picker__header-label")]))))
            headerChildren.add(buildNavBtn("arrow-right", "下个月", { ctx => this.onNavMonth(ctx, 1) }))
        }
        let header = VNode("div", headerChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-date-range-picker__header")])))
        let table = buildDayTable(vy, vm, "", range, this._viewYear.get(), this._viewMonth.get(), this._todayKey, this._disabled, { ctx, key => this.onPick(ctx, key) })
        let contentCls = if (isLeft) { "el-picker-panel__content el-date-range-picker__content is-left" } else { "el-picker-panel__content el-date-range-picker__content is-right" }
        VNode("div", [header, table], attrs: Some(HashMap<String, String>([("class", contentCls)])))
    }

    private func toggleOpen(ctx: ActionContext): PatchResult {
        if (this._disabled) { return PatchResult.ReRender }
        let opening = !this._open.get()
        if (opening) { this.syncView() }
        this._open.set(opening)
        PatchResult.ReRender
    }

    private func syncView(): Unit {
        let sv = this.startVal()
        let base = match (parseDate(sv)) {
            case Some(d) => Some(CalDate(d.year, d.month, 1))
            case None => parseDate(this._todayKey)
        }
        match (base) {
            case Some(d) => this._viewYear.set(d.year); this._viewMonth.set(d.month)
            case None => ()
        }
    }

    private func onNavMonth(ctx: ActionContext, delta: Int64): PatchResult {
        let vy = this._viewYear.get()
        let vm = this._viewMonth.get()
        let next = addMonths(vy, vm, delta)
        this._viewYear.set(next[0])
        this._viewMonth.set(next[1])
        PatchResult.ReRender
    }

    private func onPick(ctx: ActionContext, key: String): PatchResult {
        if (this._disabled) { return PatchResult.ReRender }
        match (this._pendingStart.get()) {
            case Some(s) =>
                var start = s
                var end = key
                if (dateKeyLess(end, start)) {
                    let t = start
                    start = end
                    end = t
                }
                // 两端都选齐才写外部信号（避免中途触发父组件重渲染关闭面板）
                this.setStart(start)
                this.setEnd(end)
                this._pendingStart.set(Option<String>.None)
                this._open.set(false)
                this.invokeHandler(this._onChangeHandler, ctx)
            case None =>
                // 第一次点选：只写内部 pendingStart，面板保持打开等第二次点选
                this._pendingStart.set(Some(key))
        }
        PatchResult.ReRender
    }

    private func onClear(ctx: ActionContext): PatchResult {
        this.setStart("")
        this.setEnd("")
        this._pendingStart.set(Option<String>.None)
        this._open.set(false)
        this.invokeHandler(this._onChangeHandler, ctx)
        PatchResult.ReRender
    }

    private func invokeHandler(h: Option<ActionHandler>, ctx: ActionContext): Unit {
        match (h) {
            case Some(fn) => runCb(fn, ctx)
            case None => ()
        }
    }
}

// ── DatePicker：单选日期 ──

public class DatePicker <: Component {
    var _signal: Option<Signal<String>> = None
    var _placeholder: String = "请选择日期"
    var _disabled: Bool = false
    var _clearable: Bool = false
    var _onChangeHandler: Option<ActionHandler> = None
    var _open: Signal<Bool>
    var _viewYear: Signal<Int64>
    var _viewMonth: Signal<Int64>
    let _todayKey: String

    public init() {
        this._todayKey = nowDateKey()
        this._open = Signal<Bool>(false)
        this._viewYear = Signal<Int64>(2026)
        this._viewMonth = Signal<Int64>(1)
    }

    public func bind(signal: Signal<String>): DatePicker { this._signal = Some(signal); this }
    public func placeholder(v: String): DatePicker { this._placeholder = v; this }
    public func disabled(): DatePicker { this._disabled = true; this }
    public func clearable(): DatePicker { this._clearable = true; this }
    public func onChange(h: ActionHandler): DatePicker { this._onChangeHandler = Some(h); this }

    public func render(): IComponent {
        let isOpen = this._open.get()
        let currentValue = this.value()
        let children = ArrayList<IComponent>()
        children.add(this.buildInput(currentValue, isOpen))
        match (this.buildClear({ ctx => this.onClear(ctx) })) {
            case Some(c) => children.add(c)
            case None => ()
        }
        if (isOpen) { children.add(this.buildPanel(currentValue)) }
        let cls = pickerEditorClass(isOpen, this._disabled, this._clearable, currentValue != "")
        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls), ("style", "position:relative;display:inline-block")])))
    }

    private func value(): String {
        match (this._signal) { case Some(s) => s.get(); case None => "" }
    }

    private func setValue(v: String): Unit {
        match (this._signal) { case Some(s) => s.set(v); case None => () }
    }

    // ── 输入框 ──
    private func buildInput(currentValue: String, isOpen: Bool): IComponent {
        let prefixInner = VNode("span", [Icon("calendar").render()], attrs: Some(HashMap<String, String>([("class", "el-input__prefix-inner")])))
        let prefix = VNode("span", [prefixInner], attrs: Some(HashMap<String, String>([("class", "el-input__prefix")])))
        let inputAttrs = HashMap<String, String>([("class", "el-input__inner"), ("placeholder", this._placeholder), ("readonly", "true")])
        if (currentValue != "") { inputAttrs["value"] = currentValue }
        let inputEl = VNode("input", [], attrs: Some(inputAttrs))
        let wrapperChildren = ArrayList<IComponent>()
        wrapperChildren.add(prefix)
        wrapperChildren.add(inputEl)
        var wrapper = VNode("div", wrapperChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-input__wrapper")])))
        if (!this._disabled) {
            wrapper = wrapper.onClick({ ctx => this.toggleOpen(ctx) })
        }
        wrapper
    }

    // 清除图标独立于 wrapper 渲染（避免点击清除时又触发打开）
    private func buildClear(onClear: ActionHandler): Option<IComponent> {
        if (this._clearable && this.value() != "" && !this._disabled) {
            Some(VNode("span", [Icon("circle-close").render()], attrs: Some(HashMap<String, String>([("class", "el-input__suffix el-input__suffix-inner"), ("style", "position:absolute;right:8px;top:50%;transform:translateY(-50%);cursor:pointer;z-index:2")]))).onClick(onClear))
        } else {
            None
        }
    }

    // ── 面板 ──
    private func buildPanel(currentValue: String): IComponent {
        let vy = this._viewYear.get()
        let vm = this._viewMonth.get()
        let headerChildren = ArrayList<IComponent>()
        headerChildren.add(buildNavBtn("arrow-left", "上个月", { ctx => this.onNavMonth(ctx, -1) }))
        headerChildren.add(VNode("span", [text("${vy} 年")], attrs: Some(HashMap<String, String>([("class", "el-date-picker__header-label")]))))
        headerChildren.add(VNode("span", [text("${vm} 月")], attrs: Some(HashMap<String, String>([("class", "el-date-picker__header-label")]))))
        headerChildren.add(buildNavBtn("arrow-right", "下个月", { ctx => this.onNavMonth(ctx, 1) }))
        let header = VNode("div", headerChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-date-picker__header")])))
        let table = buildDayTable(vy, vm, currentValue, Option<(String, String)>.None, vy, vm, this._todayKey, this._disabled, { ctx, key => this.onPick(ctx, key) })
        let body = VNode("div", [header, table], attrs: Some(HashMap<String, String>([("class", "el-picker-panel__body")])))
        let panel = VNode("div", [body], attrs: Some(HashMap<String, String>([("class", "el-picker-panel el-date-picker")])))
        VNode("div", [panel], attrs: Some(HashMap<String, String>([("class", "el-picker__popper el-popper"), ("style", "position:absolute;top:100%;left:0;z-index:1000;margin-top:4px")])))
    }

    // ── 交互 ──
    private func toggleOpen(ctx: ActionContext): PatchResult {
        if (this._disabled) { return PatchResult.ReRender }
        let opening = !this._open.get()
        if (opening) { this.syncView() }
        this._open.set(opening)
        PatchResult.ReRender
    }

    private func syncView(): Unit {
        let selected = this.value()
        let base = match (parseDate(selected)) {
            case Some(d) => Some(CalDate(d.year, d.month, 1))
            case None => parseDate(this._todayKey)
        }
        match (base) {
            case Some(d) => this._viewYear.set(d.year); this._viewMonth.set(d.month)
            case None => ()
        }
    }

    private func onNavMonth(ctx: ActionContext, delta: Int64): PatchResult {
        let vy = this._viewYear.get()
        let vm = this._viewMonth.get()
        let next = addMonths(vy, vm, delta)
        this._viewYear.set(next[0])
        this._viewMonth.set(next[1])
        PatchResult.ReRender
    }

    private func onPick(ctx: ActionContext, key: String): PatchResult {
        if (this._disabled) { return PatchResult.ReRender }
        this.setValue(key)
        this._open.set(false)
        this.invokeHandler(this._onChangeHandler, ctx)
        PatchResult.ReRender
    }

    private func onClear(ctx: ActionContext): PatchResult {
        this.setValue("")
        this._open.set(false)
        this.invokeHandler(this._onChangeHandler, ctx)
        PatchResult.ReRender
    }

    private func invokeHandler(h: Option<ActionHandler>, ctx: ActionContext): Unit {
        match (h) {
            case Some(fn) => runCb(fn, ctx)
            case None => ()
        }
    }
}
