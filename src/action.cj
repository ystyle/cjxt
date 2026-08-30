package cjxt

import std.collection.{HashMap, ArrayList}
import std.convert.*
import std.reflect.*
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}
import stdx.net.http.WebSocket

public interface AppState {}

// 按键事件信息：由前端 keydown/keyup 委托捕获，随 action 消息回传服务端
public struct KeyEvent {
    public let key: String
    public let code: String
    public let keyCode: Int64
    public let ctrl: Bool
    public let shift: Bool
    public let alt: Bool
    public let meta: Bool

    public init(key: String, code: String, keyCode: Int64, ctrl: Bool, shift: Bool, alt: Bool, meta: Bool) {
        this.key = key
        this.code = code
        this.keyCode = keyCode
        this.ctrl = ctrl
        this.shift = shift
        this.alt = alt
        this.meta = meta
    }

    public func isEnter(): Bool { this.key == "Enter" || this.code == "Enter" }
    public func isEscape(): Bool { this.key == "Escape" || this.code == "Escape" }
    public func isTab(): Bool { this.key == "Tab" || this.code == "Tab" }
    public func isCtrlEnter(): Bool { this.ctrl && this.isEnter() }
}

// 从 action 的 params（前端回传的按键字段）解析 KeyEvent
// params 里没有 key 字段（普通点击/非按键 action）时返回 None
public func parseKeyEvent(params: HashMap<String, String>): Option<KeyEvent> {
    match (params.get("key")) {
        case Some(k) =>
            let code = match (params.get("code")) { case Some(c) => c case None => "" }
            let keyCode = match (params.get("keyCode")) {
                case Some(kc) => try { Int64.parse(kc) } catch (_) { 0 }
                case None => 0
            }
            let ctrl = match (params.get("ctrl")) { case Some(v) => v == "1" case None => false }
            let shift = match (params.get("shift")) { case Some(v) => v == "1" case None => false }
            let alt = match (params.get("alt")) { case Some(v) => v == "1" case None => false }
            let meta = match (params.get("meta")) { case Some(v) => v == "1" case None => false }
            Some(KeyEvent(k, code, keyCode, ctrl, shift, alt, meta))
        case None => None
    }
}

func doGetState<T>(s: AppState): T where T <: AppState {
    match (s) {
        case t: T => t
        case _ => throw Exception("type mismatch for AppState")
    }
}

public enum PatchResult {
    | ReRender
    | Patch(Array<PatchEntry>)
}

public struct PatchEntry {
    let op: String
    let path: String
    let value: Option<String>
    let from: Option<String>

    public init(op: String, path: String, value: Option<String>, from: Option<String>) {
        this.op = op
        this.path = path
        this.value = value
        this.from = from
    }
}

// 颗粒 patch

public struct TreePatchEntry <: JsonSerializable {
    let op: String
    let path: String
    let tree: Option<IComponent>

    public init(op: String, path: String, tree: Option<IComponent>) {
        this.op = op
        this.path = path
        this.tree = tree
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("op").writeValue(this.op)
        w.writeName("path").writeValue(this.path)
        match (this.tree) {
            case Some(t) => w.writeName("tree"); t.toJson(w)
            case None => ()
        }
        w.endObject()
    }
}

public struct DummyPatchEntry <: JsonSerializable {
    public init() {}
    public func toJson(w: JsonWriter): Unit {}
}

public struct CombinedPatchMsg <: JsonSerializable {
    let attrs: Array<DummyPatchEntry>
    let trees: Array<TreePatchEntry>

    public init(attrs: Array<DummyPatchEntry>, trees: Array<TreePatchEntry>) {
        this.attrs = attrs
        this.trees = trees
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("patch")
        w.writeName("attrs").writeValue(this.attrs)
        w.writeName("trees").writeValue(this.trees)
        w.endObject()
    }
}

public struct ActionContext {
    public let sessionId: String
    public let context: HashMap<String, String>
    public let params: HashMap<String, String>
    public let router: Router
    public let pushFn: (Array<PatchEntryMsg>) -> Unit
    public let sessionStates: HashMap<String, AppState>
    public let route: RouteContext
    public let keyEvent: Option<KeyEvent>
    // DOM 事务入口（事件驱动）：fire-and-forget 命令 + 查询续体。App 注入，None 表示不可用
    public let dom: Option<DomApi>

