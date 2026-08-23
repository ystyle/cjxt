package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ============ Breadcrumb 面包屑导航（对齐 Element Plus） ============

public class BreadcrumbItem <: Component {
    var _content: String = ""
    var _to: String = ""            // 点击跳转路径（可选）
    var _onClick: Option<ActionHandler> = None

    public func content(v: String): BreadcrumbItem { this._content = v; this }
    public func to(path: String): BreadcrumbItem { this._to = path; this }
    public func onClick(h: ActionHandler): BreadcrumbItem { this._onClick = Some(h); this }

    public func render(): IComponent {
        div([]) // 数据载体，不单独渲染
    }

    func isLink(): Bool { this._to != "" || this._onClick.isSome() }
}

public class Breadcrumb <: Component {
    var _children: Array<IComponent>
    var _separator: String = "/"

    public init(children: Array<IComponent>) {
        this._children = children
    }

    public func separator(v: String): Breadcrumb { this._separator = v; this }

    public func render(): IComponent {
        let items = this.collectItems()
        let count = items.size
        let children = ArrayList<IComponent>()
        var i = 0
        for (item in items) {
            children.add(this.buildItem(item, i, count))
            i += 1
        }
        let attrs = HashMap<String, String>()
        attrs["class"] = "el-breadcrumb"
        attrs["role"] = "navigation"
        attrs["aria-label"] = "Breadcrumb"
        VNode("div", children.toArray(), attrs: Some(attrs))
    }

    func collectItems(): ArrayList<BreadcrumbItem> {
        let result = ArrayList<BreadcrumbItem>()
        for (c in this._children) {
            match (c) {
                case item: BreadcrumbItem => result.add(item)
                case _ => ()
            }
        }
        result
    }

    func buildItem(item: BreadcrumbItem, idx: Int64, count: Int64): IComponent {
        let isLast = idx == count - 1
        // inner
        var innerCls = "el-breadcrumb__inner"
        if (item.isLink()) { innerCls = "${innerCls} is-link" }
        var inner = VNode("span", [text(item._content)], attrs: Some(HashMap<String, String>([("class", innerCls), ("role", "link")])))
        if (item._to != "") {
            let path = item._to
            let h: ActionHandler = { ctx => ctx.route.push(path); PatchResult.ReRender }
            inner = inner.onClick(h)
        } else {
            match (item._onClick) {
                case Some(fn) => inner = inner.onClick(fn)
                case None => ()
            }
        }
        let parts = ArrayList<IComponent>()
        parts.add(inner)
        if (!isLast) {
            // separator
            let sep = VNode("span", [text(this._separator)], attrs: Some(HashMap<String, String>([("class", "el-breadcrumb__separator"), ("role", "presentation")])))
            parts.add(sep)
        }
        // item span
        let itemAttrs = HashMap<String, String>()
        itemAttrs["class"] = "el-breadcrumb__item"
        if (isLast) { itemAttrs["aria-current"] = "page" }
        VNode("span", parts.toArray(), attrs: Some(itemAttrs))
    }
}
