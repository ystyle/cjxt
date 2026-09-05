// 反馈组件演示：Message / Notification / Loading / Skeleton
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.HashMap

public func demoAlert(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("信息提示", [
            div([
                Alert().title("成功提示").kind(AlertKind2.Success).showIcon().description("这是一条成功提示，显示描述信息").closable(),
                Alert().title("警告信息").kind(AlertKind2.Warning).showIcon().description("注意数据版本，操作前请备份"),
                Alert().title("错误信息").kind(AlertKind2.Error).showIcon().closable(),
                Alert().title("普通信息").kind(AlertKind2.Info).showIcon().description("普通提示信息"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func propsAlert(): IComponent {
    div([
        propRow("title", "String", "标题"),
        propRow("kind", "Success | Warning | Error | Info", "类型"),
        propRow("description", "String", "描述内容"),
        propRow("closable", "false", "是否可关闭"),
        propRow("showIcon", "false", "是否显示图标"),
        propRow("center / effect", "false / light", "居中 / 主题"),
    ], attrs: Some(HashMap<String, String>([("class", cls("row"))])))
}

public func demoMessage(st: ShowcaseState): Array<IComponent> {
    let q = MessageQueue(st.messageItems)
    let successH: ActionHandler = { ctx => q.success("这是一条成功提示"); PatchResult.ReRender }
    let warningH: ActionHandler = { ctx => q.warning("这是一条警告提示"); PatchResult.ReRender }
    let errorH: ActionHandler = { ctx => q.error("这是一条错误提示"); PatchResult.ReRender }
    let infoH: ActionHandler = { ctx => q.info("这是一条普通提示"); PatchResult.ReRender }
    [
        demoSection("消息提示（Message，3 秒自动消失，点击任意处可关闭）", [
            div([
                PrimaryButton("成功").onClick(successH),
                WarningButton("警告").onClick(warningH),
                DangerButton("错误").onClick(errorH),
                InfoButton("信息").onClick(infoH),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            MessageHost().bind(st.messageItems),
        ]),
    ]
}

public func demoNotification(st: ShowcaseState): Array<IComponent> {
    let q = NotificationQueue(st.notificationItems)
    let successH: ActionHandler = { ctx => q.success("成功通知", "操作已成功完成，数据已保存。"); PatchResult.ReRender }
    let warningH: ActionHandler = { ctx => q.warning("警告通知", "检测到异常，请检查配置。"); PatchResult.ReRender }
    let errorH: ActionHandler = { ctx => q.error("错误通知", "操作失败，请重试。"); PatchResult.ReRender }
    [
        demoSection("通知（Notification，右上角，4.5 秒自动消失）", [
            div([
                PrimaryButton("成功").onClick(successH),
                WarningButton("警告").onClick(warningH),
                DangerButton("错误").onClick(errorH),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            NotificationHost().bind(st.notificationItems),
        ]),
    ]
}

public func demoLoading(st: ShowcaseState): Array<IComponent> {
    let toggleH: ActionHandler = { ctx => st.loadingVisible.set(!st.loadingVisible.get()); PatchResult.ReRender }
    [
        demoSection("加载遮罩（Loading，绑定 Signal<Bool>）", [
            div([
                PrimaryButton("切换加载状态").onClick(toggleH),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Loading().bind(st.loadingVisible).label("拼命加载中..."),
                div([text("这是被加载遮罩覆盖的内容区域")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            ], attrs: Some(HashMap<String, String>([("style", "position:relative;min-height:140px;border:1px solid #e5e7eb;border-radius:8px;display:flex;align-items:center;justify-content:center")]))),
        ]),
    ]
}

public func demoSkeleton(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("骨架屏（Skeleton）", [
            div([Skeleton().rows(3)], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("不带动画", [
            div([Skeleton().rows(2).noAnimated()], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

// ============ Props ============

public func propsMessage(): IComponent {
    div([
        propRow("MessageQueue.success/warning/error/info(text)", "Unit", "服务端入队消息（3s 自动消失）"),
        propRow("MessageHost.bind", "Signal<ArrayList<MessageItem>>", "消息列表信号绑定"),
    ])
}

public func propsNotification(): IComponent {
    div([
        propRow("NotificationQueue.success/warning/error/info(title, text)", "Unit", "服务端入队通知（4.5s 自动消失）"),
        propRow("NotificationHost.bind", "Signal<ArrayList<NotificationItem>>", "通知列表信号绑定"),
    ])
}

public func propsLoading(): IComponent {
    div([
        propRow("bind(signal)", "Signal<Bool>", "加载遮罩绑定"),
        propRow("label", "String", "加载文案"),
        propRow("fullscreen", "Bool", "全屏遮罩"),
    ])
}

public func propsSkeleton(): IComponent {
    div([
        propRow("rows", "Int64", "段落行数"),
        propRow("animated / noAnimated", "Bool", "动画 / 静态骨架"),
    ])
}