    public init(sessionId: String, context: HashMap<String, String>, params: HashMap<String, String>, router: Router, pushFn!: (Array<PatchEntryMsg>) -> Unit = { _ => () }, sessionStates!: HashMap<String, AppState> = HashMap<String, AppState>(), keyEvent!: Option<KeyEvent> = None, dom!: Option<DomApi> = None) {
        this.sessionId = sessionId
        this.context = context
        this.params = params
        this.router = router
        this.pushFn = pushFn
        this.sessionStates = sessionStates
        this.route = RouteContext(params: HashMap<String, String>(), pushFn: Some({ p => router.push(p) }))
        this.keyEvent = keyEvent
        this.dom = dom
    }

    public func push(patches: Array<PatchEntryMsg>): Unit {
        (this.pushFn)(patches)
    }

    public func getState<T>(): T where T <: AppState {
        let key = TypeInfo.of<T>().qualifiedName
        let raw = this.sessionStates.get(key)
        match (raw) {
            case Some(s) => doGetState<T>(s)
            case None => throw Exception("AppState not registered: ${key}")
        }
    }

    /// 会话 id（服务端推送等场景用，如 App.pushUpdate 指定目标会话）
    public func getSessionId(): String {
        this.sessionId
    }

    /// 会话上下文写入（守卫/鉴权用）。上下文与会话绑定，可跨 HTTP 恢复
    public func setContext(key: String, value: String): Unit {
        this.context[key] = value
    }

    /// 会话上下文读取（守卫/鉴权用），返回与会话绑定的上下文 map
    public func getContext(): HashMap<String, String> {
        this.context
    }
}

public struct Router {
    let sessionId: String
    let navigateFn: (String) -> Unit

    public init(sessionId: String, navigateFn: (String) -> Unit) {
        this.sessionId = sessionId
        this.navigateFn = navigateFn
    }

    public func push(path: String): Unit {
        (this.navigateFn)(path)
    }
}

// ---- WS 协议消息类型 ----

public struct ConnectedMsg <: JsonSerializable {
    public init() {}

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("connected")
        w.endObject()
    }
}

public struct PatchEntryMsg <: JsonSerializable {
    let op: String
    let path: String
    let value: IComponent

    public init(op: String, path: String, value: IComponent) {
        this.op = op
        this.path = path
        this.value = value
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("op").writeValue(this.op)
        w.writeName("path").writeValue(this.path)
        w.writeName("value").writeValue(this.value)
        w.endObject()
    }
}

public struct PatchMsg <: JsonSerializable {
    let patches: Array<PatchEntryMsg>

    public init(patches: Array<PatchEntryMsg>) {
        this.patches = patches
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("patch")
        w.writeName("patches").writeValue(this.patches)
        w.endObject()
    }
}

public struct FullTreeMsg <: JsonSerializable {
    let tree: IComponent
    let path: String

    public init(tree: IComponent, path!: String = "") {
        this.tree = tree
        this.path = path
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("fullTree")
        w.writeName("tree")
        this.tree.toJson(w)
        if (this.path != "") {
            w.writeName("path").writeValue(this.path)
        }
        w.endObject()
    }
}

public struct PushMsg <: JsonSerializable {
    let patches: Array<PatchEntryMsg>

    public init(patches: Array<PatchEntryMsg>) {
        this.patches = patches
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("push")
        w.writeName("patches").writeValue(this.patches)
        w.endObject()
    }
}

public struct TitleMsg <: JsonSerializable {
    let title: String

    public init(title: String) {
        this.title = title
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("title")
        w.writeName("title").writeValue(this.title)
        w.endObject()
    }
}

public struct DenyMsg <: JsonSerializable {
    let reason: String
    let path: String

    public init(reason: String, path!: String = "") {
        this.reason = reason
        this.path = path
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("deny")
        w.writeName("reason").writeValue(this.reason)
        if (this.path != "") {
            w.writeName("path").writeValue(this.path)
        }
        w.endObject()
    }
}

/// 令牌同步消息：会话上下文 token 变化时发给前端（前端存 localStorage）
public struct AuthMsg <: JsonSerializable {
    let token: String

    public init(token: String) {
        this.token = token
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("auth")
        w.writeName("token").writeValue(this.token)
        w.endObject()
    }
}
