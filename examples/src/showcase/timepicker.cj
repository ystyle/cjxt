// TimePicker 时间选择演示
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.HashMap

public func demoTimePicker(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("时间选择（TimePicker）", [
            div([
                TimePicker().bind(st.timeValue),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("当前时间：${st.timeValue.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("点输入框开面板；点 时/分/秒 列选项即时写值并高亮；取消/确定关闭")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("禁用 / 可清除", [
            div([
                TimePicker().bind(st.timeValue).disabled(),
                TimePicker().bind(st.timeValue).clearable(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func propsTimePicker(): IComponent {
    div([
        propRow("bind(signal)", "Signal<String>", "值绑定（HH:mm:ss）"),
        propRow("placeholder", "String", "占位文本（默认 HH:mm:ss）"),
        propRow("disabled", "Bool", "禁用状态"),
        propRow("clearable", "Bool", "有值时显示清除按钮"),
    ])
}
