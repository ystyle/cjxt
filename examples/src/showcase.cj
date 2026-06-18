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
                this.propRow("kind", "Default | Primary | Success | Warning | Danger | Info"),
                this.propRow("size", "Large | Default | Small"),
                this.propRow("plain / round / circle", "false"),
                this.propRow("loading / disabled", "false"),
                this.propRow("text / link / bg", "false"),
                this.propRow("icon(name)", "String"),
                this.propRow("onClick", "(ActionContext) -> PatchResult"),
            ])
            case "ButtonGroup" => div([
                this.propRow("children", "Array<IComponent>"),
                this.propRow("direction", "Horizontal | Vertical"),
                this.propRow("size / kind", "apply to children"),
            ])
            case "Card" => div([
                this.propRow("header", "String | Array<IComponent>"),
                this.propRow("footer", "String | Array<IComponent>"),
                this.propRow("shadow", "Always | Hover | Never"),
                this.propRow("bodyStyle / bodyClass", "String"),
            ])
            case "RowCol" => div([
                this.propRow("Row.gutter", "Int64"),
                this.propRow("Row.justify", "Start | End | Center | SpaceAround | SpaceBetween | SpaceEvenly"),
                this.propRow("Row.align", "Top | Middle | Bottom"),
                this.propRow("Col.span", "Int64 (默认 24)"),
                this.propRow("Col.offset / push / pull", "Int64"),
            ])
            case "Divider" => div([
                this.propRow("direction", "Horizontal | Vertical"),
                this.propRow("contentPosition", "Left | Center | Right"),
            ])
            case "Text" => div([
                this.propRow("kind", "Default | Primary | Success | Warning | Danger | Info | Plain"),
                this.propRow("size", "Default | Large | Small"),
                this.propRow("truncated", "false"),
                this.propRow("lineClamp", "Int64"),
                this.propRow("tag", "String (默认 span)"),
            ])
            case "Link" => div([
                this.propRow("kind", "Default | Primary | Success | Warning | Danger | Info"),
                this.propRow("underline", "Always | Hover | Never"),
                this.propRow("href / target", "String"),
                this.propRow("disabled", "false"),
                this.propRow("icon(name)", "String"),
                this.propRow("onClick", "(ActionContext) -> PatchResult"),
            ])
            case "Tag" => div([
                this.propRow("kind", "Default | Primary | Success | Warning | Danger | Info"),
                this.propRow("size", "Default | Large | Medium | Small | Mini"),
                this.propRow("effect", "Dark | Light | Plain"),
                this.propRow("closable / hit / round", "false"),
                this.propRow("color", "String"),
            ])
            case "Badge" => div([
                this.propRow("value", "Int64 | String"),
                this.propRow("max", "Int64 (默认 99)"),
                this.propRow("dot / hidden", "false"),
                this.propRow("showZero", "true"),
                this.propRow("kind", "Default | Primary | Success | Warning | Danger | Info"),
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
                this.propRow("clearable / disabled / password", "false"),
                this.propRow("prefixIcon / suffixIcon", "String"),
                this.propRow("bind(signal)", "Signal<String>"),
            ])
            case "InputNumber" => div([
                this.propRow("min / max / step", "Int64"),
                this.propRow("size", "Large | Default | Small"),
                this.propRow("noControls", "隐藏 +/- 按钮"),
                this.propRow("bind(signal)", "Signal<Int64>"),
            ])
            case "Switch" => div([
                this.propRow("activeText / inactiveText", "String"),
                this.propRow("activeValue / inactiveValue", "Bool"),
                this.propRow("size", "Large | Default | Small"),
                this.propRow("disabled", "false"),
                this.propRow("bind(signal)", "Signal<Bool>"),
            ])
            case "Radio" => div([
                this.propRow("Radio(value)", "String"),
                this.propRow("Radio.disabled", "false"),
                this.propRow("RadioGroup.bind(signal)", "Signal<String>"),
            ])
            case "Checkbox" => div([
                this.propRow("Checkbox(value)", "String"),
                this.propRow("Checkbox.disabled", "false"),
                this.propRow("CheckboxGroup.bind(signal)", "Signal<ArrayList<String>>"),
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
