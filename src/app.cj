package cjxt

import std.collection.{ArrayList, HashMap}
import std.reflect.*
import std.sync.Mutex
import stdx.net.http.{WebSocket, WebSocketFrameType}
import tang.{Tang, TangHttpContext}
import tang.middleware.staticfile.{staticFiles, withPrefix, staticMiddleware}

class SessionState {
    var page: IComponent
    var handlers: HashMap<String, ActionHandler>
    var path: String

    public init(page: IComponent, path: String) {
        this.page = page
        this.path = path
        this.handlers = HashMap<String, ActionHandler>()
    }

    public func refreshFromTree(tree: IComponent): Unit {
        this.handlers.clear()
        RenderContext.collectHandlersFromTree(tree, this.handlers)
    }
}

public class App {
    let tangApp: Tang
    let sessions = SessionManager(300000)
    var config: AppConfig
    var bindHost: String
    var bindPort: UInt16
    let stateRegs = ArrayList<StateReg>()
    var cssBlobs = HashMap<String, String>()
    var jsBlobs = HashMap<String, String>()

    public init() {
        this.tangApp = Tang()
        this.config = AppConfig()
        this.bindHost = "0.0.0.0"
        this.bindPort = 8080
    }

    public func host(h: String): App { this.bindHost = h; this }
    public func port(p: UInt16): App { this.bindPort = p; this }
    public func configure(c: AppConfig): App { this.config = c; this }

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
        this.tangApp.get("${prefix}/*", staticFiles(dir, [withPrefix(prefix)]))
        this
    }

    /**
     * 按会话 id 获取会话（外部模块访问用，如 harness 事件桥）
     */
    public func getSession(sid: String): Option<Session> {
        this.sessions.get(sid)
    }

    public func serve(): Unit {
        let reg = RouteRegistry.global()
        let bp = this.config.basePath
        for ((entry, _) in reg.entries) {
            let routePath = if (bp != "") { "${bp}${entry.path}" } else { entry.path }
            let tangPath = if (entry.path.contains("[")) { this.makeWildcard(routePath) } else { routePath }
            this.tangApp.get(tangPath, { ctx => this.renderHTTP(ctx) })
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
        this.initStates(session)
        p.onMount(LifecycleContext(session.id, routeParams, None, None, states: session.states))
        let tree = RenderContext.expandTree(p.renderWithScope(), "")
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

        if (sid != "") {
            match (sessions.get(sid)) {
                case Some(session) => this.resumeSession(ws, session)
                case None => this.newSession(ws, sid)
            }
        } else {
            this.newSession(ws, sessions.generateId())
        }
    }

    private func resumeSession(ws: WebSocket, session: Session): Unit {
        session.wsState = WsState.Connected
        session.ws = Some(ws)
        session.touch()
        let state = SessionState(session.page, session.path)
        let tree = RenderContext.expandTree(applyLayout(session.path, session.tree), "")
        state.refreshFromTree(tree)
        wsSendJson(ws, ConnectedMsg())
        wsSendJson(ws, CombinedPatchMsg([], [TreePatchEntry("replace", "", Some(tree))]))
        sendTitle(ws, session.path)
        this.listenLoop(ws, state, session)
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
        state.refreshFromTree(tree)
        session.tree = tree
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
        match (state.handlers.get(name)) {
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
        } catch (e: Error) {
            state.page.onError(ErrorContext("", name, e))
        }
        SignalTracker.execMutex.unlock()
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
        state.refreshFromTree(session.tree)
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
        }
        SignalTracker.execMutex.unlock()
        true
    }

    private func dispatchBind(ws: WebSocket, state: SessionState, session: Session, name: String, value: String): Unit {
        SignalTracker.execMutex.lock()
        match (state.handlers.get(name)) {
            case Some(fn) => this.doBind(ws, state, session, fn, value, name)
            case None => ()
        }
        SignalTracker.execMutex.unlock()
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
        if (!RouteRegistry.global().checkGuard(path, session.context)) {
            wsSendJson(ws, DenyMsg("无权限访问"))
            return
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
        state.refreshFromTree(tree)
        session.updatePage(newPage, tree)
        session.path = path
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

        state.handlers.clear()
        RenderContext.collectHandlersFromTree(session.tree, state.handlers)
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
