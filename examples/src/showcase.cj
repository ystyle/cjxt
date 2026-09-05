// ShowcasePage：演示站页面壳（package examples）
// 所有 demo / props / 状态实现已拆到 src/showcase/ 子包（examples.showcase），
// 本文件只保留页面骨架与分发逻辑。
// 注意：@Page 宏生成的顶层注册只会在主包执行，因此 ShowcasePage 必须留在主包。

package examples

import cjxt.*
import cjxt.macros.*
import cjxt.components.*
import examples.showcase.*
import std.collection.{HashMap, ArrayList}

// 侧边栏分组（对应 showcase/ 下 8 个分类文件；菜单分组标题不可点击）
public struct MenuCategory {
    let label: String
    let names: Array<String>
    public init(label: String, names: Array<String>) {
        this.label = label
        this.names = names
    }
}

let menuGroups: Array<MenuCategory> = [
    MenuCategory("基础", ["Button", "ButtonGroup", "Card", "RowCol", "Divider", "Text", "Link", "Tag", "Badge", "Space", "Icon"]),
    MenuCategory("表单", ["Input", "InputNumber", "Switch", "Radio", "Checkbox", "Rate", "Select", "Slider", "Form"]),
    MenuCategory("数据", ["Table", "Pagination", "DatePicker", "DateRangePicker", "Tree", "Cascader", "Upload"]),
    MenuCategory("导航", ["Tabs", "Breadcrumb", "Steps", "Dropdown"]),
    MenuCategory("反馈", ["Message", "Notification", "Loading", "Skeleton"]),
    MenuCategory("遮罩层", ["Dialog", "Drawer", "Tooltip", "Popover"]),
    MenuCategory("展示", ["Progress", "Avatar", "Empty", "Descriptions", "Statistic", "Result"]),
    MenuCategory("高级", ["Markdown", "AutoScroll", "Reactive", "VirtualList", "DomTx"]),
]

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
        for (g in menuGroups) {
            let items = ArrayList<IComponent>()
            for (name in g.names) {
                let active = name == sel
                items.add(
                    MenuItem(name, [text(name)]).active(active).onClick({ ctx =>
                        this.state.selected.set(name)
                    })
                )
            }
            menu.add(MenuItemGroup(g.label, items.toArray()))
        }
        let attrs = HashMap<String, String>([("class", "${cls("showcase-sidebar")} showcase-menu-wrap")])
        div([menu], attrs: Some(attrs))
    }

    func demoArea(sel: String): IComponent {
        div(this.renderDemo(sel), attrs: Some(HashMap<String, String>([("class", cls("showcase-demo"))])))
    }

    func propsPanel(sel: String): IComponent {
        let titleCls = HashMap<String, String>([("class", cls("showcase-props-title"))])
        div([
            div([text("属性")], attrs: Some(titleCls)),
            this.renderProps(sel),
        ], attrs: Some(HashMap<String, String>([("class", cls("showcase-props"))])))
    }

    // ============ Demo 分发 ============

    func renderDemo(sel: String): Array<IComponent> {
        match (sel) {
            case "Button" => demoButton(this.state)
            case "ButtonGroup" => demoButtonGroup(this.state)
            case "Card" => demoCard(this.state)
            case "RowCol" => demoRowCol(this.state)
            case "Divider" => demoDivider(this.state)
            case "Text" => demoText(this.state)
            case "Link" => demoLink(this.state)
            case "Tag" => demoTag(this.state)
            case "Badge" => demoBadge(this.state)
            case "Space" => demoSpace(this.state)
            case "Icon" => demoIcon(this.state)
            case "Input" => demoInput(this.state)
            case "InputNumber" => demoInputNumber(this.state)
            case "Switch" => demoSwitch(this.state)
            case "Radio" => demoRadio(this.state)
            case "Checkbox" => demoCheckbox(this.state)
            case "Rate" => demoRate(this.state)
            case "Select" => demoSelect(this.state)
            case "Slider" => demoSlider(this.state)
            case "Form" => demoForm(this.state)
            case "Table" => demoTable(this.state)
            case "Dialog" => demoDialog(this.state)
            case "Drawer" => demoDrawer(this.state)
            case "Tooltip" => demoTooltip(this.state)
            case "Popover" => demoPopover(this.state)
            case "Progress" => demoProgress(this.state)
            case "Avatar" => demoAvatar(this.state)
            case "Empty" => demoEmpty(this.state)
            case "Descriptions" => demoDescriptions(this.state)
            case "Statistic" => demoStatistic(this.state)
            case "Result" => demoResult(this.state)
            case "Pagination" => demoPagination(this.state)
            case "DatePicker" => demoDatePicker(this.state)
            case "DateRangePicker" => demoDatePicker(this.state)
            case "Message" => demoMessage(this.state)
            case "Notification" => demoNotification(this.state)
            case "Loading" => demoLoading(this.state)
            case "Skeleton" => demoSkeleton(this.state)
            case "Tabs" => demoTabs(this.state)
            case "Markdown" => demoMarkdown(this.state)
            case "AutoScroll" => demoAutoScroll(this.state)
            case "Reactive" => demoReactive(this.state)
            case "VirtualList" => demoVirtualList(this.state)
            case "DomTx" => demoDomTx(this.state)
            case "Breadcrumb" => demoBreadcrumb(this.state)
            case "Steps" => demoSteps(this.state)
            case "Dropdown" => demoDropdown(this.state)
            case "Tree" => demoTree(this.state)
            case "Cascader" => demoCascader(this.state)
            case "Upload" => demoUpload(this.state)
            case _ => []
        }
    }

    // ============ Props 分发 ============

    func renderProps(sel: String): IComponent {
        match (sel) {
            case "Button" => propsButton()
            case "ButtonGroup" => propsButtonGroup()
            case "Card" => propsCard()
            case "RowCol" => propsRowCol()
            case "Divider" => propsDivider()
            case "Text" => propsText()
            case "Link" => propsLink()
            case "Tag" => propsTag()
            case "Badge" => propsBadge()
            case "Space" => propsSpace()
            case "Icon" => propsIcon()
            case "Input" => propsInput()
            case "InputNumber" => propsInputNumber()
            case "Switch" => propsSwitch()
            case "Radio" => propsRadio()
            case "Checkbox" => propsCheckbox()
            case "Rate" => propsRate()
            case "Select" => propsSelect()
            case "Slider" => propsSlider()
            case "Form" => propsForm()
            case "Table" => propsTable()
            case "Dialog" => propsDialog()
            case "Drawer" => propsDrawer()
            case "Tooltip" => propsTooltip()
            case "Popover" => propsPopover()
            case "Progress" => propsProgress()
            case "Avatar" => propsAvatar()
            case "Empty" => propsEmpty()
            case "Descriptions" => propsDescriptions()
            case "Statistic" => propsStatistic()
            case "Result" => propsResult()
            case "Pagination" => propsPagination()
            case "DatePicker" => propsDatePicker()
            case "DateRangePicker" => propsDateRangePicker()
            case "Message" => propsMessage()
            case "Notification" => propsNotification()
            case "Loading" => propsLoading()
            case "Skeleton" => propsSkeleton()
            case "Tabs" => propsTabs()
            case "Markdown" => propsMarkdown()
            case "AutoScroll" => propsAutoScroll()
            case "Reactive" => propsReactive()
            case "VirtualList" => propsVirtualList()
            case "DomTx" => propsDomTx()
            case "Breadcrumb" => propsBreadcrumb()
            case "Steps" => propsSteps()
            case "Dropdown" => propsDropdown()
            case "Tree" => propsTree()
            case "Cascader" => propsCascader()
            case "Upload" => propsUpload()
            case _ => text("选择左侧组件查看属性")
        }
    }
}
