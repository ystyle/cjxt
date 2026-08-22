package cjxt

import std.collection.{ArrayList, HashMap}
import std.reflect.*
import std.sync.Mutex
import stdx.net.http.{WebSocket, WebSocketFrameType}
import tang.{Tang, TangHttpContext}
import tang.middleware.staticfile.{staticFiles, withPrefix, staticMiddleware}

class SessionState {
    var page: IComponent
    var path: String

    public init(page: IComponent, path: String) {
        this.page = page
        this.path = path
    }
}

public class App {
    var tangApp: Tang
    let sessions = SessionManager(300000)
    var config: AppConfig
    var bindHost: String
    var bindPort: UInt16
    let stateRegs = ArrayList<StateReg>()
    var cssBlobs = HashMap<String, String>()
    var jsBlobs = HashMap<String, String>()
    var staticRoutes = ArrayList<(String, String)>()

    public init() {
        this.tangApp = Tang()
        this.config = AppConfig()
        this.bindHost = "0.0.0.0"
        this.bindPort = 8080
    }

    public func host(h: String): App { this.bindHost = h; this }
    public func port(p: UInt16): App { this.bindPort = p; this }
    public func configure(c: AppConfig): App { this.config = c; this }

    /// 配置 token 校验钩子（WS 连接恢复会话时调用，返回会话上下文信息）
    /// 校验回调由应用提供（如 AuthService.validateSessionToken），框架不关心业务
    public func auth(validateToken: (String) -> Option<HashMap<String, String>>): App {
        AuthHooks.setup(validateToken)
        this
    }

    /// 注入外部 Tang 实例（与其他服务共享同一 HTTP 服务），随后正常 serve()
    public func setTang(t: Tang): App {
        this.tangApp = t
        this
    }

    public func state<T>(factory: () -> T): App where T <: AppState {
        let name = TypeInfo.of<T>().qualifiedName
        this.stateRegs.add(StateReg(factory, name))
        this
    }

    public func addCSS(css: String): App {
        let hash = css.hashCode().toString().replace("-", "0")[0..8]
        this.cssBlobs.add(hash, css)
        this
    }

    public func addJS(js: String): App {
        let hash = js.hashCode().toString().replace("-", "0")[0..8]
        this.jsBlobs.add(hash, js)
        this
    }

    public func UseComponent(): App {
        this.addCSS(_componentCSS)
        this.addJS(_frontendJS)
        this.addJS(_floatingUIJS)
        this.addJS(_tooltipJS)
        this.addJS(_popoverJS)
        this
    }

    public func serveStatic(prefix: String, dir: String): App {
        this.staticRoutes.add((prefix, dir))
        this.tangApp.get("${prefix}/*", staticFiles(dir, [withPrefix(prefix)]))
        this
    }

    /**
     * 按会话 id 获取会话（外部模块访问用，如 harness 事件桥）
     */
    public func getSession(sid: String): Option<Session> {
        this.sessions.get(sid)
    }

    /// 停止服务器（测试清理 / 生命周期管理用；未启动时是安全空操作）
    public func stop(): Unit {
        this.tangApp.stop()
        this.sessions.clearAll()
    }

    public func serve(): Unit {
        let reg = RouteRegistry.global()
        let bp = this.config.basePath
        for ((entry, _) in reg.entries) {
            let routePath = if (bp != "") { "${bp}${entry.path}" } else { entry.path }
            let tangPath = if (entry.path.contains("[")) { this.makeWildcard(routePath) } else { routePath }
            this.tangApp.get(tangPath, { ctx => this.renderHTTP(ctx) })
        }
        for ((prefix, dir) in this.staticRoutes) {
            this.tangApp.get("${prefix}/*", staticFiles(dir, [withPrefix(prefix)]))
        }
        this.tangApp.get("${bp}/ws", { ctx => this.upgradeWS(ctx) })
        if (this.cssBlobs.size > 0) {
            this.tangApp.get("${bp}/_cjxt/css/*", { ctx => this.serveEmbeddedCSS(ctx) })
        }
        if (this.jsBlobs.size > 0) {
            this.tangApp.get("${bp}/_cjxt/js/*", { ctx => this.serveEmbeddedJS(ctx) })
        }
        this.tangApp.setHost(this.bindHost).setPort(this.bindPort).listen()
    }

    private func makeWildcard(path: String): String {
        let parts = path.split("/")
        let result = ArrayList<String>()
        for (p in parts) {
            if (p.startsWith("[") && p.endsWith("]")) {
                result.add("*")
            } else {
                result.add(p)
            }
        }
        String.join(result.toArray(), delimiter: "/")
    }

