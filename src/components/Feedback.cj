package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}
import std.convert.*

// ============ 反馈体系：Message / Notification / Loading / Skeleton（对齐 Element Plus） ============

// ── Message 轻提示 ──

public struct MessageItem {
    public let id: Int64
    public let kind: String   // success | warning | error | info
    public let text: String

    public init(id: Int64, kind: String, text: String) {
        this.id = id
        this.kind = kind
        this.text = text
    }
}

func removeMessageById(list: ArrayList<MessageItem>, id: Int64): Unit {
    var i = 0
    while (i < list.size) {
        if (list[i].id == id) { list.remove(i..i + 1) } else { i += 1 }
    }
}

func messageIcon(kind: String): String {
    match (kind) {
        case "success" => "circle-check"
        case "warning" => "warning-filled"
        case "error" => "circle-close"
        case _ => "info-filled"
    }
}

// 消息队列辅助：服务端 handler 里直接 messages.success("保存成功")
public class MessageQueue {
    let signal: Signal<ArrayList<MessageItem>>

    public init(signal: Signal<ArrayList<MessageItem>>) {
        this.signal = signal
    }

    public func success(text: String): Unit { this.push("success", text) }
    public func warning(text: String): Unit { this.push("warning", text) }
    public func error(text: String): Unit { this.push("error", text) }
    public func info(text: String): Unit { this.push("info", text) }

    func push(kind: String, text: String): Unit {
        let id = nextToastId()
        let sig = this.signal
        sig.update({ list => toastPush(list, MessageItem(id, kind, text)) })
    }
}

// 消息渲染容器：绑定队列信号，每条渲染为 .el-message，点任意处关闭 + 3s 自动消失
public class MessageHost <: Component {
    var _signal: Option<Signal<ArrayList<MessageItem>>> = None

    public func bind(signal: Signal<ArrayList<MessageItem>>): MessageHost {
        this._signal = Some(signal)
        this
    }

    public func render(): IComponent {
        // 容器始终渲染（空容器无碍），避免 EmptyVNode 导致 DOM 槽位与树路径错位
        let items = match (this._signal) { case Some(s) => s.get(); case None => ArrayList<MessageItem>() }
        let children = ArrayList<IComponent>()
        for (item in items) {
            children.add(this.buildMessage(item))
        }
        // 容器避让顶部导航栏(top 70)；width:max-content + max-width 防 100% 循环压窄换行
        div(children.toArray(), attrs: Some(HashMap<String, String>([("class", "el-message__container"), ("style", "position:fixed;top:70px;left:50%;transform:translateX(-50%);z-index:3000;display:flex;flex-direction:column;align-items:center;gap:12px;width:max-content;max-width:90vw")])))
    }

    private func buildMessage(item: MessageItem): IComponent {
        let typeCls = "el-message--${item.kind}"
        let iconEl = VNode("span", [Icon(messageIcon(item.kind)).render()], attrs: Some(HashMap<String, String>([("class", "el-message__icon ${typeCls}")])))
        let content = VNode("p", [text(item.text)], attrs: Some(HashMap<String, String>([("class", "el-message__content"), ("style", "white-space:nowrap")])))
        let closeBtn = VNode("span", [Icon("close").render()], attrs: Some(HashMap<String, String>([("class", "el-message__closeBtn")])))
        let attrs = HashMap<String, String>([("class", "el-message ${typeCls}"), ("role", "alert"), ("data-auto-dismiss", "3000"), ("data-id", item.id.toString())])
        // EP scss 的 .el-message 本身 position:fixed（官方挂 body）——
        // 我们的架构是 host 容器 fixed + items 进流，用 relative 覆盖（同 Notification）
        attrs["style"] = "position:relative"
        var el = VNode("div", [iconEl, content, closeBtn], attrs: Some(attrs))
        el = el.onClick({ ctx => this.dismiss(ctx) })
        el
    }

    private func dismiss(ctx: ActionContext): PatchResult {
        let id = match (ctx.params.get("id")) {
            case Some(v) => try { Int64.parse(v) } catch (_) { -1 }
            case None => -1
        }
        match (this._signal) {
            case Some(sig) => if (id >= 0) {
                sig.update({ list => let c = ArrayList<MessageItem>(list); removeMessageById(c, id); c })
            }
            case None => ()
        }
        PatchResult.ReRender
    }
}

// ── Notification 通知 ──

public struct NotificationItem {
    public let id: Int64
    public let kind: String
    public let title: String
    public let text: String

    public init(id: Int64, kind: String, title: String, text: String) {
        this.id = id
        this.kind = kind
        this.title = title
        this.text = text
    }
}

func removeNotificationById(list: ArrayList<NotificationItem>, id: Int64): Unit {
    var i = 0
    while (i < list.size) {
        if (list[i].id == id) { list.remove(i..i + 1) } else { i += 1 }
    }
}

public class NotificationQueue {
    let signal: Signal<ArrayList<NotificationItem>>

    public init(signal: Signal<ArrayList<NotificationItem>>) {
        this.signal = signal
    }

    public func success(title: String, text: String): Unit { this.push("success", title, text) }
    public func warning(title: String, text: String): Unit { this.push("warning", title, text) }
    public func error(title: String, text: String): Unit { this.push("error", title, text) }
    public func info(title: String, text: String): Unit { this.push("info", title, text) }

    func push(kind: String, title: String, text: String): Unit {
        let id = nextToastId()
        let sig = this.signal
        sig.update({ list => toastPush(list, NotificationItem(id, kind, title, text)) })
    }
}

public class NotificationHost <: Component {
    var _signal: Option<Signal<ArrayList<NotificationItem>>> = None

