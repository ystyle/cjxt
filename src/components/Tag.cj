package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}
import std.convert

public class Tag <: Component {
    var _children: Array<IComponent>
    var _kind: ComponentKind = ComponentKind.Default
    var _size: TagSize = TagSize.Default
    var _effect: TagEffect = TagEffect.Light
    var _closable: Bool = false
    var _hit: Bool = false
    var _round: Bool = false
    var _color: String = ""
    var _onClose: Option<ActionHandler> = None
    var _onClick: Option<ActionHandler> = None

    public init(children: Array<IComponent>) { this._children = children }
    public func kind(v: ComponentKind): Tag { this._kind = v; this }
    public func size(v: TagSize): Tag { this._size = v; this }
    public func effect(v: TagEffect): Tag { this._effect = v; this }
    public func closable(): Tag { this._closable = true; this }
    public func hit(): Tag { this._hit = true; this }
    public func round(): Tag { this._round = true; this }
    public func color(v: String): Tag { this._color = v; this }
    public func onClose(h: ActionHandler): Tag { this._onClose = Some(h); this }
    public func onClick(h: ActionHandler): Tag { this._onClick = Some(h); this }
    public func onClick(h: (ActionContext) -> Unit): Tag {
        let wrapped: ActionHandler = { ctx => h(ctx); PatchResult.ReRender }
        this.onClick(wrapped)
    }

    public func render(): IComponent {
        var cls = "el-tag"
        // EP 默认 type='primary'（tag.ts）；ComponentKind.Default 不产生修饰符 → 默认无 --el-tag-text-color
        let kc = match (this._kind) {
            case ComponentKind.Default => "primary"
            case k => k.asClass()
        }
        if (kc != "") { cls = "${cls} el-tag--${kc}" }
        let sc = this._size.asClass()
        if (sc != "") { cls = "${cls} el-tag--${sc}" }
        cls = "${cls} el-tag--${this._effect.asClass()}"
        if (this._hit) { cls = "${cls} is-hit" }
        if (this._round) { cls = "${cls} is-round" }
        if (this._closable) { cls = "${cls} is-closable" }

        let attrs = HashMap<String, String>([("class", cls)])
        if (this._color != "") { attrs["style"] = "background-color:${this._color}" }

        let content = ArrayList<IComponent>()
        content.add(span(this._children, attrs: Some(HashMap<String, String>([("class", "el-tag__content")]))))
        if (this._closable) {
            let closeBtn = Icon("close").render()
            let closeEl = VNode("button", [closeBtn], attrs: Some(HashMap<String, String>([("class", "el-tag__close"), ("type", "button"), ("aria-label", "close")])))
            // 前端点击委托 closest([data-action-click]) 取最近元素 —— 关闭按钮自身带 handler，
            // 不会冒泡触发 tag 根 onClick（对齐 EP 的 @click.stop="handleClose"）
            match (this._onClose) {
                case Some(h) => content.add(closeEl.onClick(h))
                case None => content.add(closeEl)
            }
        }

        let el = VNode("span", content.toArray(), attrs: Some(attrs))
        match (this._onClick) {
            case Some(h) => el.onClick(h)
            case None => el
        }
    }
}

public class Badge <: Component {
    var _children: Array<IComponent>
    var _value: String = ""
    var _max: Int64 = 99
    var _dot: Bool = false
    var _hidden: Bool = false
    var _showZero: Bool = true
    var _kind: ComponentKind = ComponentKind.Danger

    public init(children: Array<IComponent>) { this._children = children }
    public func value(v: Int64): Badge { this._value = v.toString(); this }
    public func value(v: String): Badge { this._value = v; this }
    public func max(v: Int64): Badge { this._max = v; this }
    public func dot(): Badge { this._dot = true; this }
    public func hidden(): Badge { this._hidden = true; this }
    public func showZero(v: Bool): Badge { this._showZero = v; this }
    public func kind(v: ComponentKind): Badge { this._kind = v; this }

    func computeDisplayValue(): String {
        if (this._dot) { return "" }
        let n = this.parseInt(this._value)
        if (n >= 0) {
            if (n == 0 && !this._showZero) { return "" }
            if (n > this._max) { return "${this._max}+" }
        }
        this._value
    }

    func parseInt(s: String): Int64 {
        try {
            Int64.parse(s)
        } catch (e: Error) {
            -1
        }
    }

    public func render(): IComponent {
        let outerCls = "el-badge"
        var contentCls = "el-badge__content"
        if (this._dot) { contentCls = "${contentCls} is-dot" }
        let hasChildren = this._children.size > 0
        if (hasChildren) { contentCls = "${contentCls} is-fixed" }
        let kc = this._kind.asClass()
        if (kc != "") { contentCls = "${contentCls} el-badge__content--${kc}" }

        let displayValue = this.computeDisplayValue()
        // EP badge.vue：值 0 且 showZero=false → is-hide-zero（scss display:none）；
        // 无值且非 dot 且无子项 slot 时不渲染 sup（旧实现空值也渲染空 sup）
        let isZero = this.parseInt(this._value) == 0 && this._value != ""
        if (isZero && !this._showZero) { contentCls = "${contentCls} is-hide-zero" }

        let parts = ArrayList<IComponent>()
        if (hasChildren) {
            parts.add(Fragment(this._children))
        }
        if (!this._hidden && (this._dot || this._value != "")) {
            let supAttrs = HashMap<String, String>([("class", contentCls)])
            parts.add(VNode("sup", [text(displayValue)], attrs: Some(supAttrs)))
        }
        div(parts.toArray(), attrs: Some(HashMap<String, String>([("class", outerCls)])))
    }
}
