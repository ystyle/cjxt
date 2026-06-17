package cjxt.components

import cjxt.*
import std.collection.HashMap

public class ElButton {
    var label: String
    var _kind: String = ""
    var _size: String = ""
    var _plain: Bool = false
    var _round: Bool = false
    var _circle: Bool = false
    var _disabled: Bool = false
    var _loading: Bool = false

    public init(label: String) {
        this.label = label
    }

    public func kind(v: String): ElButton { this._kind = v; this }
    public func size(v: String): ElButton { this._size = v; this }
    public func plain(): ElButton { this._plain = true; this }
    public func round(): ElButton { this._round = true; this }
    public func circle(): ElButton { this._circle = true; this }
    public func disabled(): ElButton { this._disabled = true; this }
    public func loading(): ElButton { this._loading = true; this }

    public func render(): ComponentNode {
        var cls = "el-button"
        if (this._kind != "") { cls = "${cls} el-button--${this._kind}" }
        if (this._size != "") { cls = "${cls} el-button--${this._size}" }
        if (this._plain) { cls = "${cls} is-plain" }
        if (this._round) { cls = "${cls} is-round" }
        if (this._circle) { cls = "${cls} is-circle" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        if (this._loading) { cls = "${cls} is-loading" }

        let attrs = HashMap<String, String>()
        attrs["class"] = cls
        if (this._disabled) { attrs["disabled"] = "disabled" }
        button([text(this.label)], attrs: Some(attrs))
    }

    public func onClick(h: ActionHandler): ComponentNode {
        this.render().onClick(h)
    }
}

public func PrimaryButton(label: String): ComponentNode {
    ElButton(label).kind("primary").render()
}

public func DangerButton(label: String): ComponentNode {
    ElButton(label).kind("danger").render()
}

public func SmallButton(label: String): ComponentNode {
    ElButton(label).size("small").render()
}

public func TextButton(label: String): ComponentNode {
    let attrs = HashMap<String, String>()
    attrs["class"] = "el-button is-text"
    button([text(label)], attrs: Some(attrs))
}

public func LinkButton(label: String): ComponentNode {
    let attrs = HashMap<String, String>()
    attrs["class"] = "el-button is-link"
    button([text(label)], attrs: Some(attrs))
}