    private func initStates(session: Session): Unit {
        for (reg in this.stateRegs) {
            session.states.add(reg.typeName, reg.factory())
        }
    }

    private func renderHTTP(ctx: TangHttpContext): Unit {
        let requestPath = ctx.path()
        match (RouteRegistry.global().resolve(requestPath)) {
            case Some(rm) => this.doRoute(ctx, rm.component, rm.params)
            case None => this.tryRootRoute(ctx)
        }
    }

    private func doRoute(ctx: TangHttpContext, p: IComponent, routeParams: HashMap<String, String>): Unit {
        servePage(ctx, p, routeParams)
    }

    private func tryRootRoute(ctx: TangHttpContext): Unit {
        match (RouteRegistry.global().resolve("/")) {
            case Some(rm) => servePage(ctx, rm.component, rm.params)
            case None => ctx.status(404).writeString("Not Found")
        }
    }

    private func servePage(ctx: TangHttpContext, p: IComponent, routeParams: HashMap<String, String>): Unit {
        let session = sessions.create(p, text(""))
        session.path = ctx.path()
        // HTTP 阶段没有凭据（token 在前端 localStorage，随 WS 连接回传），
        // 因此受守卫保护的路径在此渲染登录页占位；WS 连接令牌校验成功后
        // 再按 session.path 重新渲染真实页面（见 resumeSession/rerenderDeferred）
        match (RouteRegistry.global().resolveGuard(ctx.path(), session.context)) {
            case Some(target) =>
                // 守卫拒绝：渲染守卫指定的跳转页面（如登录页）占位；无该路由则 404
                match (RouteRegistry.global().create(target)) {
                    case Some(fallbackPage) =>
                        this.renderPageInto(ctx, session, fallbackPage, routeParams)
                        session.deferred = true
                    case None =>
                        this.sessions.remove(session.id)
                        ctx.status(404).writeString("Not Found")
                }
                return
            case None => ()
        }
        this.renderPageInto(ctx, session, p, routeParams)
    }

    /// 渲染页面到 HTML 壳（会话初始化 + onMount + 树展开 + 写响应）
    private func renderPageInto(ctx: TangHttpContext, session: Session, page: IComponent, routeParams: HashMap<String, String>): Unit {
        this.initStates(session)
        page.onMount(LifecycleContext(session.id, routeParams, None, None, states: session.states))
        let tree = RenderContext.expandTree(page.renderWithScope(), "")
        session.page = page
        session.tree = tree

        let cssLinks = ArrayList<String>()
        for ((hash, _) in this.cssBlobs) {
            cssLinks.add("${this.config.basePath}/_cjxt/css/${hash}.css")
        }
        let jsLinks = ArrayList<String>()
        for ((hash, _) in this.jsBlobs) {
            jsLinks.add("${this.config.basePath}/_cjxt/js/${hash}.js")
        }
        ctx.contentType("text/html; charset=utf-8").writeString(
            generateHtmlShell(session.id, config: this.config, extraCSS: cssLinks.toArray(), extraJS: jsLinks.toArray()))
    }

    private func serveEmbeddedCSS(ctx: TangHttpContext): Unit {
        let requestPath = ctx.path()
        let bp = this.config.basePath
        let prefix = if (bp != "") { "${bp}/_cjxt/css/" } else { "/_cjxt/css/" }
        if (requestPath.startsWith(prefix)) {
            let hashPart = requestPath[prefix.size..requestPath.size]
            let hash = hashPart.replace(".css", "")
            match (this.cssBlobs.get(hash)) {
                case Some(css) => ctx.contentType("text/css").writeString(css)
                case None => ctx.status(404).writeString("Not found")
            }
        } else {
            ctx.status(404).writeString("Not found")
        }
    }

    private func serveEmbeddedJS(ctx: TangHttpContext): Unit {
        let requestPath = ctx.path()
        let bp = this.config.basePath
        let prefix = if (bp != "") { "${bp}/_cjxt/js/" } else { "/_cjxt/js/" }
        if (requestPath.startsWith(prefix)) {
            let hashPart = requestPath[prefix.size..requestPath.size]
            let hash = hashPart.replace(".js", "")
            match (this.jsBlobs.get(hash)) {
                case Some(js) => ctx.contentType("application/javascript").writeString(js)
                case None => ctx.status(404).writeString("Not found")
            }
        } else {
            ctx.status(404).writeString("Not found")
        }
    }

