package cjxt.components

import cjxt.*
import std.collection.HashMap
import std.collection.ArrayList

public class Menu <: Component {
    var _mode: MenuMode = MenuMode.Vertical
    var _items = ArrayList<IComponent>()
    // 暗色主题：通过 EP CSS 变量驱动（:root 默认浅色，元素级变量覆盖）
    var _dark: Bool = false

    public init() {}

    public func mode(v: MenuMode): Menu {
        this._mode = v
        this
    }

    public func dark(): Menu {
        this._dark = true
        this
    }

    public func add(item: MenuItem): Menu {
        this._items.add(item)
        this
    }

    // 分组/子菜单等容器项（MenuItemGroup/SubMenu 均 <: Component）
    public func add(item: IComponent): Menu {
        this._items.add(item)
        this
    }

    public func render(): IComponent {
        let modeCls = match (this._mode) {
            case MenuMode.Horizontal => "el-menu el-menu--horizontal"
            case MenuMode.Vertical => "el-menu el-menu--vertical"
        }
        let attrs = HashMap<String, String>([("class", modeCls)])
        if (this._dark) {
            attrs["style"] = "--el-menu-bg-color:#1d2b3a;--el-menu-text-color:#c0c4cc;--el-menu-active-color:#ffffff;--el-menu-hover-text-color:#ffffff;--el-menu-hover-bg-color:#2a3b50;--el-menu-item-height:44px"
        }
        let items = ArrayList<IComponent>()
        for (i in 0..this._items.size) {
            items.add(this._items[i])
        }
        VNode("ul", items.toArray(), attrs: Some(attrs))
    }
}

public class MenuItem <: Component {
    var _index: String
    var _disabled: Bool = false
    var _active: Bool = false
    var _children: Array<IComponent>
    var _onClick: Option<ActionHandler> = None

    public init(index: String, children: Array<IComponent>) {
        this._index = index
        this._children = children
    }

    public func disabled(v: Bool): MenuItem {
        this._disabled = v
        this
    }

    public func active(v: Bool): MenuItem {
        this._active = v
        this
    }

    public func onClick(h: ActionHandler): MenuItem {
        this._onClick = Some(h)
        this
    }

    public func onClick(h: (ActionContext) -> Unit): MenuItem {
        let wrapped: ActionHandler = { ctx => h(ctx); PatchResult.ReRender }
        this.onClick(wrapped)
    }

    public func render(): IComponent {
        var cls = "el-menu-item"
        if (this._active) { cls = "${cls} is-active" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let attrs = HashMap<String, String>([("class", cls)])
        // EP vertical 菜单用 calc(base-padding + level*padding) 计算左内边距，
        // 但 level 变量由 Vue 组件设置、服务端渲染未设置 → calc 失效 padding 归零。
        // 内联兜底：显式设置 level=0 与左右内边距。
        attrs["style"] = "--el-menu-level: 0; padding-left: 20px; padding-right: 20px"
        if (this._disabled) { attrs["disabled"] = "true" }

        let el = VNode("li", this._children, attrs: Some(attrs))
        match (this._onClick) {
            case Some(h) => el.onClick(h)
            case None => el
        }
    }
}

// EP menu-item-group：li.el-menu-item-group > div.__title + ul > items（分组标题不可点击）
public class MenuItemGroup <: Component {
    var _label: String
    var _children: Array<IComponent>

    public init(label: String, children: Array<IComponent>) {
        this._label = label
        this._children = children
    }
    public func getChildren(): Array<IComponent> { this._children }

    public func render(): IComponent {
        // 标题 padding 依赖 --el-menu-base-level-padding（服务端渲染未设置 → 贴边），
        // 内联对齐菜单项（EP：padding: 7px 0 7px 20px, 12px 次级文字色由 scss 提供）
        let titleAttrs = HashMap<String, String>([
            ("class", "el-menu-item-group__title"),
            ("style", "padding: 9px 20px 7px 20px"),
        ])
        let title = div([text(this._label)], attrs: Some(titleAttrs))
        // 组间距（首组也无妨：与顶部导航栏留白一致）；inner ul 防 marker 圆点
        let liAttrs = HashMap<String, String>([("class", "el-menu-item-group"), ("style", "margin-top: 10px; list-style: none")])
        VNode("li", [title, VNode("ul", this._children, attrs: Some(HashMap<String, String>([("style", "list-style: none")])))], attrs: Some(liAttrs))
    }
}

// EP sub-menu：li.el-sub-menu[is-opened] > div.__title(@click 折叠，箭头 rotateZ) + ul.el-menu.el-menu--inline > items
public class SubMenu <: Component {
    var _title: String
    var _children: Array<IComponent>
    var _open: Signal<Bool>

    public init(title: String, children: Array<IComponent>) {
        this._title = title
        this._children = children
        this._open = Signal<Bool>(false)
    }
    public func getChildren(): Array<IComponent> { this._children }

    public func render(): IComponent {
        let isOpen = this._open.get()
        var cls = "el-sub-menu"
        if (isOpen) { cls = "${cls} is-opened" }
        let attrs = HashMap<String, String>([("class", cls)])

        // 标题行：点击折叠/展开（EP inline transform rotateZ 旋转箭头）
        let arrowIcon = Icon("arrow-down").size("12px").render()
        let arrowCls = "el-sub-menu__icon-arrow"
        let arrowStyle = if (isOpen) { "transform: rotateZ(180deg)" } else { "transform: none" }
        let arrow = VNode("span", [arrowIcon], attrs: Some(HashMap<String, String>([("class", arrowCls), ("style", arrowStyle)])))
        let title = VNode("div", [span([text(this._title)]), arrow], attrs: Some(HashMap<String, String>([("class", "el-sub-menu__title")])))
        let toggle: ActionHandler = { ctx =>
            this._open.set(!this._open.get())
            PatchResult.ReRender
        }
        let titleEl = title.onClick(toggle)

        let inline = VNode("ul", this._children, attrs: Some(HashMap<String, String>([("class", "el-menu el-menu--inline")])))
        VNode("li", [titleEl, inline], attrs: Some(attrs))
    }
}
