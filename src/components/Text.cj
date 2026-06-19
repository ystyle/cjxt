package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Text <: Component {
    var _children: Array<IComponent>
    var _kind: ComponentKind = ComponentKind.Default
    var _size: TextSize = TextSize.Default
    var _truncated: Bool = false
    var _lineClamp: Int64 = -1
    var _tag: String = "span"

    public init(children: Array<IComponent>) { this._children = children }
    public func kind(v: ComponentKind): Text { this._kind = v; this }
    public func size(v: TextSize): Text { this._size = v; this }
    public func truncated(): Text { this._truncated = true; this }
    public func lineClamp(v: Int64): Text { this._lineClamp = v; this }
    public func tag(v: String): Text { this._tag = v; this }

    public func render(): IComponent {
        var cls = "el-text"
        let kc = this._kind.asClass()
        if (kc != "") { cls = "${cls} el-text--${kc}" }
        let sc = this._size.asClass()
        if (sc != "") { cls = "${cls} el-text--${sc}" }
        if (this._truncated) { cls = "${cls} is-truncated" }
        if (this._lineClamp > 0) { cls = "${cls} is-line-clamp" }
        let attrs = HashMap<String, String>([("class", cls)])
        if (this._lineClamp > 0) { attrs["style"] = "-webkit-line-clamp: ${this._lineClamp}" }
        VNode(this._tag, this._children, attrs: Some(attrs))
    }
}

public enum LinkUnderline {
    | Always | Hover | Never

    public func asClass(): String {
        match (this) {
            case Always => "is-underline"
            case Hover => "is-hover-underline"
            case Never => ""
        }
    }
}

public class Link <: Component {
    var _children: Array<IComponent>
    var _kind: ComponentKind = ComponentKind.Default
    var _underline: LinkUnderline = LinkUnderline.Hover
    var _disabled: Bool = false
    var _href: String = ""
    var _target: String = "_self"
    var _iconName: Option<String> = None
    var _onClick: Option<ActionHandler> = None

    public init(children: Array<IComponent>) { this._children = children }
    public func kind(v: ComponentKind): Link { this._kind = v; this }
    public func underline(v: LinkUnderline): Link { this._underline = v; this }
    public func noUnderline(): Link { this._underline = LinkUnderline.Never; this }
    public func disabled(): Link { this._disabled = true; this }
    public func href(v: String): Link { this._href = v; this }
    public func target(v: String): Link { this._target = v; this }
    public func icon(name: String): Link { this._iconName = Some(name); this }
    public func onClick(h: ActionHandler): Link { this._onClick = Some(h); this }
    public func onClick(h: (ActionContext) -> Unit): Link {
        let wrapped: ActionHandler = { ctx => h(ctx); PatchResult.ReRender }
        this.onClick(wrapped)
    }

    public func render(): IComponent {
        var cls = "el-link"
        let kc = this._kind.asClass()
        if (kc != "") { cls = "${cls} el-link--${kc}" }
        let uc = this._underline.asClass()
        if (uc != "") { cls = "${cls} ${uc}" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let attrs = HashMap<String, String>([("class", cls)])
        if (this._href != "" && !this._disabled) {
            attrs["href"] = this._href
            attrs["target"] = this._target
        }
        if (this._disabled) { attrs["disabled"] = "disabled" }

        let inner = ArrayList<IComponent>()
        match (this._iconName) {
            case Some(name) => inner.add(Icon(name).render())
            case None => ()
        }
        inner.add(span(this._children, attrs: Some(HashMap<String, String>([("class", "el-link__inner")]))))

        let el = a(inner.toArray(), attrs: Some(attrs))
        match (this._onClick) {
            case Some(h) => if (!this._disabled) { el.onClick(h) } else { el }
            case None => el
        }
    }
}
