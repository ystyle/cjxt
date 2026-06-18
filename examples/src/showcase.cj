package examples

import cjxt.*
import cjxt.macros.*
import cjxt.components.*
import std.collection.{HashMap, ArrayList}

let componentNames: Array<String> = [
    "Button", "ButtonGroup", "Card", "RowCol", "Divider",
    "Text", "Link", "Tag", "Badge", "Space", "Icon",
    "Input", "InputNumber", "Switch", "Radio", "Checkbox",
    "Rate", "Select", "Slider", "Form"
]

class ShowcaseState <: AppState {
    var selected = Signal<String>("Button")
    var radioValue = Signal<String>("a")
    var checkboxValue = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
    var rateValue = Signal<Int64>(3)
    var switchValue = Signal<Bool>(true)
    var inputNumberValue = Signal<Int64>(3)
    var selectValue = Signal<String>("")
    var sliderValue = Signal<Int64>(30)
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
                    PatchResult.ReRender
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
            case _ => text("选择左侧组件查看示例")
        }
    }

    func demoButton(): IComponent {
        div([
            Button("Default"),
            PrimaryButton("Primary"),
            DangerButton("Danger"),
            InfoButton("Info"),
            SmallButton("Small"),
        ], attrs: Some(HashMap<String, String>([("class", cls("row"))])))
    }

    func demoButtonGroup(): IComponent {
        ButtonGroup([Button("上一页"), Button("下一页")])
    }

    func demoCard(): IComponent {
        Card([text("卡片内容")], header: "卡片标题")
    }

    func demoRowCol(): IComponent {
        let gutter: Int64 = 12
        let cell = { label: String =>
            div([text(label)]).style("background:#f5f3ff;border:1px solid #4f46e5;border-radius:8px;padding:16px 0;text-align:center;color:#4f46e5;font-weight:600")
        }
        Row([
            Col([cell("span: 24")], span: 24, gutter: gutter),
            Col([cell("span: 12")], span: 12, gutter: gutter),
            Col([cell("span: 12")], span: 12, gutter: gutter),
            Col([cell("span: 8")], span: 8, gutter: gutter),
            Col([cell("span: 8")], span: 8, gutter: gutter),
            Col([cell("span: 8")], span: 8, gutter: gutter),
        ], gutter: gutter)
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
        CheckboxGroup([
            Checkbox([text("A")], "a"),
            Checkbox([text("B")], "b"),
            Checkbox([text("C")], "c"),
        ]).bind(this.state.checkboxValue)
    }

    func demoText(): IComponent {
        div([
            Text([text("默认文本")]),
            Text([text("主色文本")]).kind(ComponentKind.Primary),
            Text([text("成功文本")]).kind(ComponentKind.Success),
            Text([text("警告文本")]).kind(ComponentKind.Warning),
            Text([text("危险文本")]).kind(ComponentKind.Danger),
            Text([text("信息文本")]).kind(ComponentKind.Info),
        ]).style("display:flex;flex-wrap:wrap;gap:12px;align-items:center")
    }

    func demoLink(): IComponent {
        div([
            Link([text("默认链接")]),
            Link([text("主色链接")]).kind(ComponentKind.Primary),
            Link([text("禁用链接")]).disabled(),
        ]).style("display:flex;flex-wrap:wrap;gap:16px;align-items:center")
    }

    func demoTag(): IComponent {
        div([
            Tag([text("标签")]),
            Tag([text("成功")]).kind(ComponentKind.Success),
            Tag([text("可移除")]).kind(ComponentKind.Info).closable(),
            Tag([text("深色")]).kind(ComponentKind.Danger).effect(TagEffect.Dark),
        ], attrs: Some(HashMap<String, String>([("class", cls("row"))])))
    }

    func demoBadge(): IComponent {
        div([
            Badge([Button("消息")]).value(5),
            Badge([Button("动态")]).dot(),
        ], attrs: Some(HashMap<String, String>([("class", cls("row"))])))
    }

    func demoSpace(): IComponent {
        Space([Button("按钮1"), Button("按钮2"), Button("按钮3")]).size(16)
    }

    func demoIcon(): IComponent {
        div([
            Icon("edit"),
            Icon("delete"),
            Icon("star-on"),
            Icon("search"),
        ], attrs: Some(HashMap<String, String>([("class", cls("row"))])))
    }

    func demoInput(): IComponent {
        Input().placeholder("请输入内容").prefixIcon("search")
    }

    func demoInputNumber(): IComponent {
        InputNumber().min(0).max(10).bind(this.state.inputNumberValue)
    }

    func demoSwitch(): IComponent {
        Switch().bind(this.state.switchValue)
    }

    func demoRadio(): IComponent {
        RadioGroup([
            Radio([text("选项A")], "a"),
            Radio([text("选项B")], "b"),
            Radio([text("选项C")], "c").disabled(),
        ]).bind(this.state.radioValue)
    }

    func demoRate(): IComponent {
        Rate().bind(this.state.rateValue)
    }

    func demoSelect(): IComponent {
        Select([
            SelectOption([text("选项A")], "a"),
            SelectOption([text("选项B")], "b"),
            SelectOption([text("选项C")], "c"),
        ]).placeholder("请选择").bind(this.state.selectValue)
    }

    func demoSlider(): IComponent {
        Slider().min(0).max(100).bind(this.state.sliderValue)
    }

    func demoForm(): IComponent {
        Form([
            FormItem([Input().placeholder("请输入用户名")]).label("用户名").required(),
            FormItem([Input().placeholder("请输入密码").password()]).label("密码").required(),
            FormItem([Input().placeholder("请输入邮箱")]).label("邮箱"),
        ])
    }

    // ============ Props ============

    func renderProps(sel: String): IComponent {
        match (sel) {
            case "Button" => div([
                this.propRow("kind", "Primary | Danger | Info | Default"),
                this.propRow("size", "Large | Default | Small"),
                this.propRow("plain", "false"),
                this.propRow("disabled", "false"),
                this.propRow("onClick", "(ActionContext) -> PatchResult"),
            ])
            case "ButtonGroup" => div([
                this.propRow("children", "Array<IComponent>"),
            ])
            case "Card" => div([
                this.propRow("header", "String"),
                this.propRow("shadow", "Always | Hover | Never"),
            ])
            case "RowCol" => div([
                this.propRow("Row.gutter", "Int64"),
                this.propRow("Col.span", "Int64 (默认 24)"),
            ])
            case "Divider" => div([
                this.propRow("direction", "Horizontal | Vertical"),
                this.propRow("contentPosition", "Left | Center | Right"),
            ])
            case "Text" => div([
                this.propRow("kind", "Default | Primary | ... | Plain"),
                this.propRow("size", "Default | Large | Small"),
                this.propRow("truncated", "false"),
            ])
            case "Link" => div([
                this.propRow("kind", "Default | Primary | ... | Info"),
                this.propRow("underline", "true"),
                this.propRow("disabled", "false"),
                this.propRow("onClick", "(ActionContext) -> PatchResult"),
            ])
            case "Tag" => div([
                this.propRow("kind", "Default | Primary | ... | Info"),
                this.propRow("size", "Default | Large | Small | Mini"),
                this.propRow("effect", "Dark | Light | Plain"),
                this.propRow("closable", "false"),
            ])
            case "Badge" => div([
                this.propRow("value", "Int64 | String"),
                this.propRow("dot", "false"),
            ])
            case "Space" => div([
                this.propRow("size", "Int64 (默认 8)"),
                this.propRow("direction", "Horizontal | Vertical"),
                this.propRow("wrap", "false"),
            ])
            case "Icon" => div([
                this.propRow("name", "String (EP 图标名)"),
            ])
            case "Input" => div([
                this.propRow("placeholder", "String"),
                this.propRow("size", "Large | Default | Small"),
                this.propRow("clearable", "false"),
                this.propRow("prefixIcon", "String"),
                this.propRow("bind(signal)", "Signal<String>"),
            ])
            case "InputNumber" => div([
                this.propRow("min / max / step", "Int64"),
                this.propRow("noControls", "隐藏 +/- 按钮"),
                this.propRow("bind(signal)", "Signal<Int64>"),
            ])
            case "Switch" => div([
                this.propRow("activeText / inactiveText", "String"),
                this.propRow("bind(signal)", "Signal<Bool>"),
            ])
            case "Radio" => div([
                this.propRow("Radio(value)", "String"),
                this.propRow("RadioGroup.bind(signal)", "Signal<String>"),
            ])
            case "Checkbox" => div([
                this.propRow("Checkbox(value)", "String"),
                this.propRow("Group.bind(signal)", "Signal<ArrayList<String>>"),
            ])
            case "Rate" => div([
                this.propRow("max", "Int64 (默认 5)"),
                this.propRow("showText", "false"),
                this.propRow("bind(signal)", "Signal<Int64>"),
            ])
            case "Select" => div([
                this.propRow("SelectOption(value)", "String"),
                this.propRow("Select.placeholder", "String"),
                this.propRow("Select.bind(signal)", "Signal<String>"),
            ])
            case "Slider" => div([
                this.propRow("min / max / step", "Int64"),
                this.propRow("showStops", "false"),
                this.propRow("bind(signal)", "Signal<Int64>"),
            ])
            case "Form" => div([
                this.propRow("FormItem.label", "String"),
                this.propRow("FormItem.required", "false"),
                this.propRow("FormItem.error", "String"),
            ])
            case _ => text("选择左侧组件查看属性")
        }
    }

    func propRow(name: String, value: String): IComponent {
        div([
            div([text(name)], attrs: Some(HashMap<String, String>([("class", cls("showcase-prop-name"))]))),
            div([text(value)], attrs: Some(HashMap<String, String>([("class", cls("showcase-prop-value"))]))),
        ], attrs: Some(HashMap<String, String>([("class", cls("showcase-prop-row"))])))
    }
}
