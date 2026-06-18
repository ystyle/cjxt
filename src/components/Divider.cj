package cjxt.components

import cjxt.*
import std.collection.HashMap

public class Divider <: Component {
    var _direction: DividerDirection = DividerDirection.Horizontal
    var _contentPosition: ContentPosition = ContentPosition.Center
    var _children: Array<Component> = []

    public init() {}
    public init(children: Array<Component>) { this._children = children }
    public func direction(v: DividerDirection): Divider { this._direction = v; this }
    public func contentPosition(v: ContentPosition): Divider { this._contentPosition = v; this }

    public func render(): Component {
        match (this._direction) {
            case Vertical => this.renderVertical()
            case Horizontal => this.renderHorizontal()
        }
    }

    func renderVertical(): Component {
        div([], attrs: Some(HashMap<String, String>([("class", "el-divider el-divider--vertical")])))
    }

    func renderHorizontal(): Component {
        let cls = "el-divider el-divider--horizontal"
        if (this._children.size == 0) {
            div([], attrs: Some(HashMap<String, String>([("class", cls)])))
        } else {
            let textCls = "el-divider__text is-${this._contentPosition.asClass()}"
            div([span(this._children, attrs: Some(HashMap<String, String>([("class", textCls)])))], attrs: Some(HashMap<String, String>([("class", cls)])))
        }
    }
}
