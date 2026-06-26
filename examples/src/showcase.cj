package examples

import cjxt.*
import cjxt.macros.*
import cjxt.components.*
import std.collection.{HashMap, ArrayList}

let componentNames: Array<String> = [
    "Button", "ButtonGroup", "Card", "RowCol", "Divider",
    "Text", "Link", "Tag", "Badge", "Space", "Icon",
    "Input", "InputNumber", "Switch", "Radio", "Checkbox",
    "Rate", "Select", "Slider", "Form", "Table", "Dialog"
]

class ShowcaseState <: AppState {
    var selected = Signal<String>("Button")
    var radioValue = Signal<String>("a")
    var checkboxValue = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
    var rateValue = Signal<Int64>(3)
    var switchValue = Signal<Bool>(true)
    var inputNumberValue = Signal<Int64>(3)
    var selectValue = Signal<String>("")
    var clearableValue = Signal<String>("")
    var filterableValue = Signal<String>("")
    var groupValue = Signal<String>("")
    var multiSelectValue = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
    var sliderValue = Signal<Int64>(30)
    var formUsername = Signal<String>("")
    var formPassword = Signal<String>("")
    var formUserError = Signal<String>("")
    var formPwdError = Signal<String>("")
    var formEmailError = Signal<String>("")
    var formEmail = Signal<String>("")
    var formError = Signal<String>("")
    var formSwitch = Signal<Bool>(true)
    var dialogVisible = Signal<Bool>(false)
    var dialogNestedVisible = Signal<Bool>(false)
    var formLayout = Signal<String>("")
    var tableData = Signal<ArrayList<HashMap<String, String>>>(ArrayList<HashMap<String, String>>())
    var tableSortColumn = Signal<String>("")
    var tableSortOrder = Signal<SortOrder>(SortOrder.None)
    var tableSelectedRows = Signal<ArrayList<HashMap<String, String>>>(ArrayList<HashMap<String, String>>())
    var tableCurrentRow: Signal<Option<HashMap<String, String>>>

    public init() {
        let noneRow: Option<HashMap<String, String>> = None
        this.tableCurrentRow = Signal<Option<HashMap<String, String>>>(noneRow)
    }
}

@Page["/showcase"]
class ShowcasePage <: Component {
    var state: ShowcaseState

    public init() { this.state = ShowcaseState() }
    public func onMount(ctx: LifecycleContext): Unit {
        this.state = ctx.getState<ShowcaseState>()
    }

    public func render(): IComponent {
        let sel = this.state.selected.get()
        let wrapCls = HashMap<String, String>([("class", cls("showcase-wrap"))])
        div([
            renderTabs("/showcase"),
            div([
                this.sidebar(sel),
                div([
                    this.demoArea(sel),
                    this.propsPanel(sel),
                ], attrs: Some(HashMap<String, String>([("class", cls("showcase-content"))]))),
            ], attrs: Some(HashMap<String, String>([("class", cls("showcase-body"))]))),
        ], attrs: Some(wrapCls))
    }

    func sidebar(sel: String): IComponent {
        let menu = Menu().mode(MenuMode.Vertical)
        for (name in componentNames) {
            let active = name == sel
            menu.add(
                MenuItem(name, [text(name)]).active(active).onClick({ ctx =>
                    this.state.selected.set(name)
                })
            )
        }
        let attrs = HashMap<String, String>([("class", "${cls("showcase-sidebar")} showcase-menu-wrap")])
        div([menu.render()], attrs: Some(attrs))
    }

    func demoArea(sel: String): IComponent {
        div([this.renderDemo(sel)], attrs: Some(HashMap<String, String>([("class", cls("showcase-demo"))])))
    }

    func propsPanel(sel: String): IComponent {
        let titleCls = HashMap<String, String>([("class", cls("showcase-props-title"))])
        div([
            div([text("属性")], attrs: Some(titleCls)),
            this.renderProps(sel),
        ], attrs: Some(HashMap<String, String>([("class", cls("showcase-props"))])))
    }

    // ============ Demos ============

