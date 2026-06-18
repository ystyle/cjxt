package cjxt.components

import cjxt.*
import std.collection.HashMap
import std.collection.ArrayList

public class Menu <: Component {
    var _mode: MenuMode = MenuMode.Vertical
    var _items = ArrayList<MenuItem>()

    public init() {}

    public func mode(v: MenuMode): Menu {
        this._mode = v
        this
    }

    public func add(item: MenuItem): Menu {
        this._items.add(item)
        this
    }

    public func render(): IComponent {
        let modeCls = match (this._mode) {
            case MenuMode.Horizontal => "el-menu el-menu--horizontal"
            case MenuMode.Vertical => "el-menu el-menu--vertical"
        }
        let attrs = HashMap<String, String>([("class", modeCls)])
        let items = ArrayList<IComponent>()
        for (i in 0..this._items.size) {
            items.add(this._items[i].render())
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

    public func render(): IComponent {
        var cls = "el-menu-item"
        if (this._active) { cls = "${cls} is-active" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let attrs = HashMap<String, String>([("class", cls)])
        if (this._disabled) { attrs["disabled"] = "true" }

        let el = VNode("li", this._children, attrs: Some(attrs))
        match (this._onClick) {
            case Some(h) => el.onClick(h)
            case None => el
        }
    }
}
