package cjxt.components

import cjxt.*
import std.collection.HashMap
import stdx.encoding.json.stream.JsonWriter

public class ButtonBuilder <: Component {
    var _label: String
    var _kind: ButtonKind = ButtonKind.Default
    var _size: ButtonSize = ButtonSize.Default
    var _plain: Bool = false
    var _round: Bool = false
    var _circle: Bool = false
    var _disabled: Bool = false
    var _loading: Bool = false

    public init(label: String) {
        this._label = label
    }

    public func kind(v: ButtonKind): ButtonBuilder { this._kind = v; this }
    public func size(v: ButtonSize): ButtonBuilder { this._size = v; this }
    public func plain(): ButtonBuilder { this._plain = true; this }
    public func round(): ButtonBuilder { this._round = true; this }
    public func circle(): ButtonBuilder { this._circle = true; this }
    public func disabled(): ButtonBuilder { this._disabled = true; this }
    public func loading(): ButtonBuilder { this._loading = true; this }

    private func build(): VNode {
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
        button([text(this._label)], attrs: Some(attrs))
    }

    // ——— Component 接口实现 ———
    public func render(): Component { this.build() }
    public func toJson(w: JsonWriter): Unit { this.build().toJson(w) }
    public func collectHandlers(out: HashMap<String, ActionHandler>): Unit { this.build().collectHandlers(out) }
    public func onClick(h: ActionHandler): Component { this.build().onClick(h) }
}

public func Button(label: String): ButtonBuilder { ButtonBuilder(label) }

// 便捷函数（返回 Component，可直接链式 .onClick）
public func PrimaryButton(label: String): Component { Button(label).kind(ButtonKind.Primary) }
public func DangerButton(label: String): Component { Button(label).kind(ButtonKind.Danger) }
public func InfoButton(label: String): Component { Button(label).kind(ButtonKind.Info) }
public func SmallButton(label: String): Component { Button(label).size(ButtonSize.Small) }

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
