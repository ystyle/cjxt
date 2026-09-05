package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// EP Calendar（calendar.vue + date-table.vue）：
// 表头周起始默认周一（中文习惯，EP zh locale firstDayOfWeek=1；0=周日可配）。
//   div.el-calendar
//     div.el-calendar__header > div.el-calendar__title("2026 年 9 月") + div.el-calendar__button-group(上月/今天/下月 small)
//     div.el-calendar__body
//       table.el-calendar-table[cellspacing=0][cellpadding=0]
//         thead > tr > th（周日起始 weekNames）
//         tbody > tr.el-calendar-table__row > td.{prev|current|next}[.is-selected][.is-today] > div.el-calendar-day > span
// 视图月：外部 viewDate(Signal<String>) 优先，内部信号兜底（父组件跨渲染重建会重置——业务请用外置）；
// 选中：bind(Signal<String>)；点击任意格 = 写入值 + onSelect 回调（对齐 EP pickDay）
public class Calendar <: Component {
    var _valueS: Option<Signal<String>> = None
    var _viewDate: Option<Signal<String>> = None
    var _viewS: Signal<String>
    var _firstDay: Int64 = 1
    var _selectH: Option<ActionHandler> = None

    public init() {
        this._viewS = Signal<String>(firstOfMonthKey(nowDateKey()))
    }
    public func bind(s: Signal<String>): Calendar { this._valueS = Some(s); this }
    public func viewDate(s: Signal<String>): Calendar { this._viewDate = Some(s); this }
    public func firstDayOfWeek(v: Int64): Calendar { this._firstDay = v; this }
    public func onSelect(h: ActionHandler): Calendar { this._selectH = Some(h); this }

    // 当前视图月份（外部信号优先）
    func viewKey(): String {
        match (this._viewDate) {
            case Some(s) => s.get()
            case None => this._viewS.get()
        }
    }

    func setViewKey(key: String): Unit {
        match (this._viewDate) {
            case Some(s) => s.set(key)
            case None => this._viewS.set(key)
        }
    }

    // "yyyy-MM-dd" → 当月首日 key
    func gotoMonthAction(n: Int64): ActionHandler {
        let base = this
        let handler: ActionHandler = { ctx =>
            let keep = base.viewKey()
            let d = parseDate(keep)
            match (d) {
                case Some(cd) =>
                    let nd = addMonths(cd.year, cd.month, n)
                    base.setViewKey(formatDate(nd[0], nd[1], 1))
                case None => ()
            }
            PatchResult.ReRender
        }
        handler
    }

    // 今天：视图切回今天所在月
    func todayAction(): ActionHandler {
        let base = this
        let handler: ActionHandler = { ctx =>
            base.setViewKey(firstOfMonthKey(nowDateKey()))
            PatchResult.ReRender
        }
        handler
    }

    func selectDayAction(cell: CalCell): ActionHandler {
        let vs = this._valueS
        let h = this._selectH
        let base = this
        let handler: ActionHandler = { ctx =>
            let key = formatDate(cell.year, cell.month, cell.day)
            match (vs) {
                case Some(s) => s.set(key)
                case None => ()
            }
            // 补位格（上/下月）点击：视图切到该格所在月（EP pickDay 语义：选择后月历跟随）
            if (!cell.inMonth) {
                base.setViewKey(formatDate(cell.year, cell.month, 1))
            }
            match (h) {
                case Some(hh) => runHandler(hh, ctx)
                case None => ()
            }
            PatchResult.ReRender
        }
        handler
    }

    public func render(): IComponent {
        let viewKey = this.viewKey()
        let d = match (parseDate(viewKey)) {
            case Some(cd) => cd
            case None => CalDate(1970, 1, 1)
        }
        let cells = monthGrid(d.year, d.month)
        let todayKey = nowDateKey()
        let valueKey = match (this._valueS) {
            case Some(s) => s.get()
            case None => ""
        }
        let weekNames = ["日", "一", "二", "三", "四", "五", "六"]

        // ===== header =====
        let headerParts = ArrayList<IComponent>()
        headerParts.add(VNode("div", [text("${d.year} 年 ${d.month} 月")], attrs: Some(HashMap<String, String>([("class", "el-calendar__title")]))))
        let grpParts = ArrayList<IComponent>()
        grpParts.add(this.navBtn("上月", this.gotoMonthAction(-1)))
        grpParts.add(this.navBtn("今天", this.todayAction()))
        grpParts.add(this.navBtn("下月", this.gotoMonthAction(1)))
        headerParts.add(VNode("div", grpParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-calendar__button-group")]))))

        // ===== weekday header =====
        let thParts = ArrayList<IComponent>()
        for (i in 0..7) {
            thParts.add(VNode("th", [text(weekNames[(i + this._firstDay) % 7])], attrs: Some(HashMap<String, String>([("scope", "col")]))))
        }
        let theadParts = ArrayList<IComponent>()
        theadParts.add(VNode("tr", thParts.toArray()))

        // ===== 42 格 body =====
        let tbodyParts = ArrayList<IComponent>()
        for (i in 0..6) {
            let rowParts = ArrayList<IComponent>()
            for (j in 0..7) {
                let cell = cells[i * 7 + j]
                let key = formatDate(cell.year, cell.month, cell.day)
                // td 类：current(当月)/prev(上月补位)/next(下月补位) + is-selected/is-today
                var tdCls = ""
                if (cell.inMonth) {
                    tdCls = "current"
                } else if (cell.year > d.year || (cell.year == d.year && cell.month > d.month)) {
                    tdCls = "next"
                } else {
                    tdCls = "prev"
                }
                let isSel = cell.inMonth && key == valueKey
                let isToday = key == todayKey
                if (isSel) { tdCls = "${tdCls} is-selected" }
                if (isToday) { tdCls = "${tdCls} is-today" }
                let tdAttrs = HashMap<String, String>([("class", tdCls)])
                var td = VNode("td", [
                    VNode("div", [VNode("span", [text(cell.text.toString())])], attrs: Some(HashMap<String, String>([("class", "el-calendar-day")]))),
                ], attrs: Some(tdAttrs))
                td = td.onClick(this.selectDayAction(cell))
                rowParts.add(td)
            }
            tbodyParts.add(VNode("tr", rowParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-calendar-table__row")]))))
        }

        let bodyParts = ArrayList<IComponent>()
        bodyParts.add(VNode("table", [
            VNode("thead", theadParts.toArray()),
            VNode("tbody", tbodyParts.toArray()),
        ], attrs: Some(HashMap<String, String>([
            ("class", "el-calendar-table"),
            ("cellspacing", "0"),
            ("cellpadding", "0"),
        ]))))
        let body = VNode("div", bodyParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-calendar__body")])))

        VNode("div", [
            VNode("div", headerParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-calendar__header")]))),
            body,
        ], attrs: Some(HashMap<String, String>([("class", "el-calendar")])))
    }

    func navBtn(label: String, h: ActionHandler): IComponent {
        let btnAttrs = HashMap<String, String>([("class", "el-button el-button--small"), ("type", "button")])
        var btn = VNode("button", [VNode("span", [text(label)])], attrs: Some(btnAttrs))
        btn = btn.onClick(h)
        btn
    }
}

func runHandler(hh: ActionHandler, ctx: ActionContext): Unit {
    let _ = hh(ctx)
}

func firstOfMonthKey(dayKey: String): String {
    let d = parseDate(dayKey)
    match (d) {
        case Some(cd) => formatDate(cd.year, cd.month, 1)
        case None => formatDate(1970, 1, 1)
    }
}
