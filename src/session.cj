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
    // 挂起的 DOM 事务续体：txId → (results) -> PatchResult（dom_result 到达后由 listenLoop 调用）
    var pendingTx: HashMap<String, (HashMap<String, String>) -> PatchResult>
    // 命名引用注册表：ref 名 → 树路径（DOM 事务寻址用，每次渲染后 refreshRefs 重建）
    var refPaths: HashMap<String, String>
    var createdAt: Int64
    var lastActiveAt: Int64
    let context: HashMap<String, String>
    var states: HashMap<String, AppState>
    // 会话上下文视图（框架契约，每会话唯一）：默认实现 SessionContextState，
    // 或应用通过 App.sessionContext<T>(factory) 注册的实现。
    // 按接口类型持有即可，不需要按类型名索引（AppState 那套反射键是给任意多份状态用的）
    var sessionContext: Option<SessionContext>
    // 会话状态是否已初始化：initStates 的幂等判据。
    // 不能用 states.size == 0 判断——应用可能一个 AppState 都不注册
    var statesInitialized: Bool
    // HTTP 阶段守卫未通过时渲染的是登录页占位，WS 连接（令牌恢复）后需按 path 重渲
    var deferred: Bool
    // 已同步给前端的 token（登录/登出后 context["token"] 变化时触发 AuthMsg）
    var syncedToken: String
    // 进行中的 WS 二进制上传（单流：binary 帧无元数据，同一连接一个活跃上传）
    var upload: Option<UploadState>
    // 当前页面树上的组件：路径 → 组件实例（渲染时登记）。
    // 用途：① 换页/重渲时退订旧组件——旧组件仍订阅着共享信号，被标脏后会按
    //       旧路径把旧页面内容补丁进新页面；
    //      ② 补丁只认本会话当前树上的组件，别的会话的脏标记不得套用本树路径。
    var components: HashMap<String, Component>

    public init(id: String, page: IComponent, tree: IComponent) {
        this.id = id
        this.page = page
        this.tree = tree
        this.path = "/"
        this.wsState = WsState.Connecting
        this.ws = None
        this.handlers = HashMap<String, ActionHandler>()
        this.pendingTx = HashMap<String, (HashMap<String, String>) -> PatchResult>()
        this.refPaths = HashMap<String, String>()
        this.createdAt = nowMillis()
        this.lastActiveAt = nowMillis()
        this.context = HashMap<String, String>()
        this.states = HashMap<String, AppState>()
        this.sessionContext = None
        this.statesInitialized = false
        this.deferred = false
        this.syncedToken = ""
        this.upload = None
        this.components = HashMap<String, Component>()
    }

    /**
     * 该组件是否属于本会话**当前**页面树（按路径查到的实例是不是它自己）。
     * 旧页面的组件即使路径与新页面某节点相同，实例也不同 → 不归本树。
     */
    public func ownsComponent(c: Component): Bool {
        match (this.components.get(c.getPath())) {
            case Some(cur) => cur.uid() == c.uid()
            case None => false
        }
    }

    /// 整页渲染后登记组件归属：不在本轮渲染结果里的旧组件全部退订作废
    public func adoptPageComponents(captured: ArrayList<Component>): Unit {
        this.adoptComponents(captured, "", true)
    }

    /// 子树补丁渲染后登记组件归属：只作废该子树路径下的旧组件
    /// （rootPath 为空 = 根组件重渲，渲染结果覆盖整棵树，按整页处理）
    public func adoptSubtreeComponents(rootPath: String, captured: ArrayList<Component>): Unit {
        this.adoptComponents(captured, rootPath, rootPath == "")
    }

    private func adoptComponents(captured: ArrayList<Component>, rootPath: String, wholePage: Bool): Unit {
        let keep = HashMap<Int64, Bool>()
        for (c in captured) { keep[c.uid()] = true }
        let stalePaths = ArrayList<String>()
        for ((p, old) in this.components) {
            if (keep.contains(old.uid())) { continue }
            if (wholePage || p == rootPath || p.startsWith("${rootPath}/")) {
                old.dispose()
                stalePaths.add(p)
            }
        }
        for (p in stalePaths) { this.components.remove(p) }
        this.registerComponents(captured)
    }

    // 登记本轮渲染出的组件：同路径的旧实例（组件实例不跨渲染复用）立即退订作废
    private func registerComponents(captured: ArrayList<Component>): Unit {
        for (c in captured) {
            match (this.components.get(c.getPath())) {
                case Some(prev) => if (prev.uid() != c.uid()) { prev.dispose() }
                case None => ()
            }
            this.components[c.getPath()] = c
        }
    }

    public func touch(): Unit {
        this.lastActiveAt = nowMillis()
    }

    /// 从会话树重建 handler 注册表（startSession/resumeSession/
    /// pushUpdate/applyNav 渲染后调用——统一写入会话级 handlers，
    /// 保证 listenLoop 分发 action/bind 时能看到全部 handler）。
    // 从树收集 data-ref → 路径（DOM 事务寻址）
    public func refreshRefs(tree: IComponent): Unit {
        this.refPaths.clear()
        collectRefsFromTree(tree, "", this.refPaths)
    }

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

    /**
     * 会话上下文只读快照（uid/username/isAdmin/token 等）。
     * 返回**副本**：外部模块可读，但改副本不影响会话（防外部篡改鉴权态）；
     * 渲染期请用 `SessionContextState`（响应式，变化会触发重渲）。
     */
    public func getContext(): HashMap<String, String> {
        let c = HashMap<String, String>()
        for ((k, v) in this.context) {
            c[k] = v
        }
        c
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