    private func upgradeWS(ctx: TangHttpContext): Unit {
        let ws = ctx.upgrade()
        let frame = ws.read()
        let raw = String.fromUtf8(frame.payload)
        let sid = readField(raw, "sessionId")
        let token = readField(raw, "token")

        if (sid != "") {
            match (sessions.get(sid)) {
                case Some(session) => this.resumeSession(ws, session, token)
                case None => this.newSession(ws, sid)
            }
        } else {
            this.newSession(ws, sessions.generateId())
        }
    }

    private func resumeSession(ws: WebSocket, session: Session, token: String): Unit {
        session.wsState = WsState.Connected
        session.ws = Some(ws)
        session.touch()
        // 令牌恢复：连接携带的 token → 应用钩子校验 → 写会话上下文（uid/角色等）
        if (token != "") {
            this.restoreToken(session, token)
        }
        // HTTP 阶段守卫未通过时渲染的是登录页占位；令牌就绪后按 session.path
        // 重新渲染（守卫再次执行：通过 → 原页面，未通过 → 登录页）
        var sendFull = false
        if (session.deferred) {
            sendFull = this.rerenderDeferred(session)
            session.deferred = false
        }
        let state = SessionState(session.page, session.path)
        let tree = RenderContext.expandTree(applyLayout(session.path, session.tree), "")
        session.refreshHandlers(tree)
        // 初始渲染/恢复后清理脏标记（渲染出口统一清理，防止残留污染后续补丁）
        RenderContext.clearDirty()
        wsSendJson(ws, ConnectedMsg())
        if (sendFull) {
            wsSendJson(ws, FullTreeMsg(tree, path: session.path))
        } else {
            wsSendJson(ws, CombinedPatchMsg([], [TreePatchEntry("replace", "", Some(tree))]))
        }
        sendTitle(ws, session.path)
        this.listenLoop(ws, state, session)
    }

    /// 令牌校验并写会话上下文（校验回调返回的信息 + 令牌本身）
    private func restoreToken(session: Session, token: String): Unit {
        match (AuthHooks.global()) {
            case Some(hooks) =>
                match (hooks.doValidateToken(token)) {
                    case Some(ctxMap) =>
                        for ((k, v) in ctxMap) {
                            session.context[k] = v
                        }
                        session.context[TOKEN_KEY] = token
                        session.syncedToken = token
                    case None => ()
                }
            case None => ()
        }
    }

    /// 延迟页面重渲：按 session.path 重新解析并渲染（守卫未通过 → 守卫指定页面）
    /// 返回 true 表示渲染了新页面（调用方以 fullTree 发送，携带新路径）
    private func rerenderDeferred(session: Session): Bool {
        let path = session.path
        match (RouteRegistry.global().resolveGuard(path, session.context)) {
            case Some(target) =>
                match (RouteRegistry.global().create(target)) {
                    case Some(fallbackPage) =>
                        if (session.states.size == 0) { this.initStates(session) }
                        fallbackPage.onMount(LifecycleContext(session.id, HashMap<String, String>(), None, None, states: session.states))
                        session.page = fallbackPage
                        session.path = target
                        session.tree = RenderContext.expandTree(fallbackPage.renderWithScope(), "")
                        return true
                    case None => return false
                }
            case None => ()
        }
        match (RouteRegistry.global().resolve(path)) {
            case Some(rm) =>
                if (session.states.size == 0) { this.initStates(session) }
                rm.component.onMount(LifecycleContext(session.id, rm.params, None, None, states: session.states))
                session.page = rm.component
                session.tree = RenderContext.expandTree(rm.component.renderWithScope(), "")
                return true
            case None => return false
        }
    }

    private func newSession(ws: WebSocket, sid: String): Unit {
        match (RouteRegistry.global().create("/")) {
            case Some(page) => startSession(ws, sid, page)
            case None => ws.closeConn()
        }
    }

    private func applyLayout(path: String, raw: IComponent): IComponent {
        match (RouteRegistry.global().getLayout(path)) {
            case Some(fn) => fn(raw)
            case None => raw
        }
    }

