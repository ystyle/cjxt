// 导航组件演示：Tabs / Breadcrumb / Steps / Dropdown
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.HashMap

public func demoTabs(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础标签（line）", [
            div([
                Tabs([
                    TabPane([text("用户管理内容：这里是用户列表相关功能。")], "tab1", "用户管理"),
                    TabPane([text("配置管理内容：这里是系统配置相关功能。")], "tab2", "配置管理"),
                    TabPane([text("角色管理内容：这里是角色与权限相关功能。")], "tab3", "角色管理"),
                ]).bind(st.activeTab),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("卡片标签（card）", [
            div([
                Tabs([
                    TabPane([text("选项 A 的内容。")], "a", "选项A"),
                    TabPane([text("选项 B 的内容。")], "b", "选项B"),
                    TabPane([text("这个标签被禁用。")], "c", "禁用项").disabled(),
                ]).bind(st.activeTab).tabType("card"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("边框卡片（border-card）", [
            div([
                Tabs([
                    TabPane([text("标签页 1 的内容。")], "t1", "标签页 1"),
                    TabPane([text("标签页 2 的内容。")], "t2", "标签页 2"),
                    TabPane([text("标签页 3 的内容。")], "t3", "标签页 3"),
                ]).bind(st.activeTab).tabType("border-card"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("联动状态", [
            div([text("当前激活标签：${st.activeTab.get()}（三个 Tabs 共享信号联动）")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoBreadcrumb(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("面包屑导航（Breadcrumb）", [
            div([
                Breadcrumb([
                    BreadcrumbItem().content("首页").to("/"),
                    BreadcrumbItem().content("组件库").to("/showcase"),
                    BreadcrumbItem().content("面包屑"),
                ]),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("自定义分隔符", [
            div([
                Breadcrumb([
                    BreadcrumbItem().content("用户管理"),
                    BreadcrumbItem().content("角色管理"),
                    BreadcrumbItem().content("权限配置"),
                ]).separator(">"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoSteps(st: ShowcaseState): Array<IComponent> {
    let stepBack: ActionHandler = { ctx =>
        let cur = st.stepsActive.get()
        if (cur > 1) { st.stepsActive.set(cur - 1) }
        PatchResult.ReRender
    }
    let stepNext: ActionHandler = { ctx =>
        let cur = st.stepsActive.get()
        if (cur < 4) { st.stepsActive.set(cur + 1) }
        PatchResult.ReRender
    }
    [
        demoSection("步骤条（Steps）——当前第 ${st.stepsActive.get()} 步", [
            div([
                Steps([
                    StepItem().title("填写信息").description("基本信息与联系方式"),
                    StepItem().title("上传附件").description("证明文件与资料"),
                    StepItem().title("确认提交").description("核对后提交申请"),
                ], st.stepsActive).space("33%"),
            ], attrs: Some(HashMap<String, String>([("style", "width:100%")]))),
            div([
                Button("上一步").onClick(stepBack),
                Button("下一步").onClick(stepNext),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("垂直方向", [
            div([
                Steps([
                    StepItem().title("创建订单"),
                    StepItem().title("等待审批").status("error"),
                    StepItem().title("完成"),
                ], st.stepsActive).direction("vertical"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoDropdown(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("下拉菜单（Dropdown）", [
            div([
                Dropdown(Button("更多操作")).menu([
                    DropdownItem().content("编辑").command("edit"),
                    DropdownItem().content("复制").command("copy"),
                    DropdownItem().content("删除").command("delete").divided(),
                    DropdownItem().content("禁用项").command("disabled").disabled(true),
                ]).onCommand { cmd =>
                    st.dropdownResult.set("选择了：${cmd}")
                    PatchResult.ReRender
                },
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("结果：${st.dropdownResult.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("触发方式：点击触发面板；菜单项点击回传 command 并关闭面板；divided 分隔线；disabled 禁点")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

// ============ Props ============

public func propsTabs(): IComponent {
    div([
        propRow("TabPane(name / label)", "String", "标签标识 / 显示文本"),
        propRow("TabPane.disabled", "Bool", "禁用标签"),
        propRow("Tabs.tabType", "line | card | border-card", "标签页类型"),
        propRow("Tabs.position", "top | bottom | left | right", "标签位置"),
        propRow("Tabs.bind(signal)", "Signal<String>", "激活标签外置信号"),
        propRow("Tabs.onChange", "ActionHandler", "切换事件"),
    ])
}

public func propsBreadcrumb(): IComponent {
    div([
        propRow("BreadcrumbItem.content", "String", "面包屑文本"),
        propRow("BreadcrumbItem.to / onClick", "String·ActionHandler", "跳转路径 / 点击事件"),
        propRow("Breadcrumb.separator", "String", "分隔符（默认 /）"),
    ])
}

public func propsSteps(): IComponent {
    div([
        propRow("StepItem.title / description", "String", "步骤标题 / 描述"),
        propRow("StepItem.status", "finish|process|wait|error", "强制状态"),
        propRow("Steps(children, active)", "Signal<Int64>", "激活步骤（1 起）外置"),
        propRow("direction", "horizontal | vertical", "方向"),
        propRow("processStatus / finishStatus", "String", "进行/完成状态映射"),
    ])
}

public func propsDropdown(): IComponent {
    div([
        propRow("DropdownItem.content / command", "String", "菜单文本 / 回传命令"),
        propRow("DropdownItem.disabled / divided", "Bool", "禁用 / 分隔线"),
        propRow("Dropdown(trigger).menu / onCommand", "Array<IComponent>", "菜单项 + 命令回调"),
    ])
}
