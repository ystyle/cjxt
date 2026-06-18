package cjxt.components

import cjxt.*
import std.collection.HashMap

public class Tag <: Component {
    var _children: Array<Component>
    var _kind: ComponentKind = ComponentKind.Default
    var _size: TagSize = TagSize.Default
    var _effect: TagEffect = TagEffect.Light
    var _closable: Bool = false
    var _hit: Bool = false
    var _onClose: Option<ActionHandler> = None

    public init(children: Array<Component>) { this._children = children }
    public func kind(v: ComponentKind): Tag { this._kind = v; this }
    public func size(v: TagSize): Tag { this._size = v; this }
    public func effect(v: TagEffect): Tag { this._effect = v; this }
    public func closable(): Tag { this._closable = true; this }
    public func hit(): Tag { this._hit = true; this }
    public func onClose(h: ActionHandler): Tag { this._onClose = Some(h); this }

    public func render(): Component {
        var cls = "el-tag"
        let kc = this._kind.asClass()
        if (kc != "") { cls = "${cls} el-tag--${kc}" }
        let sc = this._size.asClass()
        if (sc != "") { cls = "${cls} el-tag--${sc}" }
        cls = "${cls} el-tag--${this._effect.asClass()}"
        if (this._hit) { cls = "${cls} is-hit" }
        let attrs = HashMap<String, String>([("class", cls)])
        if (this._closable) {
            this.renderClosable(attrs)
        } else {
            span(this._children, attrs: Some(attrs))
        }
    }

    func renderClosable(attrs: HashMap<String, String>): Component {
        let closeIcon = i([], attrs: Some(HashMap<String, String>([("class", "el-tag__close el-icon-close")]))).onClick(this._onClose)
        span([Fragment(this._children), closeIcon], attrs: Some(attrs))
    }
}

public class Badge <: Component {
    var _children: Array<Component>
    var _value: String = ""
    var _max: Int64 = 99
    var _dot: Bool = false
    var _kind: ComponentKind = ComponentKind.Danger

    public init(children: Array<Component>) { this._children = children }
    public func value(v: Int64): Badge { this._value = v.toString(); this }
    public func value(v: String): Badge { this._value = v; this }
    public func max(v: Int64): Badge { this._max = v; this }
    public func dot(): Badge { this._dot = true; this }
    public func kind(v: ComponentKind): Badge { this._kind = v; this }

    public func render(): Component {
        let outerCls = "el-badge"
        var contentCls = "el-badge__content"
        if (this._dot) { contentCls = "${contentCls} is-dot" }
        contentCls = "${contentCls} el-badge__content--${this._kind.asClass()}"
        let displayValue = if (this._dot) { "" } else { this._value }
        let supAttrs = HashMap<String, String>([("class", contentCls)])
        let badgeEl = VNode("sup", [text(displayValue)], attrs: Some(supAttrs))
        div([Fragment(this._children), badgeEl], attrs: Some(HashMap<String, String>([("class", outerCls)])))
    }
}
