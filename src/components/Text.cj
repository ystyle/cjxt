package cjxt.components

import cjxt.*
import std.collection.HashMap

public class Text <: Component {
    var _children: Array<IComponent>
    var _kind: ComponentKind = ComponentKind.Default
    var _size: TextSize = TextSize.Default
    var _truncated: Bool = false

    public init(children: Array<IComponent>) { this._children = children }
    public func kind(v: ComponentKind): Text { this._kind = v; this }
    public func size(v: TextSize): Text { this._size = v; this }
    public func truncated(): Text { this._truncated = true; this }

    public func render(): IComponent {
        var cls = "el-text"
        let kc = this._kind.asClass()
        if (kc != "") { cls = "${cls} is-${kc}" }
        let sc = this._size.asClass()
        if (sc != "") { cls = "${cls} el-text--${sc}" }
        if (this._truncated) { cls = "${cls} is-truncated" }
        span(this._children, attrs: Some(HashMap<String, String>([("class", cls)])))
    }
}

public class Link <: Component {
    var _children: Array<IComponent>
    var _kind: ComponentKind = ComponentKind.Default
    var _underline: Bool = true
    var _disabled: Bool = false
    var _href: String = ""
    var _onClick: Option<ActionHandler> = None

    public init(children: Array<IComponent>) { this._children = children }
    public func kind(v: ComponentKind): Link { this._kind = v; this }
    public func underline(v: Bool): Link { this._underline = v; this }
    public func disabled(): Link { this._disabled = true; this }
    public func href(v: String): Link { this._href = v; this }
    public func onClick(h: ActionHandler): Link { this._onClick = Some(h); this }

    public func render(): IComponent {
        var cls = "el-link"
        let kc = this._kind.asClass()
        if (kc != "") { cls = "${cls} el-link--${kc}" }
        if (this._underline) { cls = "${cls} is-underline" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let attrs = HashMap<String, String>([("class", cls)])
        if (this._href != "") { attrs["href"] = this._href }
        if (this._disabled) { attrs["disabled"] = "disabled" }
        a(this._children, attrs: Some(attrs)).onClick(this._onClick)
    }
}