    private func startSession(ws: WebSocket, sid: String, page: IComponent): Unit {
        let session = sessions.save(sid, page, div([text("")]))
        session.wsState = WsState.Connected
        session.ws = Some(ws)
        if (session.states.size == 0) { this.initStates(session) }
        let mountCtx = LifecycleContext(sid, HashMap<String, String>(), None, None, states: session.states)
        page.onMount(mountCtx)
        let state = SessionState(page, "/")
        session.path = "/"
        this.initSignals(ws, state, session)
        wsSendJson(ws, ConnectedMsg())
        wsSendJson(ws, CombinedPatchMsg([], [TreePatchEntry("replace", "", Some(session.tree))]))
        sendTitle(ws, "/")
        this.listenLoop(ws, state, session)
    }

    private func initSignals(ws: WebSocket, state: SessionState, session: Session): Unit {
        let raw = state.page.renderWithScope()
        let tree = RenderContext.expandTree(applyLayout(state.path, raw), "")
        session.refreshHandlers(tree)
        session.tree = tree
        // 初始渲染后清理脏标记（渲染出口统一清理，防止残留污染后续补丁）
        RenderContext.clearDirty()
    }

    private func listenLoop(ws: WebSocket, state: SessionState, session: Session): Unit {
        while (true) {
            let frame = ws.read()
            if (frame.frameType == WebSocketFrameType.TextWebFrame) {
                let raw = String.fromUtf8(frame.payload)
                let t = readField(raw, "type")
                if (t == "ack") {
                    let ev = readField(raw, "event")
                    if (ev == "mount") {
                        // mount ack — 不重复调 onMount（this.data 已由 startSession 设置）
                    } else if (ev == "update") {
                        state.page.onUpdate(LifecycleContext("", HashMap<String, String>(), None, None))
                    }
                } else if (t == "action") {
                    let name = readField(raw, "name")
                    if (name != "") {
                        let params = readActionParams(raw)
                        this.dispatchAction(ws, state, session, name, params)
                    }
                } else if (t == "bind") {
                    let name = readField(raw, "name")
                    let value = readBindValue(raw)
                    if (name != "") { this.dispatchBind(ws, state, session, name, value) }
                } else if (t == "navigate") {
                    let path = readField(raw, "path")
                    if (path != "") { this.handleNavigate(ws, state, session, path) }
                }
            } else if (frame.frameType == WebSocketFrameType.CloseWebFrame) {
                ws.writeCloseFrame()
                break
            }
        }
        session.wsState = WsState.Disconnected
        session.ws = None
        session.tree = RenderContext.expandTree(state.page.renderWithScope(), "")
    }

    private func dispatchAction(ws: WebSocket, state: SessionState, session: Session, name: String, params: HashMap<String, String>): Unit {
        match (session.handlers.get(name)) {
            case Some(fn) => this.runAction(ws, state, session, name, fn, params)
            case None => ()
        }
    }

    private func runAction(ws: WebSocket, state: SessionState, session: Session, name: String, fn: ActionHandler, params: HashMap<String, String>): Unit {
        SignalTracker.execMutex.lock()
        let flag = NavFlag()
        let router = Router("", { path => this.execNavAction(ws, state, session, flag, path) })
        let keyEvent = parseKeyEvent(params)
        let ctx = ActionContext("", session.context, params, router, pushFn: { patches =>
            wsSendJson(ws, PushMsg(patches))
        }, sessionStates: session.states, keyEvent: keyEvent)
        try {
            match (fn(ctx)) {
                case PatchResult.ReRender => if (!flag.done) { this.sendPatch(ws, state, session) }
                case _ => ()
            }
            // 登录/登出等动作可能修改上下文 token → 同步给前端（localStorage）
            this.syncAuthToken(ws, session)
        } catch (e: Error) {
            state.page.onError(ErrorContext("", name, e))
        } finally {
            // 必须保证释放 execMutex：handler 抛非 Error 异常时
            // 若跳过 unlock，静态锁永久泄漏 → 后续所有会话/测试死锁
            SignalTracker.execMutex.unlock()
        }
    }

    /// 会话上下文 token 变化时，通过 WS 同步给前端（前端存 localStorage，
    /// 下次连接时回传用于恢复会话）。登出（token 清空）时同步空串清除。
    private func syncAuthToken(ws: WebSocket, session: Session): Unit {
        let token = match (session.context.get(TOKEN_KEY)) {
            case Some(t) => t
            case None => ""
        }
        if (token != session.syncedToken) {
            session.syncedToken = token
            wsSendJson(ws, AuthMsg(token))
        }
    }

