package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public enum AlertKind2 {
    | Success | Warning | Error | Info

    public func asClass(): String {
        match (this) {
            case Success => "success"
            case Warning => "warning"
            case Error => "error"
            case Info => "info"
        }
    }
}

public class Alert <: Component {
    var _title: String = ""
    var _description: String = ""
    var _kind: AlertKind2 = AlertKind2.Info
    var _closable: Bool = false
    var _showIcon: Bool = false
    var _center: Bool = false
    var _effect: String = "light"
    var _visible: Signal<Bool>
    var _children: Array<IComponent> = []

    public init() {
        this._visible = Signal<Bool>(true)
    }
    public func title(v: String): Alert { this._title = v; this }
    public func description(v: String): Alert { this._description = v; this }
    public func kind(v: AlertKind2): Alert { this._kind = v; this }
    public func closable(): Alert { this._closable = true; this }
    public func showIcon(): Alert { this._showIcon = true; this }
    public func center(): Alert { this._center = true; this }
    public func effect(v: String): Alert { this._effect = v; this }
    public func children(v: Array<IComponent>): Alert { this._children = v; this }

    public func render(): IComponent {
        if (!this._visible.get()) { return div([]) }
        var cls = "el-alert el-alert--${this._kind.asClass()} is-${this._effect}"
        if (this._center) { cls = "${cls} is-center" }
        let attrs = HashMap<String, String>([("class", cls), ("role", "alert")])

        let iconName = match (this._kind) {
            case Success => "success-filled"
            case Warning => "warning-filled"
            case Error => "error-filled"
            case Info => "info-filled"
        }

        let iconPart: Option<IComponent> = if (this._showIcon) {
            Some(VNode("span", [Icon(iconName).cls("is-big").render()], attrs: Some(HashMap<String, String>([("class", "el-alert__icon")]))))
        } else {
            None
        }

        let contentParts = ArrayList<IComponent>()
        if (this._title != "") {
            let titleCls = if (this._description != "") { "el-alert__title with-description" } else { "el-alert__title" }
            contentParts.add(VNode("span", [text(this._title)], attrs: Some(HashMap<String, String>([("class", titleCls)]))))
        }
        if (this._description != "") {
            contentParts.add(VNode("p", [text(this._description)], attrs: Some(HashMap<String, String>([("class", "el-alert__description")]))))
        }
        if (this._closable) {
            let closeIcon = Icon("close").render()
            let closeBtn = VNode("span", [closeIcon], attrs: Some(HashMap<String, String>([("class", "el-alert__close-btn")])))
            let v = this._visible
            contentParts.add(VNode("span", [closeBtn.onClick({ ctx =>
                v.set(false)
                PatchResult.ReRender
            })]))
        }

        let childrenParts = ArrayList<IComponent>()
        childrenParts.add(VNode("div", contentParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-alert__content")]))))
        for (c in this._children) { childrenParts.add(c) }

        let rootChildren = ArrayList<IComponent>()
        match (iconPart) {
            case Some(ip) => rootChildren.add(ip)
            case None => ()
        }
        for (c in childrenParts.toArray()) { rootChildren.add(c) }
        VNode("div", rootChildren.toArray(), attrs: Some(attrs))
    }
}
