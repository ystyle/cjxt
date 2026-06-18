package cjxt.components

import cjxt.*
import std.collection.HashMap

public class Button <: Component {
    var _label: String
    var _kind: ButtonKind = ButtonKind.Default
    var _size: ButtonSize = ButtonSize.Default
    var _plain: Bool = false
    var _round: Bool = false
    var _circle: Bool = false
    var _disabled: Bool = false
    var _loading: Bool = false
    var _onClick: Option<ActionHandler> = None

    public init(label: String) {
        this._label = label
    }

    public func kind(v: ButtonKind): Button { this._kind = v; this }
    public func size(v: ButtonSize): Button { this._size = v; this }
    public func plain(): Button { this._plain = true; this }
    public func round(): Button { this._round = true; this }
    public func circle(): Button { this._circle = true; this }
    public func disabled(): Button { this._disabled = true; this }
    public func loading(): Button { this._loading = true; this }
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
        if (this._disabled) { cls = "${cls} is-disabled" }
        if (this._loading) { cls = "${cls} is-loading" }

        let attrs = HashMap<String, String>()
        attrs["class"] = cls
        if (this._disabled) { attrs["disabled"] = "disabled" }
        let btn = button([text(this._label)], attrs: Some(attrs))
        match (this._onClick) {
            case Some(h) => btn.onClick(h)
            case None => btn
        }
    }
}

// 便捷函数
public func PrimaryButton(label: String): Button { Button(label).kind(ButtonKind.Primary) }
public func DangerButton(label: String): Button { Button(label).kind(ButtonKind.Danger) }
public func InfoButton(label: String): Button { Button(label).kind(ButtonKind.Info) }
public func SmallButton(label: String): Button { Button(label).size(ButtonSize.Small) }

public func TextButton(label: String): VNode {
    let attrs = HashMap<String, String>()
    attrs["class"] = "el-button is-text"
    button([text(label)], attrs: Some(attrs))
}

public func LinkButton(label: String): VNode {
    let attrs = HashMap<String, String>()
    attrs["class"] = "el-button is-link"
    button([text(label)], attrs: Some(attrs))
}
