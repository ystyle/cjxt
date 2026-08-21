package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// ============ Tabs 标签页（对齐 Element Plus） ============

public class TabPane <: Component {
    var _children: Array<IComponent>
    var _name: String
    var _label: String
    var _disabled: Bool = false

    public init(children: Array<IComponent>, name: String, label: String) {
        this._children = children
        this._name = name
        this._label = label
    }

    public func label(v: String): TabPane { this._label = v; this }
    public func disabled(): TabPane { this._disabled = true; this }

    // TabPane 自身不单独渲染节点（Tabs 消费其属性）；返回稳定空容器防补丁槽位错位
    public func render(): IComponent {
        div([])
    }
}

public class Tabs <: Component {
    var _children: Array<IComponent>
    var _activeSignal: Option<Signal<String>> = None
    var _type: String = "line"        // line | card | border-card
    var _position: String = "top"     // top | bottom | left | right
    var _onChangeHandler: Option<ActionHandler> = None

    public init(children: Array<IComponent>) {
        this._children = children
    }

    public func bind(signal: Signal<String>): Tabs { this._activeSignal = Some(signal); this }
    // type 是仓颉关键字，方法命名 tabType
    public func tabType(v: String): Tabs { this._type = v; this }
    public func position(v: String): Tabs { this._position = v; this }
    public func onChange(h: ActionHandler): Tabs { this._onChangeHandler = Some(h); this }

    public func render(): IComponent {
        let panes = this.collectPanes()
        let active = this.effectiveActive(panes, this.activeName())
        let rootCls = "el-tabs el-tabs--${this._position} el-tabs--${this._type}"
        let header = this.buildHeader(panes, active)
        let content = this.buildContent(panes, active)
        VNode("div", [header, content], attrs: Some(HashMap<String, String>([("class", rootCls), ("role", "tablist")])))
    }

    private func collectPanes(): ArrayList<TabPane> {
        let result = ArrayList<TabPane>()
        for (c in this._children) {
            match (c) {
                case tp: TabPane => result.add(tp)
                case _ => ()
            }
        }
        result
    }

    private func activeName(): String {
        match (this._activeSignal) { case Some(s) => s.get(); case None => "" }
    }

    private func setActive(name: String): Unit {
        match (this._activeSignal) { case Some(s) => s.set(name); case None => () }
    }

    private func effectiveActive(panes: ArrayList<TabPane>, active: String): String {
        let names = ArrayList<String>()
        for (p in panes) { names.add(p._name) }
        resolveActiveTab(active, names)
    }

    // ── header ──
    private func buildHeader(panes: ArrayList<TabPane>, active: String): IComponent {
        let items = ArrayList<IComponent>()
        for (pane in panes) {
            items.add(this.buildNavItem(pane, active))
        }
        let nav = VNode("div", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-tabs__nav"), ("role", "tablist")])))
        let navScroll = VNode("div", [nav], attrs: Some(HashMap<String, String>([("class", "el-tabs__nav-scroll")])))
        let navWrap = VNode("div", [navScroll], attrs: Some(HashMap<String, String>([("class", "el-tabs__nav-wrap")])))
        VNode("div", [navWrap], attrs: Some(HashMap<String, String>([("class", "el-tabs__header")])))
    }

    private func buildNavItem(pane: TabPane, active: String): IComponent {
        let isActive = pane._name == active
        var cls = "el-tabs__item"
        if (isActive) { cls = "${cls} is-active" }
        if (pane._disabled) { cls = "${cls} is-disabled" }
        let attrs = HashMap<String, String>([("class", cls), ("role", "tab"), ("aria-selected", if (isActive) { "true" } else { "false" })])
        if (pane._disabled) { attrs["aria-disabled"] = "true" }
        var item = VNode("div", [text(pane._label)], attrs: Some(attrs))
        if (!pane._disabled) {
            let name = pane._name
            item = item.onClick({ ctx => this.onTabClick(ctx, name) })
        }
        item
    }

    // ── content：仅渲染当前激活 pane ──
    private func buildContent(panes: ArrayList<TabPane>, active: String): IComponent {
        let children = ArrayList<IComponent>()
        for (pane in panes) {
            if (pane._name == active) {
                children.add(VNode("div", pane._children, attrs: Some(HashMap<String, String>([("class", "el-tab-pane"), ("role", "tabpanel")]))))
            }
        }
        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", "el-tabs__content")])))
    }

    private func onTabClick(ctx: ActionContext, name: String): PatchResult {
        if (name != this.activeName()) {
            this.setActive(name)
            this.invokeHandler(this._onChangeHandler, ctx)
        }
        PatchResult.ReRender
    }

    private func invokeHandler(h: Option<ActionHandler>, ctx: ActionContext): Unit {
        match (h) {
            case Some(fn) => runCb(fn, ctx)
            case None => ()
        }
    }
}
