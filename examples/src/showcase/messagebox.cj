// MessageBox 弹框演示：Alert / Confirm / Prompt
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.HashMap

public func demoMessageBox(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("Alert 提示框", [
            div([
                Button("打开提示").kind(ButtonKind.Primary).onClick(openAlertH(st)),
                MessageBox(st.messageBoxAlertVisible)
                    .kind(MessageBoxKind2.Alert)
                    .title("操作提示")
                    .message("这是一条 Alert 提示信息，点击“确定”关闭。"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("结果：${st.messageBoxResult.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("Confirm 确认框（警告图标）", [
            div([
                Button("删除数据").kind(ButtonKind.Danger).onClick(openConfirmH(st)),
                MessageBox(st.messageBoxConfirmVisible)
                    .kind(MessageBoxKind2.Confirm)
                    .title("确认删除")
                    .message("删除后不可恢复，确定要继续吗？")
                    .confirmText("删除")
                    .cancelText("取消")
                    .onConfirm({ ctx =>
                        st.messageBoxResult.set("已确认删除")
                        PatchResult.ReRender
                    })
                    .onCancel({ ctx =>
                        st.messageBoxResult.set("已取消")
                        PatchResult.ReRender
                    }),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("结果：${st.messageBoxResult.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("Prompt 输入框（回车确认）", [
            div([
                Button("输入名称").onClick(openPromptH(st)),
                MessageBox(st.messageBoxPromptVisible)
                    .kind(MessageBoxKind2.Prompt)
                    .title("请输入名称")
                    .message("名称将用于新项目")
                    .placeholder("项目名称")
                    .value(st.messageBoxPromptValue)
                    .onConfirm({ ctx =>
                        let v = st.messageBoxPromptValue.get()
                        let text2 = if (v == "") { "未输入" } else { "已输入：${v}" }
                        st.messageBoxResult.set(text2)
                        PatchResult.ReRender
                    }),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("结果：${st.messageBoxResult.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("点“输入名称”打开框 → 输入文字后回车或点确定 → 结果行显示输入值")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

// Button.onClick 重载歧义：显式 ActionHandler 包装
func openAlertH(st: ShowcaseState): ActionHandler {
    let handler: ActionHandler = { ctx =>
        st.messageBoxResult.set("未操作")
        st.messageBoxAlertVisible.set(true)
        PatchResult.ReRender
    }
    handler
}
func openConfirmH(st: ShowcaseState): ActionHandler {
    let handler: ActionHandler = { ctx =>
        st.messageBoxResult.set("未操作")
        st.messageBoxConfirmVisible.set(true)
        PatchResult.ReRender
    }
    handler
}
func openPromptH(st: ShowcaseState): ActionHandler {
    let handler: ActionHandler = { ctx =>
        st.messageBoxResult.set("未操作")
        st.messageBoxPromptVisible.set(true)
        PatchResult.ReRender
    }
    handler
}

public func propsMessageBox(): IComponent {
    div([
        propRow("MessageBox(visible)", "Signal<Bool>", "显隐外置信号（跨渲染持久化）"),
        propRow("kind", "Alert | Confirm | Prompt", "Alert 仅确定 / Confirm 取消+确定 / Prompt 带输入框"),
        propRow("icon", "None | Success | Warning | Error | Info", "状态图标（默认依 kind：Confirm=Warning）"),
        propRow("title / message", "String", "标题 / 内容文案"),
        propRow("confirmText / cancelText", "String", "按钮文案（默认 确定 / 取消）"),
        propRow("showClose / closeOnClickModal", "Bool", "关闭按钮 / 点击遮罩关闭"),
        propRow("center", "Bool", "居中布局（图标入标题行）"),
        propRow("value / placeholder", "Signal<String> · String", "Prompt 输入绑定与占位"),
        propRow("onConfirm / onCancel", "ActionHandler", "确定（Prompt 附值）/ 取消回调"),
    ])
}