    func renderDemo(sel: String): IComponent {
        match (sel) {
            case "Button" => this.demoButton()
            case "ButtonGroup" => this.demoButtonGroup()
            case "Card" => this.demoCard()
            case "RowCol" => this.demoRowCol()
            case "Divider" => this.demoDivider()
            case "Text" => this.demoText()
            case "Link" => this.demoLink()
            case "Tag" => this.demoTag()
            case "Badge" => this.demoBadge()
            case "Space" => this.demoSpace()
            case "Icon" => this.demoIcon()
            case "Input" => this.demoInput()
            case "InputNumber" => this.demoInputNumber()
            case "Switch" => this.demoSwitch()
            case "Radio" => this.demoRadio()
            case "Checkbox" => this.demoCheckbox()
            case "Rate" => this.demoRate()
            case "Select" => this.demoSelect()
            case "Slider" => this.demoSlider()
            case "Form" => this.demoForm()
            case "Table" => this.demoTable()
            case "Dialog" => this.demoDialog()
            case _ => text("选择左侧组件查看示例")
        }
    }

    func demoButton(): IComponent {
        div([
            div([
                Button("Default"),
                PrimaryButton("Primary"),
                SuccessButton("Success"),
                WarningButton("Warning"),
                DangerButton("Danger"),
                InfoButton("Info"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Button("Plain").plain(),
                PrimaryButton("Plain").plain(),
                DangerButton("Plain").plain(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Button([Icon("search"), text("Icon")]).round(),
                PrimaryButton("Round").round(),
                DangerButton("Circle").circle().icon("delete"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Button("Loading").loading(),
                PrimaryButton("Disabled").disabled(),
                Button("Text").text(),
                Button("Link").link(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:16px")])))
    }

    func demoButtonGroup(): IComponent {
        div([
            ButtonGroup([PrimaryButton("上一页"), PrimaryButton("下一页")]),
            ButtonGroup([Button("左"), Button("中"), Button("右")]).kind(ButtonKind.Primary),
            ButtonGroup([Button("Top"), Button("Center"), Button("Bottom")]).direction(SpaceDirection.Vertical),
        ], attrs: Some(HashMap<String, String>([("class", cls("row"))])))
    }

    func demoCard(): IComponent {
        div([
            Card([text("卡片内容")]).header("卡片标题"),
            Card([text("无标题卡片内容")]).shadow(CardShadow.Hover),
            Card([text("带底部")]).header("Header").footer("Footer"),
        ], attrs: Some(HashMap<String, String>([("class", cls("row"))])))
    }

    func demoRowCol(): IComponent {
        let gutter: Int64 = 16
        let cell = { label: String =>
            div([text(label)]).style("background:#f0f9ff;border:1px solid #0ea5e9;border-radius:6px;padding:12px 0;text-align:center;color:#0369a1;font-weight:600;font-size:13px")
        }
        let section = { title: String =>
            div([text(title)]).style("font-size:12px;color:#606266;margin:8px 0 4px")
        }
        div([
            section("基础栅格"),
            Row([Col([cell("span: 24")], span: 24, gutter: gutter)], gutter: gutter),
            Row([
                Col([cell("span: 12")], span: 12, gutter: gutter),
                Col([cell("span: 12")], span: 12, gutter: gutter),
            ], gutter: gutter),
            Row([
                Col([cell("span: 8")], span: 8, gutter: gutter),
                Col([cell("span: 8")], span: 8, gutter: gutter),
                Col([cell("span: 8")], span: 8, gutter: gutter),
            ], gutter: gutter),
            section("Offset"),
            Row([
                Col([cell("offset: 0")], span: 6, gutter: gutter),
                Col([cell("offset: 6")], span: 6, offset: 6, gutter: gutter),
                Col([cell("offset: 4")], span: 4, offset: 4, gutter: gutter),
            ], gutter: gutter),
            section("Justify / Align"),
            Row([
                Col([cell("start")], span: 4, gutter: gutter),
                Col([cell("center")], span: 4, gutter: gutter),
            ], gutter: gutter, justify: RowJustify.Center),
            Row([
                Col([cell("end-1")], span: 4, gutter: gutter),
                Col([cell("end-2")], span: 4, gutter: gutter),
            ], gutter: gutter, justify: RowJustify.End),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:8px;padding:16px;align-self:stretch")])))
    }

    func demoDivider(): IComponent {
        div([
            div([text("默认分割线")], attrs: Some(HashMap<String, String>([("class", cls("divider-section-title"))]))),
            Divider(),
            div([text("带文字的分割线")], attrs: Some(HashMap<String, String>([("class", cls("divider-section-title"))]))),
            div([
                text("左侧"),
                Divider([text("Left")]).contentPosition(ContentPosition.Left),
                text("居中"),
                Divider([text("Center")]).contentPosition(ContentPosition.Center),
                text("右侧"),
                Divider([text("Right")]).contentPosition(ContentPosition.Right),
            ], attrs: Some(HashMap<String, String>([("class", cls("divider-group"))]))),
            div([text("垂直分割线")], attrs: Some(HashMap<String, String>([("class", cls("divider-section-title"))]))),
            div([
                text("Item 1"),
                Divider().direction(DividerDirection.Vertical),
                text("Item 2"),
                Divider().direction(DividerDirection.Vertical),
                text("Item 3"),
            ], attrs: Some(HashMap<String, String>([("class", cls("divider-group"))]))),
        ], attrs: Some(HashMap<String, String>([("class", cls("divider-demo"))])))
    }

    func demoCheckbox(): IComponent {
        div([
            CheckboxGroup([
                Checkbox([text("A")], "a"),
                Checkbox([text("B")], "b"),
                Checkbox([text("C")], "c").disabled(),
            ]).bind(this.state.checkboxValue),
            div([
                Checkbox([text("单独复选")], "single"),
                Checkbox([text("选中并禁用")], "x").disabled(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:16px")])))
    }

    func demoText(): IComponent {
        div([
            div([
                Text([text("默认文本")]),
                Text([text("主色文本")]).kind(ComponentKind.Primary),
                Text([text("成功文本")]).kind(ComponentKind.Success),
                Text([text("危险文本")]).kind(ComponentKind.Danger),
                Text([text("大尺寸")]).size(TextSize.Large),
                Text([text("小尺寸")]).size(TextSize.Small),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                div([Text([text("这是一段会被截断的很长很长的文本内容")]).truncated()], attrs: Some(HashMap<String, String>([("class", cls("row")), ("style", "max-width:200px")]))),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ])
    }

    func demoLink(): IComponent {
        div([
            Link([text("默认链接")]),
            Link([text("主色链接")]).kind(ComponentKind.Primary),
            Link([text("下划线始终")]).underline(LinkUnderline.Always),
            Link([text("无下划线")]).noUnderline(),
            Link([text("禁用链接")]).disabled(),
            Link([Icon("edit"), text("带图标")]).kind(ComponentKind.Success),
        ], attrs: Some(HashMap<String, String>([("class", cls("row"))])))
    }

    func demoTag(): IComponent {
        div([
            div([
                Tag([text("标签")]),
                Tag([text("成功")]).kind(ComponentKind.Success),
                Tag([text("警告")]).kind(ComponentKind.Warning),
                Tag([text("危险")]).kind(ComponentKind.Danger),
                Tag([text("信息")]).kind(ComponentKind.Info),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Tag([text("Plain")]).effect(TagEffect.Plain),
                Tag([text("Dark")]).effect(TagEffect.Dark),
                Tag([text("Round")]).round().kind(ComponentKind.Primary),
                Tag([text("Hit")]).hit().kind(ComponentKind.Success),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Tag([text("Small")]).size(TagSize.Small).kind(ComponentKind.Primary),
                Tag([text("Large")]).size(TagSize.Large).kind(ComponentKind.Danger),
                Tag([text("可移除")]).kind(ComponentKind.Info).closable(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:16px")])))
    }

    func demoBadge(): IComponent {
        div([
            Badge([Button("消息")]).value(5),
            Badge([Button("热门")]).value(120).max(99),
            Badge([Button("动态")]).dot(),
            Badge([Button("Zero")]).value(0).showZero(false),
        ], attrs: Some(HashMap<String, String>([("class", cls("row"))])))
    }

    func demoSpace(): IComponent {
        Space([Button("按钮1"), Button("按钮2"), Button("按钮3")]).size(16)
    }

    func demoIcon(): IComponent {
        div([
            div([
                Icon("edit"),
                Icon("delete"),
                Icon("search"),
                Icon("close"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                Icon("star-filled").size("24px"),
                Icon("star").size("24px").color("#e6a23c"),
                Icon("check").size("24px").color("#67c23a"),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:16px")])))
    }

    func demoInput(): IComponent {
        div([
            Input().placeholder("请输入内容").prefixIcon("search"),
            Input().placeholder("禁用").disabled(),
            Input().placeholder("密码").password().suffixIcon("view"),
            Input().placeholder("大号").size(ComponentSize.Large).clearable(),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:16px;width:100%")])))
    }

    func demoInputNumber(): IComponent {
        div([
            InputNumber().min(0).max(10).bind(this.state.inputNumberValue),
            InputNumber().min(0).max(100).step(5).noControls().bind(this.state.inputNumberValue),
            InputNumber().min(0).max(100).size(ComponentSize.Small).bind(this.state.inputNumberValue),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:16px")])))
    }

    func demoSwitch(): IComponent {
        div([
            Switch().bind(this.state.switchValue),
            Switch().activeText("开").inactiveText("关").bind(this.state.switchValue),
            Switch().size(ComponentSize.Small).disabled().bind(this.state.switchValue),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:16px")])))
    }

    func demoRadio(): IComponent {
        div([
            RadioGroup([
                Radio([text("选项A")], "a"),
                Radio([text("选项B")], "b"),
                Radio([text("选项C")], "c").disabled(),
            ]).bind(this.state.radioValue),
            RadioGroup([
                Radio([Button("A")], "a"),
                Radio([Button("B")], "b"),
            ]).bind(this.state.radioValue),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:16px")])))
    }

    func demoRate(): IComponent {
        div([
            Rate().bind(this.state.rateValue),
            Rate().max(3).showText().texts(["差", "一般", "好"]).bind(this.state.rateValue),
            Rate().disabled().bind(this.state.rateValue),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:16px")])))
    }

    func demoSelect(): IComponent {
        let section = { title: String =>
            span([text(title)], attrs: Some(HashMap<String, String>([("class", "el-text el-text--small"), ("style", "margin-top:8px;color:#909399")])))
        }
        div([
            section("基础单选"),
            Select([
                SelectOption([text("选项A")], "a"),
                SelectOption([text("选项B")], "b"),
                SelectOption([text("选项C")], "c").disabled(),
            ]).placeholder("请选择").bind(this.state.selectValue),
            section("多选"),
            Select([
                SelectOption([text("选项A")], "a"),
                SelectOption([text("选项B")], "b"),
                SelectOption([text("选项C")], "c"),
            ]).multiple().placeholder("请选择多个").bindMulti(this.state.multiSelectValue),
            section("可清除"),
            Select([
                SelectOption([text("选项A")], "a"),
                SelectOption([text("选项B")], "b"),
            ]).clearable().placeholder("可清除").bind(this.state.clearableValue),
            section("可搜索"),
            Select([
                SelectOption([text("选项A")], "a"),
                SelectOption([text("选项B")], "b"),
                SelectOption([text("选项C")], "c"),
            ]).filterable().placeholder("输入搜索").bind(this.state.filterableValue),
            section("选项分组"),
            Select([
                SelectOptionGroup([SelectOption([text("选项A")], "a"), SelectOption([text("选项B")], "b")], "水果"),
                SelectOptionGroup([SelectOption([text("选项C")], "c"), SelectOption([text("选项D")], "d")], "蔬菜"),
            ]).placeholder("请选择分组").bind(this.state.groupValue),
            section("禁用"),
            Select([
                SelectOption([text("苹果")], "apple"),
                SelectOption([text("香蕉")], "banana"),
                SelectOption([text("橙子")], "orange"),
            ]).placeholder("禁用").disabled(),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:16px;width:100%")])))
    }

    func demoSlider(): IComponent {
        div([
            Slider().min(0).max(100).bind(this.state.sliderValue),
            Slider().min(0).max(100).step(10).showStops().bind(this.state.sliderValue),
            Slider().min(0).max(100).disabled().bind(this.state.sliderValue),
        ], attrs: Some(HashMap<String, String>([("style", "display:flex;flex-direction:column;gap:16px;width:100%")])))
    }

    func demoForm(): IComponent {
        let itemUser = FormItem([Input().placeholder("请输入用户名").prefixIcon("user").bind(this.state.formUsername)])
            .label("用户名")
            .bind(this.state.formUsername)
            .rule(FormRule(required: true, message: "用户名不能为空"))
            .rule(FormRule(min: 3, message: "用户名至少3个字符"))
            .errorSignal(this.state.formUserError)
        let itemPwd = FormItem([Input().placeholder("请输入密码").password().prefixIcon("lock").bind(this.state.formPassword)])
            .label("密码")
            .bind(this.state.formPassword)
            .rule(FormRule(required: true, message: "密码不能为空"))
            .rule(FormRule(min: 6, message: "密码至少6个字符"))
            .errorSignal(this.state.formPwdError)

        let itemEmail = FormItem([Input().placeholder("请输入邮箱").prefixIcon("info-filled").bind(this.state.formEmail)])
            .label("邮箱")
            .bind(this.state.formEmail)
            .rule(FormRule(pattern: "^\\w+@\\w+\\.\\w+$", message: "邮箱格式不正确"))
            .errorSignal(this.state.formEmailError)

        let layout = this.state.formLayout.get()
        let baseForm = Form([
            itemUser, itemPwd, itemEmail,
            FormItem([Switch().activeText("启用").inactiveText("禁用").bind(this.state.formSwitch)]).label("状态"),
        ])
        let form = if (layout == "top") { baseForm.labelTop() } else if (layout == "inline") { baseForm.inline() } else { baseForm }

        let submitHandler: ActionHandler = { ctx: ActionContext =>
            if (form.validate()) {
                this.state.formError.set("")
            } else {
                this.state.formError.set("请填写必填字段")
            }
            PatchResult.ReRender
        }
        let defaultHandler: ActionHandler = { ctx: ActionContext => this.state.formLayout.set(""); PatchResult.ReRender }
        let topHandler: ActionHandler = { ctx: ActionContext => this.state.formLayout.set("top"); PatchResult.ReRender }
        let inlineHandler: ActionHandler = { ctx: ActionContext => this.state.formLayout.set("inline"); PatchResult.ReRender }

        div([
            div([
                text("布局："),
                if (layout == "") { PrimaryButton("横").size(ButtonSize.Small).onClick(defaultHandler) } else { Button("横").size(ButtonSize.Small).onClick(defaultHandler) },
                if (layout == "top") { PrimaryButton("竖").size(ButtonSize.Small).onClick(topHandler) } else { Button("竖").size(ButtonSize.Small).onClick(topHandler) },
                if (layout == "inline") { PrimaryButton("行内").size(ButtonSize.Small).onClick(inlineHandler) } else { Button("行内").size(ButtonSize.Small).onClick(inlineHandler) },
            ], attrs: Some(HashMap<String, String>([("style", "display:flex;gap:8px;align-items:center;margin-bottom:12px")]))),
            form,
            PrimaryButton("提交").onClick(submitHandler),
        ])
    }

    // ============ Table ============

    func demoTable(): IComponent {
        let d = this.state.tableData
        if (d.get().size == 0) {
            d.set(initTableData())
        }
        let columns = ArrayList<TableColumn>()
        columns.add(TableColumn().colType(TableColumnType.Selection).width(50))
        columns.add(TableColumn().colType(TableColumnType.Index).label("#").width(60))
        columns.add(TableColumn().colProp("date").label("Date").width(120).sortable())
        columns.add(TableColumn().colProp("name").label("Name").width(120).sortable())
        columns.add(TableColumn().colProp("state").label("State").width(120))
        columns.add(TableColumn().colProp("city").label("City").width(120))
        columns.add(TableColumn().colProp("address").label("Address").width(200).showOverflowTooltip())
        let tbl = Table()
            .data(d)
            .border()
            .stripe()
            .highlight()
            .height("300px")
            .sortColumn(this.state.tableSortColumn)
            .sortOrder(this.state.tableSortOrder)
            .selectedRows(this.state.tableSelectedRows)
            .currentRow(this.state.tableCurrentRow)
        for (c in columns) { tbl.add(c) }
        div([
            div([
                text("带边框/斑马纹/高亮当前行/排序/多选"),
            ], attrs: Some(HashMap<String, String>([("class", cls("showcase-section-title"))]))),
            tbl.render(),
            div([
                text("空数据表格："),
            ], attrs: Some(HashMap<String, String>([("style", "margin-top:24px;margin-bottom:8px")]))),
            Table()
                .data(Signal<ArrayList<HashMap<String, String>>>(ArrayList<HashMap<String, String>>()))
                .add(TableColumn().colProp("name").label("Name").width(120))
                .add(TableColumn().colProp("email").label("Email").width(200))
                .render(),
        ])
    }

    // ============ Dialog ============

    func demoDialog(): IComponent {
        let openHandler: ActionHandler = { ctx =>
            this.state.dialogVisible.set(true)
            PatchResult.ReRender
        }
        let btn = Button("打开对话框")
            .kind(ButtonKind.Primary)
            .onClick(openHandler)
        let closeHandler: ActionHandler = { ctx =>
            this.state.dialogVisible.set(false)
            PatchResult.ReRender
        }
        let dlg = Dialog([text("这是一个对话框内容。")])
            .visible(this.state.dialogVisible)
            .title("提示")
            .width("420px")
            .closeOnClickModal(false)
            .footer([
                Button("取消").onClick(closeHandler),
                Button("确认").kind(ButtonKind.Primary).onClick(closeHandler),
            ])
        div([
            div([
                text("基础对话框"),
            ], attrs: Some(HashMap<String, String>([("class", cls("showcase-section-title"))]))),
            btn.render(),
            dlg.render(),
        ])
    }

    // ============ Props ============

    func renderProps(sel: String): IComponent {
        match (sel) {
            case "Button" => div([
                this.propRow("kind", "Default | Primary | Success | Warning | Danger | Info", "按钮类型/主题色"),
                this.propRow("size", "Large | Default | Small", "按钮尺寸"),
                this.propRow("plain / round / circle", "false", "朴素样式 / 圆角 / 圆形"),
                this.propRow("loading / disabled", "false", "加载中 / 禁用状态"),
                this.propRow("text / link / bg", "false", "文字按钮 / 链接按钮 / 背景色模式"),
                this.propRow("icon(name)", "String", "图标名称"),
                this.propRow("onClick", "(ActionContext) -> PatchResult", "点击事件"),
            ])
            case "ButtonGroup" => div([
                this.propRow("children", "Array<IComponent>", "子按钮集合"),
                this.propRow("direction", "Horizontal | Vertical", "排列方向"),
                this.propRow("size / kind", "apply to children", "统一应用到子按钮的尺寸和类型"),
            ])
            case "Card" => div([
                this.propRow("header", "String | Array<IComponent>", "卡片顶部内容"),
                this.propRow("footer", "String | Array<IComponent>", "卡片底部内容"),
                this.propRow("shadow", "Always | Hover | Never", "阴影显示时机"),
                this.propRow("bodyStyle / bodyClass", "String", "内容区自定义样式/类名"),
            ])
            case "RowCol" => div([
                this.propRow("Row.gutter", "Int64", "栅格间隔"),
                this.propRow("Row.justify", "Start | End | Center | SpaceAround | SpaceBetween | SpaceEvenly", "水平对齐方式"),
                this.propRow("Row.align", "Top | Middle | Bottom", "垂直对齐方式"),
                this.propRow("Col.span", "Int64 (默认 24)", "占据的栅格数，总栅格数为 24"),
                this.propRow("Col.offset / push / pull", "Int64", "偏移 / 右推 / 左拉"),
            ])
            case "Divider" => div([
                this.propRow("direction", "Horizontal | Vertical", "分割线方向"),
                this.propRow("contentPosition", "Left | Center | Right", "内容文本位置"),
            ])
            case "Text" => div([
                this.propRow("kind", "Default | Primary | Success | Warning | Danger | Info | Plain", "文本颜色类型"),
                this.propRow("size", "Default | Large | Small", "文本尺寸"),
                this.propRow("truncated", "false", "是否省略溢出文本"),
                this.propRow("lineClamp", "Int64", "最大显示行数"),
                this.propRow("tag", "String (默认 span)", "渲染的标签名"),
            ])
            case "Link" => div([
                this.propRow("kind", "Default | Primary | Success | Warning | Danger | Info", "链接颜色类型"),
                this.propRow("underline", "Always | Hover | Never", "下划线显示时机"),
                this.propRow("href / target", "String", "跳转链接 / 打开方式"),
                this.propRow("disabled", "false", "禁用状态"),
                this.propRow("icon(name)", "String", "图标名称"),
                this.propRow("onClick", "(ActionContext) -> PatchResult", "点击事件"),
            ])
            case "Tag" => div([
                this.propRow("kind", "Default | Primary | Success | Warning | Danger | Info", "标签颜色类型"),
                this.propRow("size", "Default | Large | Medium | Small | Mini", "标签尺寸"),
                this.propRow("effect", "Dark | Light | Plain", "标签效果"),
                this.propRow("closable / hit / round", "false", "可关闭 / 边框高亮 / 圆角"),
                this.propRow("color", "String", "自定义颜色"),
            ])
            case "Badge" => div([
                this.propRow("value", "Int64 | String", "徽标数值或内容"),
                this.propRow("max", "Int64 (默认 99)", "数值最大值，超出显示 99+"),
                this.propRow("dot / hidden", "false", "小圆点模式 / 隐藏"),
                this.propRow("showZero", "true", "数值为 0 时是否显示"),
                this.propRow("kind", "Default | Primary | Success | Warning | Danger | Info", "徽标颜色类型"),
            ])
            case "Space" => div([
                this.propRow("size", "Int64 (默认 8)", "间距大小"),
                this.propRow("direction", "Horizontal | Vertical", "排列方向"),
                this.propRow("wrap", "false", "是否自动换行"),
            ])
            case "Icon" => div([
                this.propRow("name", "String", "Element Plus 图标名称"),
            ])
            case "Input" => div([
                this.propRow("placeholder", "String", "占位提示文本"),
                this.propRow("size", "Large | Default | Small", "输入框尺寸"),
                this.propRow("clearable / disabled / password", "false", "可清空 / 禁用 / 密码类型"),
                this.propRow("prefixIcon / suffixIcon", "String", "前缀 / 后缀图标"),
                this.propRow("bind(signal)", "Signal<String>", "双向绑定的信号"),
            ])
            case "InputNumber" => div([
                this.propRow("min / max / step", "Int64", "最小值 / 最大值 / 步长"),
                this.propRow("size", "Large | Default | Small", "计数器尺寸"),
                this.propRow("noControls", "false", "隐藏 +/- 按钮"),
                this.propRow("bind(signal)", "Signal<Int64>", "双向绑定的信号"),
            ])
            case "Switch" => div([
                this.propRow("activeText / inactiveText", "String", "开启 / 关闭时的文本"),
                this.propRow("activeValue / inactiveValue", "Bool", "开启 / 关闭时的值"),
                this.propRow("size", "Large | Default | Small", "开关尺寸"),
                this.propRow("disabled", "false", "禁用状态"),
                this.propRow("bind(signal)", "Signal<Bool>", "双向绑定的信号"),
            ])
            case "Radio" => div([
                this.propRow("Radio(value)", "String", "单选框的值"),
                this.propRow("Radio.disabled", "false", "单选框禁用状态"),
                this.propRow("RadioGroup.bind(signal)", "Signal<String>", "单选组绑定的信号"),
            ])
            case "Checkbox" => div([
                this.propRow("Checkbox(value)", "String", "复选框的值"),
                this.propRow("Checkbox.disabled", "false", "复选框禁用状态"),
                this.propRow("CheckboxGroup.bind(signal)", "Signal<ArrayList<String>>", "复选框组绑定的信号"),
            ])
            case "Rate" => div([
                this.propRow("max", "Int64 (默认 5)", "最大评分值"),
                this.propRow("allowHalf", "false", "是否允许半选"),
                this.propRow("showText", "false", "是否显示辅助文字"),
                this.propRow("texts", "Array<String>", "自定义辅助文字数组"),
                this.propRow("disabled", "false", "禁用状态"),
                this.propRow("bind(signal)", "Signal<Int64>", "双向绑定的信号"),
            ])
            case "Select" => div([
                this.propRow("SelectOption(value)", "String", "选项的值"),
                this.propRow("SelectOption.disabled", "false", "选项禁用状态"),
                this.propRow("Select.placeholder", "String", "占位提示文本"),
                this.propRow("Select.disabled", "false", "选择器禁用状态"),
                this.propRow("Select.bind(signal)", "Signal<String>", "双向绑定的信号"),
            ])
            case "Slider" => div([
                this.propRow("min / max / step", "Int64", "最小值 / 最大值 / 步长"),
                this.propRow("showStops", "false", "是否显示间断点"),
                this.propRow("disabled", "false", "禁用状态"),
                this.propRow("bind(signal)", "Signal<Int64>", "双向绑定的信号"),
            ])
            case "Form" => div([
                this.propRow("FormItem.label", "String", "表单项标签文本"),
                this.propRow("FormItem.required", "false", "是否必填"),
                this.propRow("FormItem.error", "String", "错误提示文本"),
            ])
            case "Table" => div([
                this.propRow("Table.data(signal)", "Signal<ArrayList<HashMap<String, String>>>", "表格数据源"),
                this.propRow("Table.add(TableColumn)", "Chain", "添加列配置"),
                this.propRow("stripe / border / highlight", "false", "斑马纹 / 边框 / 高亮当前行"),
                this.propRow("height / maxHeight", "String", "表格高度 / 最大高度"),
                this.propRow("size", "Large | Default | Small", "表格尺寸"),
                this.propRow("showSummary", "false", "是否在表尾显示汇总行"),
                this.propRow("Table.sortColumn(signal)", "Signal<String>", "当前排序列，外置信号可持久化"),
                this.propRow("Table.sortOrder(signal)", "Signal<SortOrder>", "当前排序方向，外置信号可持久化"),
                this.propRow("Table.selectedRows(signal)", "Signal<ArrayList<HashMap<String, String>>>", "选中的行集合，外置信号可持久化"),
                this.propRow("Table.currentRow(signal)", "Signal<Option<HashMap<String, String>>>", "当前高亮行，外置信号可持久化"),
                this.propRow("Table.rowClassName(fn)", "(HashMap<String,String>, Int64) -> String", "自定义行 class 回调"),
                this.propRow("Table.rowStyle(fn)", "(HashMap<String,String>, Int64) -> String", "自定义行 style 回调"),
                this.propRow("Table.cellClassName(fn)", "(HashMap<String,String>, TableColumn, Int64, Int64) -> String", "自定义单元格 class 回调"),
                this.propRow("Table.cellStyle(fn)", "(HashMap<String,String>, TableColumn, Int64, Int64) -> String", "自定义单元格 style 回调"),
                this.propRow("Table.headerCellClassName(fn)", "(TableColumn, Int64) -> String", "自定义表头 cell class 回调"),
                this.propRow("Table.headerRowStyle(fn)", "(Int64) -> String", "自定义表头行 style 回调"),
                this.propRow("Table.headerCellStyle(fn)", "(TableColumn, Int64) -> String", "自定义表头 cell style 回调"),
                this.propRow("Table.headerRowClassName(fn)", "(Int64) -> String", "自定义表头行 class 回调"),
                this.propRow("TableColumn.colProp", "String", "列对应数据字段名"),
                this.propRow("TableColumn.label", "String", "列标题"),
                this.propRow("TableColumn.width / minWidth", "Int64", "列宽 / 最小列宽"),
                this.propRow("TableColumn.fixed", "Left | Right", "固定列位置"),
                this.propRow("TableColumn.sortable", "false", "该列是否可排序"),
                this.propRow("TableColumn.align", "Left | Center | Right", "单元格对齐方式"),
                this.propRow("TableColumn.colType", "Default | Selection | Index", "列类型：默认 / 多选 / 序号"),
                this.propRow("TableColumn.showOverflowTooltip", "false", "内容溢出时显示 tooltip"),
                this.propRow("TableColumn.formatter", "(String) -> String", "单元格内容格式化函数"),
            ])
            case "Dialog" => div([
                this.propRow("Dialog(children)", "Array<IComponent>", "对话框主体内容"),
                this.propRow("Dialog.visible(signal)", "Signal<Bool>", "控制对话框显示/隐藏"),
                this.propRow("Dialog.title", "String", "对话框标题"),
                this.propRow("Dialog.width", "String (默认 50%)", "对话框宽度"),
                this.propRow("Dialog.top", "String (默认 15vh)", "对话框距顶部距离"),
                this.propRow("Dialog.showClose", "Bool (默认 true)", "是否显示关闭按钮"),
                this.propRow("Dialog.closeOnClickModal", "Bool (默认 true)", "点击遮罩层是否关闭"),
                this.propRow("Dialog.modal", "Bool (默认 true)", "是否显示遮罩层"),
                this.propRow("Dialog.center / alignCenter", "Bool", "居中标题/垂直居中"),
                this.propRow("Dialog.fullscreen", "Bool", "全屏模式"),
                this.propRow("Dialog.destroyOnClose", "Bool", "关闭时销毁内容"),
                this.propRow("Dialog.beforeClose(fn)", "ActionHandler", "关闭前回调"),
                this.propRow("Dialog.header / footer", "Array<IComponent>", "自定义头部/底部内容"),
            ])
            case _ => text("选择左侧组件查看属性")
        }
    }

// --- 辅助数据 ---

func initTableData(): ArrayList<HashMap<String, String>> {
    let data = ArrayList<HashMap<String, String>>()
    data.add(HashMap<String, String>([("date", "2016-05-03"), ("name", "Tom"), ("state", "California"), ("city", "Los Angeles"), ("address", "No. 189, Grove St, Los Angeles")]))
    data.add(HashMap<String, String>([("date", "2016-05-02"), ("name", "Jerry"), ("state", "California"), ("city", "San Francisco"), ("address", "742 Evergreen Terrace, San Francisco")]))
    data.add(HashMap<String, String>([("date", "2016-05-04"), ("name", "Alice"), ("state", "New York"), ("city", "New York City"), ("address", "350 Fifth Avenue, New York City, NY 10118")]))
    data.add(HashMap<String, String>([("date", "2016-05-01"), ("name", "Bob"), ("state", "Texas"), ("city", "Austin"), ("address", "1100 Congress Ave, Austin, TX 78701")]))
    data
}

func propRow(name: String, typ: String, desc: String): IComponent {
        div([
            div([text(name)], attrs: Some(HashMap<String, String>([("class", cls("showcase-prop-name"))]))),
            div([text(typ)], attrs: Some(HashMap<String, String>([("class", cls("showcase-prop-type"))]))),
            div([text(desc)], attrs: Some(HashMap<String, String>([("class", cls("showcase-prop-desc"))]))),
        ], attrs: Some(HashMap<String, String>([("class", cls("showcase-prop-row"))])))
    }
}
