package cjxt

import std.collection.{HashMap, ArrayList}
import std.time.{DateTime, TimeZone}
import stdx.net.http.WebSocket
import opencj::ulid.*

public enum WsState {
    | Connecting | Connected | Disconnected
}

public class Session {
    let id: String
    var page: IComponent
    var tree: IComponent
    var path: String
    var wsState: WsState
    // 当前连接（服务端推送用：外部线程通过 App.pushUpdate 推补丁）
    // 连接建立时设置，断开时清空
    var ws: ?WebSocket
    // 会话级 handler 注册表：startSession/pushUpdate/applyNav 渲染后
    // 统一写入这里，listenLoop 分发 action/bind 也查这里——保证异步
    // pushUpdate 渲染出的新 handler（如会话列表删除按钮）不丢失。
    var handlers: HashMap<String, ActionHandler>
    var createdAt: Int64
    var lastActiveAt: Int64
    let context: HashMap<String, String>
    var states: HashMap<String, AppState>

    public init(id: String, page: IComponent, tree: IComponent) {
        this.id = id
        this.page = page
        this.tree = tree
        this.path = "/"
        this.wsState = WsState.Connecting
        this.ws = None
        this.handlers = HashMap<String, ActionHandler>()
        this.createdAt = nowMillis()
        this.lastActiveAt = nowMillis()
        this.context = HashMap<String, String>()
        this.states = HashMap<String, AppState>()
    }

    public func touch(): Unit {
        this.lastActiveAt = nowMillis()
    }

    /// 从会话树重建 handler 注册表（startSession/resumeSession/
    /// pushUpdate/applyNav 渲染后调用——统一写入会话级 handlers，
    /// 保证 listenLoop 分发 action/bind 时能看到全部 handler）。
    public func refreshHandlers(tree: IComponent): Unit {
        this.handlers.clear()
        RenderContext.collectHandlersFromTree(tree, this.handlers)
    }

    public func updatePage(page: IComponent, tree: IComponent): Unit {
        this.page = page
        this.tree = tree
        this.touch()
    }

    /**
     * 会话页面组件实例（外部模块访问用，如 harness 事件桥）
     */
    public func getPage(): IComponent {
        this.page
    }

    /**
     * 会话当前连接（外部模块访问用，如 harness 服务端推送）
     */
    public func getWs(): ?WebSocket {
        this.ws
    }

    public func isExpired(ttlMillis: Int64): Bool {
        nowMillis() - this.lastActiveAt > ttlMillis
    }
}

public class SessionManager {
    let sessions = HashMap<String, Session>()
    let ttlMillis: Int64

    public init(ttlMillis: Int64) {
        this.ttlMillis = ttlMillis
    }

    public func create(page: IComponent, tree: IComponent): Session {
        let id = this.generateId()
        let session = Session(id, page, tree)
        sessions.add(id, session)
        session
    }

    public func save(id: String, page: IComponent, tree: IComponent): Session {
        let session = Session(id, page, tree)
        sessions.add(id, session)
        session
    }

    public func get(id: String): Option<Session> {
        sessions.get(id)
    }

    public func remove(id: String): Unit {
        sessions.remove(id)
    }

    /// 清空全部会话（服务器停止 / 测试清理用）
    public func clearAll(): Unit {
        let ids = ArrayList<String>()
        for ((id, _) in sessions) { ids.add(id) }
        for (id in ids) { sessions.remove(id) }
    }

    public func cleanup(): Unit {
        for ((id, session) in sessions) {
            if (session.isExpired(ttlMillis)) {
                sessions.remove(id)
            }
        }
    }

    public func generateId(): String {
        nextId()
    }
}

func nowMillis(): Int64 {
    DateTime.nowUTC().toUnixTimeStamp().toMilliseconds()
}
