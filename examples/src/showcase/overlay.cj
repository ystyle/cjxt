// 浮层组件演示：Dialog / Drawer / Tooltip / Popover
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.{ArrayList, HashMap}

public func demoDialog(st: ShowcaseState): Array<IComponent> {
    let openHandler: ActionHandler = { ctx =>
        st.dialogVisible.set(true)
        PatchResult.ReRender
    }
    let btn = Button("打开对话框")
        .kind(ButtonKind.Primary)
        .onClick(openHandler)
    let closeHandler: ActionHandler = { ctx =>
        st.dialogVisible.set(false)
        PatchResult.ReRender
    }
    let dlg = Dialog([text("这是一个对话框内容。")])
        .visible(st.dialogVisible)
        .title("提示")
        .width("420px")
        .closeOnClickModal(false)
        .footer([
            Button("取消").onClick(closeHandler),
            Button("确认").kind(ButtonKind.Primary).onClick(closeHandler),
        ])
    [
        demoSection("基础对话框", [
            div([
                btn.render(),
                dlg.render(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoDrawer(st: ShowcaseState): Array<IComponent> {
    let dirOptions = ArrayList<MenuItem>()
    for (d in ["rtl", "ltr", "ttb", "btt"]) {
        let active = d == st.drawerDirection.get()
        let dirHandler: ActionHandler = { ctx =>
            st.drawerDirection.set(d)
            PatchResult.ReRender
        }
        dirOptions.add(MenuItem(d, [text(d)]).active(active).onClick(dirHandler))
    }
    let dirMenu = Menu().mode(MenuMode.Vertical)
    for (opt in dirOptions) { dirMenu.add(opt) }

    let openHandler: ActionHandler = { ctx =>
        st.drawerVisible.set(true)
        PatchResult.ReRender
    }
    let closeHandler: ActionHandler = { ctx =>
        st.drawerVisible.set(false)
        PatchResult.ReRender
    }
    let dir = st.drawerDirection.get()
    let direction = match (dir) {
        case "ltr" => DrawerDirection.LTR
        case "rtl" => DrawerDirection.RTL
        case "ttb" => DrawerDirection.TTB
        case "btt" => DrawerDirection.BTT
        case _ => DrawerDirection.RTL
    }
    let d = Drawer([text("这是一个抽屉内容。")])
        .visible(st.drawerVisible)
        .title("抽屉标题")
        .direction(direction)
        .footer([
            Button("取消").onClick(closeHandler),
            Button("确认").kind(ButtonKind.Primary).onClick(closeHandler),
        ])
    [
        demoSection("基础抽屉", [
            div([
                Button("打开抽屉").kind(ButtonKind.Primary).onClick(openHandler),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            d.render(),
        ]),
        demoSection("方向切换", [
            div([
                div([text("方向：")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
                dirMenu.render(),
            ]),
        ]),
    ]
}

public func demoTooltip(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础 Tooltip", [
            div([
                Tooltip("这是一个提示信息", "悬停查看提示")
                    .placement(Placement.Top)
                    .effect(TooltipEffect.Dark)
                    .trigger(TooltipTrigger.Hover),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoPopover(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础 Popover", [
            div([
                Popover("这是一个弹出内容", "点击弹出", "标题")
                    .placement(Placement.Bottom)
                    .trigger(TooltipTrigger.Click)
                    .width(200),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

// ============ Props ============

public func propsDialog(): IComponent {
    div([
        propRow("Dialog(children)", "Array<IComponent>", "对话框主体内容"),
        propRow("Dialog.visible(signal)", "Signal<Bool>", "控制对话框显示/隐藏"),
        propRow("Dialog.title", "String", "对话框标题"),
        propRow("Dialog.width", "String (默认 50%)", "对话框宽度"),
        propRow("Dialog.top", "String (默认 15vh)", "对话框距顶部距离"),
        propRow("Dialog.showClose", "Bool (默认 true)", "是否显示关闭按钮"),
        propRow("Dialog.closeOnClickModal", "Bool (默认 true)", "点击遮罩层是否关闭"),
        propRow("Dialog.modal", "Bool (默认 true)", "是否显示遮罩层"),
        propRow("Dialog.center / alignCenter", "Bool", "居中标题/垂直居中"),
        propRow("Dialog.fullscreen", "Bool", "全屏模式"),
        propRow("Dialog.destroyOnClose", "Bool", "关闭时销毁内容"),
        propRow("Dialog.beforeClose(fn)", "ActionHandler", "关闭前回调"),
        propRow("Dialog.header / footer", "Array<IComponent>", "自定义头部/底部内容"),
    ])
}

public func propsDrawer(): IComponent {
    div([
        propRow("Drawer(children)", "Array<IComponent>", "抽屉主体内容"),
        propRow("Drawer.visible(signal)", "Signal<Bool>", "控制抽屉显示/隐藏"),
        propRow("Drawer.title", "String", "抽屉标题"),
        propRow("Drawer.direction", "LTR | RTL | TTB | BTT", "弹出方向（默认 RTL）"),
        propRow("Drawer.size", "String (默认 30%)", "抽屉尺寸（宽/高）"),
        propRow("Drawer.showClose", "Bool (默认 true)", "是否显示关闭按钮"),
        propRow("Drawer.closeOnClickModal", "Bool (默认 true)", "点击遮罩层是否关闭"),
        propRow("Drawer.modal", "Bool (默认 true)", "是否显示遮罩层"),
        propRow("Drawer.withHeader", "Bool (默认 true)", "是否显示头部区域"),
        propRow("Drawer.destroyOnClose", "Bool", "关闭时销毁内容"),
        propRow("Drawer.beforeClose(fn)", "ActionHandler", "关闭前回调"),
        propRow("Drawer.header / footer", "Array<IComponent>", "自定义头部/底部内容"),
    ])
}

public func propsTooltip(): IComponent {
    div([
        propRow("content", "String", "提示文本"),
        propRow("triggerText", "String", "触发元素文本"),
        propRow("placement", "Placement", "弹出方向（Top/Bottom/Left/Right 等）"),
        propRow("effect", "TooltipEffect", "主题（Dark/Light）"),
        propRow("trigger", "TooltipTrigger", "触发方式（Hover/Click/Focus）"),
        propRow("showAfter", "Int64", "显示延迟（ms）"),
        propRow("hideAfter", "Int64", "隐藏延迟（ms）"),
        propRow("disabled", "Bool", "是否禁用"),
        propRow("onShow / onHide", "Event", "显示/隐藏事件"),
    ])
}

public func propsPopover(): IComponent {
    div([
        propRow("content", "String", "弹出内容文本"),
        propRow("triggerText", "String", "触发元素文本"),
        propRow("title", "String", "弹窗标题"),
        propRow("placement", "Placement", "弹出方向"),
        propRow("effect", "TooltipEffect", "主题（Dark/Light）"),
        propRow("trigger", "TooltipTrigger", "触发方式（Hover/Click/Focus）"),
        propRow("width", "Int64", "弹窗宽度（px）"),
        propRow("showAfter", "Int64", "显示延迟（ms）"),
        propRow("hideAfter", "Int64", "隐藏延迟（ms）"),
        propRow("disabled", "Bool", "是否禁用"),
        propRow("onShow / onHide", "Event", "显示/隐藏事件"),
    ])
}
