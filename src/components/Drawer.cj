package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public enum DrawerDirection {
    LTR | RTL | TTB | BTT

    public func toClass(): String {
        match (this) {
            case LTR => "ltr"
            case RTL => "rtl"
            case TTB => "ttb"
            case BTT => "btt"
        }
    }

    public func isHorizontal(): Bool {
        match (this) {
            case LTR => true
            case RTL => true
            case TTB => false
            case BTT => false
        }
    }
}

public class Drawer <: Component {
    var _children: Array<IComponent> = []
    var _visible: Signal<Bool>
    var _title: String = ""
    var _direction: DrawerDirection = DrawerDirection.RTL
    var _size: String = "30%"
    var _showClose: Bool = true
    var _closeOnClickModal: Bool = true
    var _closeOnPressEscape: Bool = true
    var _modal: Bool = true
    var _withHeader: Bool = true
    var _destroyOnClose: Bool = false
    var _beforeClose: Option<ActionHandler> = None
    var _headerContent: Array<IComponent> = []
    var _footerContent: Array<IComponent> = []

    public init(children: Array<IComponent>) {
        this._children = children
        this._visible = Signal<Bool>(false)
    }

    public func visible(signal: Signal<Bool>): Drawer { this._visible = signal; this }
    public func title(v: String): Drawer { this._title = v; this }
    public func direction(v: DrawerDirection): Drawer { this._direction = v; this }
    public func size(v: String): Drawer { this._size = v; this }
    public func showClose(v: Bool): Drawer { this._showClose = v; this }
    public func closeOnClickModal(v: Bool): Drawer { this._closeOnClickModal = v; this }
    public func closeOnPressEscape(v: Bool): Drawer { this._closeOnPressEscape = v; this }
    public func modal(v: Bool): Drawer { this._modal = v; this }
    public func withHeader(v: Bool): Drawer { this._withHeader = v; this }
    public func destroyOnClose(): Drawer { this._destroyOnClose = true; this }
    public func beforeClose(h: ActionHandler): Drawer { this._beforeClose = Some(h); this }
    public func header(v: Array<IComponent>): Drawer { this._headerContent = v; this }
    public func footer(v: Array<IComponent>): Drawer { this._footerContent = v; this }

    private func closeAction(): ActionHandler {
        let s = this._visible
        let bc = this._beforeClose
        let handler: ActionHandler = { ctx =>
            match (bc) {
                case Some(fn) => fn(ctx)
                case None => s.set(false)
            }
            PatchResult.ReRender
        }
        handler
    }

    public func render(): IComponent {
        if (!this._visible.get()) { return Empty() }

        let dirClass = this._direction.toClass()
        let isHorizontal = this._direction.isHorizontal()
        let drawerCls = "el-drawer ${dirClass}"
        let drawerStyle = "--el-drawer-size: ${this._size}"
        let drawerAttrs = HashMap<String, String>([("class", drawerCls), ("role", "dialog"), ("style", drawerStyle)])

        let headerParts = ArrayList<IComponent>()
        if (this._withHeader) {
            if (this._headerContent.size > 0) {
                for (c in this._headerContent) { headerParts.add(c) }
            } else if (this._title != "") {
                headerParts.add(VNode("span", [text(this._title)], attrs: Some(HashMap<String, String>([("class", "el-drawer__title")]))))
            }
            if (this._showClose) {
                let closeIcon = VNode("i", [], attrs: Some(HashMap<String, String>([("class", "el-icon el-drawer__close")])))
                let btnAttrs = HashMap<String, String>([("class", "el-drawer__close-btn"), ("type", "button")])
                var closeBtn = VNode("button", [closeIcon], attrs: Some(btnAttrs))
                closeBtn = closeBtn.onClick(this.closeAction())
                headerParts.add(closeBtn)
            }
        }

        let drawerParts = ArrayList<IComponent>()
        if (this._withHeader && headerParts.size > 0) {
            drawerParts.add(VNode("div", headerParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-drawer__header")]))))
        }
        drawerParts.add(VNode("div", this._children, attrs: Some(HashMap<String, String>([("class", "el-drawer__body")]))))
        if (this._footerContent.size > 0) {
            drawerParts.add(VNode("div", this._footerContent, attrs: Some(HashMap<String, String>([("class", "el-drawer__footer")]))))
        }

        let drawer = VNode("div", drawerParts.toArray(), attrs: Some(drawerAttrs))

        let content = ArrayList<IComponent>()

        if (this._modal && this._closeOnClickModal) {
            let overlayAttrs = HashMap<String, String>([("class", "el-overlay")])
            content.add(div([], attrs: Some(overlayAttrs)).onClick(this.closeAction()))
        } else if (this._modal) {
            content.add(VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-overlay")]))))
        }

        let drawerWrapper = VNode("div", [drawer], attrs: Some(HashMap<String, String>([
            ("class", "el-overlay-dialog"),
            ("style", "position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 2001; overflow: auto;")
        ])))
        content.add(drawerWrapper)

        VNode("div", content.toArray(), attrs: Some(HashMap<String, String>([("class", "el-overlay-root")])))
    }
}
