package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Space <: Component {
    var _children: Array<IComponent>
    var _size: Int64 = 8
    var _direction: SpaceDirection = SpaceDirection.Horizontal
    var _wrap: Bool = false

    public init(children: Array<IComponent>) { this._children = children }
    public func size(v: Int64): Space { this._size = v; this }
    public func direction(v: SpaceDirection): Space { this._direction = v; this }
    public func wrap(): Space { this._wrap = true; this }

    public func render(): IComponent {
        var cls = "el-space el-space--${this._direction.asClass()}"
        if (this._wrap) { cls = "${cls} el-space--wrap" }
        let attrs = HashMap<String, String>([("class", cls), ("style", "gap: ${this._size}px")])
        let items = ArrayList<IComponent>()
        for (c in this._children) {
            items.add(div([c], attrs: Some(HashMap<String, String>([("class", "el-space__item")]))))
        }
        div(items.toArray(), attrs: Some(attrs))
    }
}

public class ButtonGroup <: Component {
    var _children: Array<IComponent>

    public init(children: Array<IComponent>) { this._children = children }

    public func render(): IComponent {
        div(this._children, attrs: Some(HashMap<String, String>([("class", "el-button-group")])))
    }
}
