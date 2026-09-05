package cjxt.components

import cjxt.*
import std.collection.HashMap

public class Divider <: Component {
    var _direction: DividerDirection = DividerDirection.Horizontal
    var _contentPosition: ContentPosition = ContentPosition.Center
    var _borderStyle: String = "solid"
    var _children: Array<IComponent> = []

    public init() {}
    public init(children: Array<IComponent>) { this._children = children }
    public func direction(v: DividerDirection): Divider { this._direction = v; this }
    public func contentPosition(v: ContentPosition): Divider { this._contentPosition = v; this }
    public func borderStyle(v: String): Divider { this._borderStyle = v; this }

    public func render(): IComponent {
        match (this._direction) {
            case Vertical => this.renderVertical()
            case Horizontal => this.renderHorizontal()
        }
    }

    // EP divider.vue：root style 设 --el-divider-border-style（borderStyle prop，默认 solid）+ role=separator
    func rootAttrs(cls: String): HashMap<String, String> {
        HashMap<String, String>([("class", cls), ("style", "--el-divider-border-style:${this._borderStyle}"), ("role", "separator")])
    }

    func renderVertical(): IComponent {
        div([], attrs: Some(this.rootAttrs("el-divider el-divider--vertical")))
    }

    func renderHorizontal(): IComponent {
        let cls = "el-divider el-divider--horizontal"
        if (this._children.size == 0) {
            div([], attrs: Some(this.rootAttrs(cls)))
        } else {
            let textCls = "el-divider__text is-${this._contentPosition.asClass()}"
            div([span(this._children, attrs: Some(HashMap<String, String>([("class", textCls)])))], attrs: Some(this.rootAttrs(cls)))
        }
    }
}
