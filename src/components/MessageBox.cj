package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// EP MessageBox（index.vue）DOM：
//   div.el-overlay.is-message-box               ← fixed 遮罩（is-message-box 触发居中布局）
//     div.el-overlay-message-box [role=dialog]
//       div.el-message-box [tabindex=-1] [is-center]
//         div.el-message-box__header[.show-close]
//           div.el-message-box__title > [el-icon.__status 当 center] span
//           button.el-message-box__headerbtn > i.el-icon.el-message-box__close
//         div.el-message-box__content
//           div.el-message-box__container
//             i.el-icon.el-message-box__status.el-message-box-icon--{type}   （非 center；颜色 per type CSS var）
//             div.el-message-box__message > p
//           div.el-message-box__input（Prompt 专属）> div.el-input > wrapper > input
//         div.el-message-box__btns > button(取消) + button.el-button--primary(确定)
// Prompt 输入值：输入框 bind 外部 Signal<String>（MessageBox.value）；回车确认时 ctx.params["value"] 亦可取
public enum MessageBoxKind2 {
    | Alert | Confirm | Prompt
}

public enum MessageBoxIcon2 {
    | None | Success | Warning | Error | Info
}

public class MessageBox <: Component {
    var _visible: Signal<Bool>
    var _kind: MessageBoxKind2 = MessageBoxKind2.Alert
    var _icon: Option<MessageBoxIcon2> = Option<MessageBoxIcon2>.None
    var _title: String = ""
    var _message: String = ""
    var _confirmText: String = "确定"
    var _cancelText: String = "取消"
    var _showClose: Bool = true
    var _closeOnClickModal: Bool = true
    var _center: Bool = false
    var _placeholder: String = ""
    var _valueS: Option<Signal<String>> = None
    var _confirmH: Option<ActionHandler> = None
    var _cancelH: Option<ActionHandler> = None

    public init(visible: Signal<Bool>) {
        this._visible = visible
    }
    public func kind(k: MessageBoxKind2): MessageBox { this._kind = k; this }
    public func icon(i: MessageBoxIcon2): MessageBox { this._icon = Some(i); this }
    public func title(v: String): MessageBox { this._title = v; this }
    public func message(v: String): MessageBox { this._message = v; this }
    public func confirmText(v: String): MessageBox { this._confirmText = v; this }
    public func cancelText(v: String): MessageBox { this._cancelText = v; this }
    public func showClose(v: Bool): MessageBox { this._showClose = v; this }
    public func closeOnClickModal(v: Bool): MessageBox { this._closeOnClickModal = v; this }
    public func center(): MessageBox { this._center = true; this }
    public func placeholder(v: String): MessageBox { this._placeholder = v; this }
    public func value(s: Signal<String>): MessageBox { this._valueS = Some(s); this }
    public func onConfirm(h: ActionHandler): MessageBox { this._confirmH = Some(h); this }
    public func onCancel(h: ActionHandler): MessageBox { this._cancelH = Some(h); this }

    // 当前展示图标：显式 icon 优先，否则依 kind（Alert 无 / Confirm Warning / Prompt 无）
    func effectiveIcon(): MessageBoxIcon2 {
        match (this._icon) {
            case Some(i) => i
            case None => match (this._kind) {
                case MessageBoxKind2.Confirm => MessageBoxIcon2.Warning
                case MessageBoxKind2.Alert => MessageBoxIcon2.None
                case MessageBoxKind2.Prompt => MessageBoxIcon2.None
            }
        }
    }

    // Prompt 输入框回车确认（其它按键照常输入）
    func enterAction(): ActionHandler {
        let s = this._visible
        let h = this._confirmH
        let base = this
        let handler: ActionHandler = { ctx =>
            match (ctx.keyEvent) {
                case Some(ke) => if (ke.isEnter()) {
                    s.set(false)
                    base.runCb(h, ctx)
                } else {
                    ()
                }
                case None => ()
            }
            PatchResult.ReRender
        }
        handler
    }

    func hideAction(): ActionHandler {
        let s = this._visible
        let handler: ActionHandler = { ctx => s.set(false); PatchResult.ReRender }
        handler
    }

    func confirmAction(): ActionHandler {
        let s = this._visible
        let h = this._confirmH
        let base = this
        let handler: ActionHandler = { ctx =>
            s.set(false)
            base.runCb(h, ctx)
            PatchResult.ReRender
        }
        handler
    }

    func cancelAction(): ActionHandler {
        let s = this._visible
        let h = this._cancelH
        let base = this
        let handler: ActionHandler = { ctx =>
            s.set(false)
            base.runCb(h, ctx)
            PatchResult.ReRender
        }
        handler
    }

    private func runCb(h: Option<ActionHandler>, ctx: ActionContext): Unit {
        match (h) {
            case Some(hh) => runHandler(hh, ctx)
            case None => ()
        }
    }
    private func runHandler(hh: ActionHandler, ctx: ActionContext): Unit {
        let _ = hh(ctx)
    }