    /**
     * 服务端推送：向指定会话推送状态更新（跨线程安全）
     *
     * 供宿主进程内的外部线程（如 agent 事件桥）使用：在 SignalTracker
     * 锁内执行 update 回调（更新 Signal / 组件状态），返回 ReRender 时
     * 计算脏组件并推送增量补丁——与 runAction 完全同构，因此页面更新
     * 逻辑与用户操作触发的渲染共用同一套脏追踪/补丁机制。
     *
     * @param sid 会话 id（SessionManager 中的 session id）
     * @param update 更新回调，返回 PatchResult.ReRender 触发补丁推送
     * @return 是否找到在线会话并执行了更新（会话不存在或已断开返回 false）
     */
    public func pushUpdate(sid: String, update: (ActionContext) -> PatchResult): Bool {
        let session: Session = match (this.sessions.get(sid)) {
            case Some(s) => s
            case None => return false
        }
        match (session.wsState) {
            case WsState.Connected => ()
            case _ => return false
        }
        let ws: WebSocket = match (session.ws) {
            case Some(w) => w
            case None => return false
        }
        let state = SessionState(session.page, session.path)
        session.refreshHandlers(session.tree)
        SignalTracker.execMutex.lock()
        let flag = NavFlag()
        let router = Router("", { path => this.execNavAction(ws, state, session, flag, path) })
        let ctx = ActionContext(sid, session.context, HashMap<String, String>(), router, pushFn: { patches =>
            wsSendJson(ws, PushMsg(patches))
        }, sessionStates: session.states)
        try {
            match (update(ctx)) {
                case PatchResult.ReRender => if (!flag.done) { this.sendPatch(ws, state, session) }
                case _ => ()
            }
        } catch (e: Error) {
            state.page.onError(ErrorContext("", "push", e))
        } finally {
            SignalTracker.execMutex.unlock()
        }
        true
    }

    private func dispatchBind(ws: WebSocket, state: SessionState, session: Session, name: String, value: String): Unit {
        SignalTracker.execMutex.lock()
        try {
            match (session.handlers.get(name)) {
                case Some(fn) => this.doBind(ws, state, session, fn, value, name)
                case None => ()
            }
        } finally {
            SignalTracker.execMutex.unlock()
        }
    }

    private func doBind(ws: WebSocket, state: SessionState, session: Session, fn: ActionHandler, value: String, aname: String): Unit {
        let params = HashMap<String, String>()
        params["value"] = value
        let flag = NavFlag()
        let router = Router("", { path => this.execNavAction(ws, state, session, flag, path) })
        let ctx = ActionContext("", session.context, params, router, pushFn: { patches =>
            wsSendJson(ws, PushMsg(patches))
        }, sessionStates: session.states)
        try {
            match (fn(ctx)) {
                case PatchResult.ReRender => if (!flag.done) { this.sendPatch(ws, state, session) }
                case _ => ()
            }
        } catch (e: Error) {
            state.page.onError(ErrorContext("", aname, e))
        }
    }

    private func execNavAction(ws: WebSocket, state: SessionState, session: Session, flag: NavFlag, path: String): Unit {
        this.handleNavigate(ws, state, session, path)
        flag.done = true
    }

    private func handleNavigate(ws: WebSocket, state: SessionState, session: Session, path: String): Unit {
        match (RouteRegistry.global().resolveGuard(path, session.context)) {
            case Some(target) =>
                // 拒绝导航并告知守卫指定的跳转目标，前端据此自动跳转
                wsSendJson(ws, DenyMsg("无权限访问", path: target))
                return
            case None => ()
        }
        state.page.onUnmount(LifecycleContext("", HashMap<String, String>(), None, None))
        match (RouteRegistry.global().resolve(path)) {
            case Some(rm) => this.applyNav(ws, state, session, rm.component, path, rm.params)
            case None => ()
        }
    }

    private func applyNav(ws: WebSocket, state: SessionState, session: Session, newPage: IComponent, path: String, routeParams: HashMap<String, String>): Unit {
        state.page = newPage
        state.path = path
        let mountCtx = LifecycleContext(session.id, routeParams, None, None, states: session.states)
        newPage.onMount(mountCtx)
        let raw = newPage.renderWithScope()
        let tree = RenderContext.expandTree(applyLayout(path, raw), "")
        session.refreshHandlers(tree)
        session.updatePage(newPage, tree)
        session.path = path
        // 导航后清理脏标记：旧页面实例（如登录页）的 markDirty 残留会在下次
        // sendPatch 被误渲染并整树替换（path="" 时 replace 整个页面）。
        // 所有渲染出口必须统一清理，否则残留脏组件污染后续增量补丁。
        RenderContext.clearDirty()
        wsSendJson(ws, FullTreeMsg(tree, path: path))
        sendTitle(ws, path)
    }

