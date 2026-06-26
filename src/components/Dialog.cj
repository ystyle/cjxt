package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Dialog <: Component {
    var _children: Array<IComponent> = []
    var _visible: Signal<Bool>
    var _title: String = ""
    var _width: String = "50%"
    var _top: String = "15vh"
    var _showClose: Bool = true
    var _closeOnClickModal: Bool = true
    var _closeOnPressEscape: Bool = true
    var _modal: Bool = true
    var _center: Bool = false
    var _alignCenter: Bool = false
    var _fullscreen: Bool = false
    var _destroyOnClose: Bool = false
    var _beforeClose: Option<ActionHandler> = None
    var _headerContent: Array<IComponent> = []
    var _footerContent: Array<IComponent> = []

    public init(children: Array<IComponent>) {
        this._children = children
        this._visible = Signal<Bool>(false)
    }

    public func visible(signal: Signal<Bool>): Dialog { this._visible = signal; this }
    public func title(v: String): Dialog { this._title = v; this }
    public func width(v: String): Dialog { this._width = v; this }
    public func top(v: String): Dialog { this._top = v; this }
    public func showClose(v: Bool): Dialog { this._showClose = v; this }
    public func closeOnClickModal(v: Bool): Dialog { this._closeOnClickModal = v; this }
    public func closeOnPressEscape(v: Bool): Dialog { this._closeOnPressEscape = v; this }
    public func modal(v: Bool): Dialog { this._modal = v; this }
    public func center(): Dialog { this._center = true; this }
    public func alignCenter(): Dialog { this._alignCenter = true; this }
    public func fullscreen(): Dialog { this._fullscreen = true; this }
    public func destroyOnClose(): Dialog { this._destroyOnClose = true; this }
    public func beforeClose(h: ActionHandler): Dialog { this._beforeClose = Some(h); this }
    public func header(v: Array<IComponent>): Dialog { this._headerContent = v; this }
    public func footer(v: Array<IComponent>): Dialog { this._footerContent = v; this }

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

        var dialogCls = "el-dialog"
        if (this._center) { dialogCls = "${dialogCls} is-center" }
        if (this._alignCenter) { dialogCls = "${dialogCls} is-align-center" }
        if (this._fullscreen) { dialogCls = "${dialogCls} is-fullscreen" }
        if (!this._modal) { dialogCls = "${dialogCls} is-modal" }

        let dialogStyle = if (this._fullscreen) { "" } else {
            "--el-dialog-width: ${this._width}; --el-dialog-margin-top: ${this._top}"
        }
        let dialogAttrs = HashMap<String, String>([("class", dialogCls), ("role", "dialog")])
        if (dialogStyle != "") { dialogAttrs.add("style", dialogStyle) }

        // 构建 header
        let headerParts = ArrayList<IComponent>()
        if (this._headerContent.size > 0) {
            for (c in this._headerContent) { headerParts.add(c) }
        } else if (this._title != "") {
            headerParts.add(VNode("span", [text(this._title)], attrs: Some(HashMap<String, String>([("class", "el-dialog__title")]))))
        }
        if (this._showClose) {
            let closeIcon = VNode("i", [], attrs: Some(HashMap<String, String>([("class", "el-icon el-dialog__close")])))
            let btnAttrs = HashMap<String, String>([("class", "el-dialog__headerbtn"), ("type", "button")])
            var closeBtn = VNode("button", [closeIcon], attrs: Some(btnAttrs))
            closeBtn = closeBtn.onClick(this.closeAction())
            headerParts.add(closeBtn)
        }

        // 构建 dialog 内容
        let dialogParts = ArrayList<IComponent>()
        if (headerParts.size > 0) {
            dialogParts.add(VNode("div", headerParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-dialog__header")]))))
        }
        dialogParts.add(VNode("div", this._children, attrs: Some(HashMap<String, String>([("class", "el-dialog__body")]))))
        if (this._footerContent.size > 0) {
            dialogParts.add(VNode("div", this._footerContent, attrs: Some(HashMap<String, String>([("class", "el-dialog__footer")]))))
        }

        let dialog = VNode("div", dialogParts.toArray(), attrs: Some(dialogAttrs))

        // overlay（遮罩层）和 dialog 是兄弟节点，解决点击事件冒泡问题
        let overlayCls = if (this._modal) { "el-overlay" } else { "" }
        let content = ArrayList<IComponent>()

        if (this._modal && this._closeOnClickModal) {
            let overlayAttrs = HashMap<String, String>([("class", "el-overlay")])
            content.add(div([], attrs: Some(overlayAttrs)).onClick(this.closeAction()))
        } else if (this._modal) {
            content.add(VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-overlay")]))))
        }

        // dialog 在遮罩层上方（使用 el-overlay-dialog 滚动容器，避免 flex stretch 导致弹窗被拉长）
        let dialogWrapper = VNode("div", [dialog], attrs: Some(HashMap<String, String>([
            ("class", "el-overlay-dialog"),
            ("style", "position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 2001; overflow: auto;")
        ])))
        content.add(dialogWrapper)

        VNode("div", content.toArray(), attrs: Some(HashMap<String, String>([("class", "el-overlay-root")])))
    }
}