    public func bind(signal: Signal<ArrayList<NotificationItem>>): NotificationHost {
        this._signal = Some(signal)
        this
    }

    public func render(): IComponent {
        // 容器始终渲染，避免 DOM 槽位与树路径错位
        let items = match (this._signal) { case Some(s) => s.get(); case None => ArrayList<NotificationItem>() }
        let children = ArrayList<IComponent>()
        for (item in items) {
            children.add(this.buildNotification(item))
        }
        div(children.toArray(), attrs: Some(HashMap<String, String>([("class", "el-notification__container"), ("style", "position:fixed;top:70px;right:16px;z-index:3000;display:flex;flex-direction:column;gap:12px;width:330px")])))
    }

    private func buildNotification(item: NotificationItem): IComponent {
        let typeCls = "el-notification--${item.kind}"
        let iconEl = VNode("span", [Icon(messageIcon(item.kind)).render()], attrs: Some(HashMap<String, String>([("class", "el-notification__icon ${typeCls}")])))
        let titleEl = VNode("h2", [text(item.title)], attrs: Some(HashMap<String, String>([("class", "el-notification__title")])))
        let contentEl = VNode("div", [text(item.text)], attrs: Some(HashMap<String, String>([("class", "el-notification__content")])))
        let closeBtn = VNode("span", [Icon("close").render()], attrs: Some(HashMap<String, String>([("class", "el-notification__closeBtn")])))
        let group = VNode("div", [titleEl, contentEl], attrs: Some(HashMap<String, String>([("class", "el-notification__group")])))
        let attrs = HashMap<String, String>([("class", "el-notification ${typeCls}"), ("data-auto-dismiss", "4500"), ("data-id", item.id.toString())])
        // EP scss 的 .el-notification 本身 position:fixed（官方挂 body）——
        // 我们的架构是 host 容器 fixed + items 进流，这里用 relative 覆盖，否则
        // 双 fixed + 零宽容器会把通知推到视口外（x≈1264 不可见）
        attrs["style"] = "position:relative"
        var el = VNode("div", [iconEl, group, closeBtn], attrs: Some(attrs))
        el = el.onClick({ ctx => this.dismiss(ctx) })
        el
    }

    private func dismiss(ctx: ActionContext): PatchResult {
        let id = match (ctx.params.get("id")) {
            case Some(v) => try { Int64.parse(v) } catch (_) { -1 }
            case None => -1
        }
        match (this._signal) {
            case Some(sig) => if (id >= 0) {
                sig.update({ list => let c = ArrayList<NotificationItem>(list); removeNotificationById(c, id); c })
            }
            case None => ()
        }
        PatchResult.ReRender
    }
}

// ── Loading 加载遮罩 ──

public class Loading <: Component {
    var _visibleSignal: Option<Signal<Bool>> = None
    var _text: String = "加载中..."
    var _fullscreen: Bool = false

    public func bind(signal: Signal<Bool>): Loading { this._visibleSignal = Some(signal); this }
    // 注意：方法名不能叫 text——会遮蔽顶层 text():TextNode 函数（Loading.render 里 text(...) 会解析到方法→返回 this→无限递归 OOM）
    public func label(v: String): Loading { this._text = v; this }
    public func fullscreen(): Loading { this._fullscreen = true; this }

    public func render(): IComponent {
        // mask 始终渲染（隐藏时 display:none），避免 EmptyVNode 导致 DOM 槽位与树路径错位
        let visible = match (this._visibleSignal) { case Some(s) => s.get(); case None => false }
        let hideStyle = if (visible) { "" } else { "display:none" }
        var cls = "el-loading-mask"
        if (this._fullscreen) { cls = "${cls} is-fullscreen" }
        let circle = VNode("circle", [], attrs: Some(HashMap<String, String>([("class", "path"), ("cx", "25"), ("cy", "25"), ("r", "20"), ("fill", "none")])))
        let svg = VNode("svg", [circle], attrs: Some(HashMap<String, String>([("class", "circular"), ("viewBox", "0 0 50 50")])))
        let spinnerChildren = ArrayList<IComponent>()
        spinnerChildren.add(svg)
        if (this._text != "") { spinnerChildren.add(VNode("p", [text(this._text)], attrs: Some(HashMap<String, String>([("class", "el-loading__text")])))) }
        let spinner = VNode("div", spinnerChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-loading-spinner")])))
        VNode("div", [spinner], attrs: Some(HashMap<String, String>([("class", cls), ("style", hideStyle)])))
    }
}

// ── Skeleton 骨架屏 ──

public class Skeleton <: Component {
    var _rows: Int64 = 3
    var _animated: Bool = true

    public func rows(v: Int64): Skeleton { this._rows = v; this }
    public func animated(): Skeleton { this._animated = true; this }
    public func noAnimated(): Skeleton { this._animated = false; this }

    public func render(): IComponent {
        var cls = "el-skeleton"
        if (this._animated) { cls = "${cls} el-skeleton--animated" }
        let items = ArrayList<IComponent>()
        items.add(VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-skeleton__item el-skeleton__p is-first")]))))
        var i: Int64 = 0
        while (i < this._rows) {
            let last = i == this._rows - 1
            let itCls = if (last && this._rows > 1) { "el-skeleton__item el-skeleton__p el-skeleton__paragraph is-last" } else { "el-skeleton__item el-skeleton__p el-skeleton__paragraph" }
            items.add(VNode("div", [], attrs: Some(HashMap<String, String>([("class", itCls)]))))
            i += 1
        }
        VNode("div", items.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
    }
}