    private func sendTitle(ws: WebSocket, path: String): Unit {
        match (RouteRegistry.global().getTitle(path)) {
            case Some(t) => wsSendJson(ws, TitleMsg(t))
            case None => ()
        }
    }

    private func sendPatch(ws: WebSocket, state: SessionState, session: Session): Unit {
        SignalTracker.pendingRender = false
        let dirty = RenderContext.collectDirty()
        if (dirty.size == 0) { return }

        for (component in dirty) {
            let path = component.getPath()
            let newSubtree = component.renderWithScope(path)
            let expanded = RenderContext.expandTree(newSubtree, path)
            let json = serializeSubtree(expanded, HashMap<String, ActionHandler>())
            session.tree = RenderContext.replaceTreeAtPath(session.tree, path, expanded)

            let msg = "{\"kind\":\"patch\",\"trees\":[{\"op\":\"replace\",\"path\":\"${path}\",\"tree\":${json}}]}"
            wsSendText(ws, msg)
        }

        session.handlers.clear()
        RenderContext.collectHandlersFromTree(session.tree, session.handlers)
        RenderContext.clearDirty()
    }
}

class NavFlag {
    var done: Bool
    public init() { this.done = false }
}

class StateReg {
    let factory: () -> AppState
    let typeName: String

    public init(factory: () -> AppState, typeName: String) {
        this.factory = factory
        this.typeName = typeName
    }
}

private func readField(raw: String, field: String): String {
    let mark = "\"${field}\":\""
    match (raw.indexOf(mark)) {
        case Some(idx) => doReadStr(raw, idx + mark.size)
        case None => ""
    }
}

private func doReadStr(s: String, from: Int64): String {
    match (s.indexOf("\"", from)) {
        case Some(e) => s[from..e]
        case None => ""
    }
}

private func readBindValue(raw: String): String {
    let mark = "\"value\":"
    match (raw.indexOf(mark)) {
        case Some(idx) => doReadBindValue(raw, idx + mark.size)
        case None => ""
    }
}

// 解析 action 消息中的 params 对象（前端所有参数值均为字符串，如按键信息）
func readActionParams(raw: String): HashMap<String, String> {
    let result = HashMap<String, String>()
    let mark = "\"params\":{"
    match (raw.indexOf(mark)) {
        case Some(start) =>
            let body = extractJsonObjectBody(raw, start + mark.size)
            if (body != "") { parseStringPairs(body, result) }
        case None => ()
    }
    result
}

// 从指定起点提取匹配的 JSON 对象体（跳过字符串字面量，处理嵌套 {}）
func extractJsonObjectBody(s: String, from: Int64): String {
    var depth: Int64 = 1
    var i = from
    while (i < s.size) {
        let ch = s[i]
        if (ch == 123u8) {
            depth += 1
        } else if (ch == 125u8) {
            depth -= 1
            if (depth == 0) {
                return s[from..i]
            }
        } else if (ch == 34u8) {
            i += 1
            while (i < s.size) {
                if (s[i] == 92u8) {
                    i += 2
                } else if (s[i] == 34u8) {
                    i += 1
                    break
                } else {
                    i += 1
                }
            }
            continue
        }
        i += 1
    }
    ""
}

// 解析 body 内所有 "key":"value" 键值对（值为字符串；跳过非字符串值）
func parseStringPairs(body: String, out: HashMap<String, String>): Unit {
    var i: Int64 = 0
    while (i < body.size) {
        match (body.indexOf("\"", i)) {
            case Some(q1) =>
                match (body.indexOf("\"", q1 + 1)) {
                    case Some(q2) =>
                        let key = body[q1 + 1..q2]
                        // 跳过键后的空白与冒号
                        var j = q2 + 1
                        while (j < body.size && (body[j] == 32u8 || body[j] == 58u8)) { j += 1 }
                        if (j < body.size && body[j] == 34u8) {
                            let vs = j + 1
                            match (body.indexOf("\"", vs)) {
                                case Some(ve) =>
                                    out[key] = body[vs..ve]
                                    i = ve + 1
                                case None => break
                            }
                        } else {
                            i = j
                        }
                    case None => break
                }
            case None => break
        }
    }
}

func doReadBindValue(s: String, from: Int64): String {
    s[from..s.size - 1]
}
