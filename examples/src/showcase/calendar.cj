// Calendar 日历演示
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.HashMap

public func demoCalendar(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("日历（Calendar）", [
            div([
                Calendar().bind(st.calendarValue).viewDate(st.calendarView),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("选中：${st.calendarValue.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("顶部 上月/今天/下月 切月；点日期选中并高亮（is-selected），今天 is-today 蓝色")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("周日开始（firstDayOfWeek=0）", [
            div([
                Calendar().bind(st.calendarValue).viewDate(st.calendarView).firstDayOfWeek(0),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func propsCalendar(): IComponent {
    div([
        propRow("bind(signal)", "Signal<String>", "选中日期（yyyy-MM-dd）"),
        propRow("viewDate(signal)", "Signal<String>", "显示月份外置信号（yyyy-MM-dd，持久化）"),
        propRow("firstDayOfWeek", "Int64", "周起始 0=周日 1=周一（默认 1）"),
        propRow("onSelect", "ActionHandler", "点击日期回调（值已写入 bind 信号）"),
    ])
}