    // EP：i.el-icon.el-message-box__status.el-message-box-icon--{type}
    func iconEl(t: MessageBoxIcon2): IComponent {
        let name = match (t) {
            case MessageBoxIcon2.Success => "success-filled"
            case MessageBoxIcon2.Warning => "warning-filled"
            case MessageBoxIcon2.Error => "error-filled"
            case MessageBoxIcon2.Info => "info-filled"
            case MessageBoxIcon2.None => ""
        }
        let typeCls = match (t) {
            case MessageBoxIcon2.Success => "el-message-box-icon--success"
            case MessageBoxIcon2.Warning => "el-message-box-icon--warning"
            case MessageBoxIcon2.Error => "el-message-box-icon--error"
            case MessageBoxIcon2.Info => "el-message-box-icon--info"
            case MessageBoxIcon2.None => ""
        }
        Icon(name).cls("el-message-box__status ${typeCls}").size("24px")
    }

    public func render(): IComponent {
        if (!this._visible.get()) { return EmptyVNode() }
        let ic = this.effectiveIcon()
        let showIcon = match (ic) { case MessageBoxIcon2.None => false; case _ => true }
        let isConfirm = match (this._kind) { case MessageBoxKind2.Confirm => true; case MessageBoxKind2.Prompt => true; case _ => false }
        let isPrompt = match (this._kind) { case MessageBoxKind2.Prompt => true; case _ => false }

        // ===== header =====
        let headParts = ArrayList<IComponent>()
        let titleParts = ArrayList<IComponent>()
        if (this._center && showIcon) { titleParts.add(this.iconEl(ic)) }
        titleParts.add(VNode("span", [text(this._title)]))
        headParts.add(VNode("div", titleParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-message-box__title")]))))
        if (this._showClose) {
            let closeIcon = VNode("i", [], attrs: Some(HashMap<String, String>([("class", "el-icon el-message-box__close")])))
            let btnAttrs = HashMap<String, String>([("class", "el-message-box__headerbtn"), ("type", "button"), ("aria-label", "close")])
            var closeBtn = VNode("button", [closeIcon], attrs: Some(btnAttrs))
            closeBtn = closeBtn.onClick(this.hideAction())
            headParts.add(closeBtn)
        }
        var headerCls = "el-message-box__header"
        if (this._showClose) { headerCls = "${headerCls} show-close" }

        // ===== content =====
        let containerParts = ArrayList<IComponent>()
        if (!this._center && showIcon) { containerParts.add(this.iconEl(ic)) }
        if (this._message != "") {
            containerParts.add(VNode("div", [VNode("p", [text(this._message)])], attrs: Some(HashMap<String, String>([("class", "el-message-box__message")]))))
        }
        let contentParts = ArrayList<IComponent>()
        contentParts.add(VNode("div", containerParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-message-box__container")]))))
        if (isPrompt) {
            let inputC = Input().placeholder(this._placeholder).onKeydown(this.enterAction())
            let inputC2 = match (this._valueS) {
                case Some(s) => inputC.bind(s)
                case None => inputC
            }
            contentParts.add(VNode("div", [inputC2], attrs: Some(HashMap<String, String>([("class", "el-message-box__input")]))))
        }
        contentParts.add(VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-message-box__errormsg")]))))

        // ===== buttons（Alert 只有确定 / Confirm·Prompt 取消+确定） =====
        let btnParts = ArrayList<IComponent>()
        if (isConfirm) {
            let cancelAttrs = HashMap<String, String>([("class", "el-button"), ("type", "button")])
            var cancelBtn = VNode("button", [VNode("span", [text(this._cancelText)])], attrs: Some(cancelAttrs))
            cancelBtn = cancelBtn.onClick(this.cancelAction())
            btnParts.add(cancelBtn)
        }
        let confirmAttrs = HashMap<String, String>([("class", "el-button el-button--primary"), ("type", "button")])
        var confirmBtn = VNode("button", [VNode("span", [text(this._confirmText)])], attrs: Some(confirmAttrs))
        confirmBtn = confirmBtn.onClick(this.confirmAction())
        btnParts.add(confirmBtn)

        // ===== assemble =====
        let boxParts = ArrayList<IComponent>()
        boxParts.add(VNode("div", headParts.toArray(), attrs: Some(HashMap<String, String>([("class", headerCls)]))))
        boxParts.add(VNode("div", contentParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-message-box__content")]))))
        boxParts.add(VNode("div", btnParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-message-box__btns")]))))

        var boxCls = "el-message-box"
        if (this._center) { boxCls = "${boxCls} is-center" }
        let boxAttrs = HashMap<String, String>([("class", boxCls), ("role", "dialog"), ("tabindex", "-1")])
        var box = VNode("div", boxParts.toArray(), attrs: Some(boxAttrs))
        // 截断：点击弹窗内部时委托命中自身 noop，避免冒泡到 overlay 的关闭 action
        let noop: ActionHandler = { ctx => PatchResult.ReRender }
        box = box.on("click", noop)

        // overlay（is-message-box 触发 .el-overlay-message-box 居中布局）；点击遮罩空白关闭
        let overlayAttrs = HashMap<String, String>([("class", "el-overlay is-message-box")])
        var overlay = VNode("div", [
            VNode("div", [box], attrs: Some(HashMap<String, String>([("class", "el-overlay-message-box")]))),
        ], attrs: Some(overlayAttrs))
        if (this._closeOnClickModal) {
            overlay = overlay.onClick(this.hideAction())
        }
        overlay
    }
}
