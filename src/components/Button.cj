package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Button <: Component {
    var _children: Array<IComponent>
    var _kind: ButtonKind = ButtonKind.Default
    var _size: ButtonSize = ButtonSize.Default
    var _nativeType: ButtonNativeType = ButtonNativeType.Button
    var _plain: Bool = false
    var _round: Bool = false
    var _circle: Bool = false
    var _disabled: Bool = false
    var _loading: Bool = false
    var _text: Bool = false
    var _link: Bool = false
    var _bg: Bool = false
    var _autofocus: Bool = false
    var _iconName: Option<String> = None
    var _onClick: Option<ActionHandler> = None

    public init(label: String) {
        this._children = [text(label)]
    }

    public init(children: Array<IComponent>) {
        this._children = children
    }

    public func kind(v: ButtonKind): Button { this._kind = v; this }
    public func size(v: ButtonSize): Button { this._size = v; this }
    public func nativeType(v: ButtonNativeType): Button { this._nativeType = v; this }
    public func plain(): Button { this._plain = true; this }
    public func round(): Button { this._round = true; this }
    public func circle(): Button { this._circle = true; this }
    public func disabled(): Button { this._disabled = true; this }
    public func loading(): Button { this._loading = true; this }
    public func text(): Button { this._text = true; this }
    public func link(): Button { this._link = true; this }
    public func bg(): Button { this._bg = true; this }
    public func autofocus(): Button { this._autofocus = true; this }
    public func icon(name: String): Button { this._iconName = Some(name); this }
    public func onClick(h: ActionHandler): Button { this._onClick = Some(h); this }

    public func render(): IComponent {
        var cls = "el-button"
        let kc = this._kind.asClass()
        if (kc != "") { cls = "${cls} el-button--${kc}" }
        let sc = this._size.asClass()
        if (sc != "") { cls = "${cls} el-button--${sc}" }
        if (this._plain) { cls = "${cls} is-plain" }
        if (this._round) { cls = "${cls} is-round" }
        if (this._circle) { cls = "${cls} is-circle" }
        if (this._disabled || this._loading) { cls = "${cls} is-disabled" }
        if (this._loading) { cls = "${cls} is-loading" }
        if (this._text) { cls = "${cls} is-text" }
        if (this._link) { cls = "${cls} is-link" }
        if (this._bg) { cls = "${cls} has-bg" }

        let attrs = HashMap<String, String>()
        attrs["class"] = cls
        attrs["type"] = this._nativeType.asAttr()
        if (this._disabled || this._loading) { attrs["disabled"] = "disabled" }
        if (this._autofocus) { attrs["autofocus"] = "autofocus" }

        let inner = ArrayList<IComponent>()
        if (this._loading) {
            inner.add(Icon("loading").render())
        } else {
            match (this._iconName) {
                case Some(name) => inner.add(Icon(name).render())
                case None => ()
            }
        }
        for (c in this._children) { inner.add(c) }

        let btn = button(inner.toArray(), attrs: Some(attrs))
        match (this._onClick) {
            case Some(h) => if (!this._loading && !this._disabled) { btn.onClick(h) } else { btn }
            case None => btn
        }
    }
}

// 便捷函数
public func PrimaryButton(children: Array<IComponent>): Button { Button(children).kind(ButtonKind.Primary) }
public func DangerButton(children: Array<IComponent>): Button { Button(children).kind(ButtonKind.Danger) }
public func InfoButton(children: Array<IComponent>): Button { Button(children).kind(ButtonKind.Info) }
public func SuccessButton(children: Array<IComponent>): Button { Button(children).kind(ButtonKind.Success) }
public func WarningButton(children: Array<IComponent>): Button { Button(children).kind(ButtonKind.Warning) }
public func SmallButton(children: Array<IComponent>): Button { Button(children).size(ButtonSize.Small) }

public func PrimaryButton(label: String): Button { Button(label).kind(ButtonKind.Primary) }
public func DangerButton(label: String): Button { Button(label).kind(ButtonKind.Danger) }
public func InfoButton(label: String): Button { Button(label).kind(ButtonKind.Info) }
public func SuccessButton(label: String): Button { Button(label).kind(ButtonKind.Success) }
public func WarningButton(label: String): Button { Button(label).kind(ButtonKind.Warning) }
public func SmallButton(label: String): Button { Button(label).size(ButtonSize.Small) }

public class ButtonGroup <: Component {
    var _children: Array<IComponent>
    var _direction: SpaceDirection = SpaceDirection.Horizontal
    var _size: ButtonSize = ButtonSize.Default
    var _kind: ButtonKind = ButtonKind.Default

    public init(children: Array<IComponent>) { this._children = children }

    public func direction(v: SpaceDirection): ButtonGroup { this._direction = v; this }
    public func size(v: ButtonSize): ButtonGroup { this._size = v; this }
    public func kind(v: ButtonKind): ButtonGroup { this._kind = v; this }

    public func render(): IComponent {
        var cls = "el-button-group"
        match (this._direction) {
            case Vertical => cls = "${cls} el-button-group--vertical"
            case _ => cls = "${cls} el-button-group--horizontal"
        }
        let attrs = HashMap<String, String>([("class", cls)])
        let items = ArrayList<IComponent>()
        for (c in this._children) {
            items.add(this.applyGroupStyle(c))
        }
        VNode("div", items.toArray(), attrs: Some(attrs))
    }

    func applyGroupStyle(c: IComponent): IComponent {
        match (c) {
            case b: Button => this.applyButtonGroupStyle(b)
            case _ => c
        }
    }

    func applyButtonGroupStyle(b: Button): IComponent {
        match (this._size) {
            case Default => ()
            case _ => b.size(this._size)
        }
        match (this._kind) {
            case Default => ()
            case _ => b.kind(this._kind)
        }
        b.render()
    }
}
