package cjxt

import std.collection.{ArrayList, HashMap}
import std.fs.{File, OpenMode, Path, remove}
import std.io.ByteBuffer
import opencj::ulid.nextId
import std.time.DateTime
import std.reflect.*
import std.sync.Mutex
import std.time.*
import stdx.net.http.{WebSocket, WebSocketFrame, WebSocketFrameType, HttpRequestDistributor, ServerBuilder}
import tang.{Tang, TangHttpContext}
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}
import stdx.encoding.base64.fromBase64String
import tang.middleware.staticfile.{staticFiles, withPrefix, staticMiddleware}

class SessionState {
    var page: IComponent
    var path: String

    public init(page: IComponent, path: String) {
        this.page = page
        this.path = path
    }
}

/// 渲染期临时变量：当前正在应用 layout 的路径（见 applyLayout）。
/// layout 函数内通过 `layoutPath()` 读；渲染结束即清空。
var currentLayoutPath: String = ""

/// layout 里读当前页面路径（导航高亮用）。不在 layout 上下文里时返回空串。
public func layoutPath(): String {
    currentLayoutPath
}

public class App {
    var tangApp: Tang
    let sessions = SessionManager(300000)
    // 会话巡检：后台线程按固定间隔回收过期会话。
    // 存在的理由：SessionManager.cleanup() 此前**没有任何调用点**，sessions 只增不减 ——
    // 每次 HTTP 页面请求都会 create 一个会话（持有一整棵渲染树），健康检查这类
    // 高频探活下会累积到撑爆堆（2026-10-16 忆时塔生产事故的根因）。
    var sessionSweepMs: Int64 = 30000
    var sweeperStarted = false
    var sweeperRunning = false
    var config: AppConfig
    var bindHost: String
    var bindPort: UInt16
    let stateRegs = ArrayList<StateReg>()
    // 会话上下文工厂（应用可选注册；None = 用默认实现 SessionContextState）。
    // 每会话唯一的上下文按接口类型持有，因此不需要 AppState 那套类型名索引
    var sessionContextFactory: Option<(HashMap<String, String>) -> SessionContext> = None
    // stdx ServerBuilder 定制（默认空操作；见 serverBuilder()）
    var builderFn: (ServerBuilder) -> Unit = { _ => () }
    var cssBlobs = HashMap<String, String>()
    var jsBlobs = HashMap<String, String>()
    var staticRoutes = ArrayList<(String, String)>()
    // 服务端推送合并器：流式多 token 的 pushUpdate 合并为一次 flush（一个 sendPatch）
    var pushCoalescer = PushCoalescer()
    // WS 二进制上传的存储配置（serveUpload 时写入；未调用则 WS 上传被拒绝）
    var uploadDir: String = ""
    var uploadPrefix: String = ""
    // sendPatch 调用计数（诊断/测试用：验证推送合并——N 次 pushUpdate → 1 次 sendPatch）
    public static var sendPatchCount: Int64 = 0

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

    /// 替换会话上下文的实现（视图与通知层；权威存储仍是 Session.context）。
    /// 不调用则使用默认实现 `SessionContextState`。
    ///
    /// ```cangjie
    /// App().sessionContext<MyContext>({ m => MyContext(m) })
    /// ```
    /// 泛型约束 `T <: SessionContext` 把工厂收窄成接口类型，框架按接口持有，
    /// 无需反射即可在每会话注入（页面用 `ctx.getSessionContext()` 取用）。
    public func sessionContext<T>(factory: (HashMap<String, String>) -> T): App where T <: SessionContext {
        let f: (HashMap<String, String>) -> SessionContext = { m => factory(m) }
        this.sessionContextFactory = Some(f)
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
        this.addJS(_popconfirmJS)
        this
    }

    public func serveStatic(prefix: String, dir: String): App {
        this.staticRoutes.add((prefix, dir))
        this.tangApp.get("${prefix}/*", staticFiles(dir, [withPrefix(prefix)]))
        this
    }

    // 上传端点：POST prefix → JSON {name, data(base64)} → 解码存盘 → 返回 {name,url,size}
    // 同时把 dir 静态暴露在 prefix 下供访问。
    // 说明：客户端用 FileReader 读为 base64 后 POST JSON（绕开 tang multipartForm 的挂起问题）。
    public func serveUpload(prefix: String, dir: String): App {
        this.uploadPrefix = prefix
        this.uploadDir = dir
        this.serveStatic(prefix, dir)
        this.tangApp.post(prefix) { ctx =>
            try {
                let raw = String.fromUtf8(ctx.bodyRaw())
                let name = extractQuotedAfter(raw, "\"name\":\"")
                let data = extractQuotedAfter(raw, "\"data\":\"")
                if (name == "" || data == "") {
                    ctx.jsonWithCode(400, UploadResult("", "", 0))
                } else {
                    match (fromBase64String(data)) {
                        case Some(bytes) =>
                            let stored = "${nextId()}-${name}"
                            let out = File("${dir}/${stored}", OpenMode.Write)
                            out.write(bytes)
                            out.close()
                            ctx.json(UploadResult(name, "${prefix}/${stored}", bytes.size))
                        case None =>
                            ctx.jsonWithCode(400, UploadResult("", "", 0))
                    }
                }
            } catch (e: Exception) {
                ctx.jsonWithCode(500, UploadResult("", "", 0))
            }
        }
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

    // ── 脱离连接的承载（无 HTTP / 无 WebSocket）──────────────────────────
    //
    // 页面由外部宿主驱动时（WebView 方法绑定、IPC、单测替身、静态生成），框架既不
    // 监听端口也不用 WS：宿主建立一个会话，把出站帧取走喂给自己的通道，再把页面的
    // 交互消息交回。**这里只做"渲染一页 / 喂一条消息 / 取走待发帧"三件事**，
    // 具体协议（方法名、信封格式、桥对象名）由承载方在自己的包里实现——框架不知道
    // 也不该知道对方是哪个 WebView 框架。生命周期与会话语义与 WS 路径完全一致。

    /**
     * 渲染一页 HTML（含内联初始树），并登记一个脱离连接的会话。
     *
     * @return (会话 id, HTML 文档)。承载方用会话 id 关联后续的帧收发。
     */
    public func renderDetachedPage(path: String): Option<(String, String)> {
        let sid = match (this.openDetachedSession(path)) {
            case Some(id) => id
            case None => return None
        }
        let session = this.sessions.get(sid).getOrThrow()
        Some((sid, this.generatePageDocument(session)))
    }

    /**
     * 建立无连接会话，并把引导帧（connected + 初始整树）写入出站缓冲。
     *
     * 桌面宿主（页面 `file://` 加载、无 HTTP/WS）用它拿首个会话：随后的
     * `drainDetachedFrames` 即可取到整树帧注入页面。
     */
    public func openDetachedSession(path: String): Option<String> {
        let rm = match (RouteRegistry.global().resolve(path)) {
            case Some(r) => r
            case None => return None
        }
        let session = this.sessions.create(rm.component, text(""))
        session.path = path
        session.sink = Some(BufferSink())
        this.initStates(session)
        // onMount 早于初始渲染：此时推送要压住（与 WS 路径同款初始化窗口语义）
        this.suspendPushes(session)
        rm.component.onMount(LifecycleContext(session.id, rm.params, None, None, states: session.states, sessionContext: session.sessionContext))
        session.page = rm.component
        session.tree = this.renderPageTree(session,
            { => RenderContext.expandTree(applyLayout(path, rm.component.renderWithScope()), "") })
        session.refreshHandlers(session.tree)
        session.refreshRefs(session.tree)
        RenderContext.clearDirtyForSession(session)
        session.markConnected()
        let sink = session.sink.getOrThrow()
        sinkSendJson(sink, ConnectedMsg())
        sinkSendJson(sink, CombinedPatchMsg([], [TreePatchEntry("replace", "", Some(session.tree))]))
        this.drainPushes(session)
        Some(session.id)
    }

    /**
     * 取走该会话自上次调用以来积压的出站包（补丁/标题/推送等）。
     *
     * 宿主在每次交互后调用一次，把返回的文本按顺序喂给自己的页面通道。
     */
    public func drainDetachedFrames(sid: String): Array<String> {
        match (this.sessions.get(sid)) {
            case Some(session) =>
                match (session.sink) {
                    case Some(b: BufferSink) => b.drain()
                    case _ => Array<String>()
                }
            case None => Array<String>()
        }
    }

    /**
     * 把一条页面交互消息喂进会话（与 WS 文本帧同构：`{"type":"action",...}`）。
     *
     * 与 WS 路径共用同一套分发（action/bind/navigate/dom_result/upload_begin），
     * 因此业务代码无需区分承载方式。返回是否发生了分发（会话不存在/消息非法为 false）。
     */
    public func feedDetachedMessage(sid: String, raw: String): Bool {
        let session = match (this.sessions.get(sid)) {
            case Some(s) => s
            case None => return false
        }
        let rawSink = match (session.sink) {
            case Some(s) => s
            case None => return false
        }
        let state = SessionState(session.page, session.path)
        return this.dispatchInbound(rawSink, state, session, raw)
    }

    /**
     * 关闭脱离连接的会话，清理组件订阅与进行中的上传。
     * 承载方在页面销毁时调用，语义对齐 WS 的断连清理。
     */
    public func closeDetachedSession(sid: String): Bool {
        let session = match (this.sessions.get(sid)) {
            case Some(s) => s
            case None => return false
        }
        this.cleanupUpload(session)
        session.wsState = WsState.Disconnected
        // 离树组件退订：否则旧页面组件仍订阅共享信号，被标脏后按旧路径把内容补进新页面
        session.adoptPageComponents(ArrayList<Component>())
        match (session.sink) {
            case Some(s) => s.close()
            case None => ()
        }
        session.sink = None
        this.sessions.remove(sid)
        true
    }

    /// 注册全部路由到 tang（serve() 与外部合并共用）：
    /// 与 MCP 等服务合并单端口时，先调用 setupRoutes()，再用 router() 把分发器
    /// 注入外部 HttpRequestDistributor（见 chronomem ComposeDistributor）。
    public func setupRoutes(): Unit {
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
    }

    /// 底层 tang 路由分发器（合并外部 server 用：distribute(path) → HttpRequestHandler）
    /// 取分发器（与其它服务合并单端口时用：把本 App 作为 fallback 挂到外层 distributor）。
    ///
    /// 这里同样启动会话巡检 —— `serve()` 不会被调用（合并模式下由宿主 serve），
    /// 若只在 serve() 里启动，合并场景的会话就没人回收（应用侧典型形态：
    /// UI 与 MCP/API 同端口）。合并模式下由宿主在 handler 里调用 setupRoutes()。
    public func router(): HttpRequestDistributor {
        this.startSessionSweeper()
        this.tangApp.getRouter()
    }

    /// 定制 stdx `ServerBuilder`（build 前调用）：可配置 TLS、超时、请求体上限等。
    ///
    /// 常见用途：`app.serverBuilder({ sb => sb.maxRequestBodySize(-1) })`
    /// —— stdx 默认请求体上限 **2MB**，超过会被服务端拒绝（413/连接重置），
    /// 上传类应用（文件上传、包发布等）必须放宽。
    public func serverBuilder(f: (ServerBuilder) -> Unit): App {
        this.builderFn = f
        this
    }

    public func serve(): Unit {
        this.setupRoutes()
        this.startSessionSweeper()
        this.tangApp.setHost(this.bindHost).setPort(this.bindPort).listen(this.builderFn)
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

    /// 会话状态初始化：应用注册的 AppState 工厂各建一份 + 会话上下文视图
    /// （默认实现或应用通过 `App.sessionContext<T>()` 注册的实现）。幂等。
    func initStates(session: Session): Unit {
        if (session.statesInitialized) {
            return
        }
        for (reg in this.stateRegs) {
            session.states.add(reg.typeName, reg.factory())
        }
        session.sessionContext = Some(this.createSessionContext(session))
        session.statesInitialized = true
    }

    /// 建会话上下文实例：应用注册了自定义实现就用它，否则用默认实现。
    /// 用泛型约束（T <: SessionContext）把工厂收窄成接口类型，全程无需反射。
    func createSessionContext(session: Session): SessionContext {
        match (this.sessionContextFactory) {
            case Some(f) => f(session.context)
            case None => SessionContextState(session.context)
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
        try {
            this.renderPageIntoInner(ctx, session, page, routeParams)
        } catch (e: Exception) {
            println("cjxt renderPageInto error: " + e.message + " @ " + ctx.path())
            e.printStackTrace()
            ctx.status(500).writeString("Internal Server Error")
        }
    }

    private func renderPageIntoInner(ctx: TangHttpContext, session: Session, page: IComponent, routeParams: HashMap<String, String>): Unit {
        this.initStates(session)
        page.onMount(LifecycleContext(session.id, routeParams, None, None, states: session.states, sessionContext: session.sessionContext))
        // 首渲必须套 layout：否则 HTTP 出来的页面没有侧栏/外壳，
        // 而 WS 恢复那条路径会套 —— 两条路径形态不一致（曾经表现为
        // "layout 只在 WS 之后才出现"且每次连接都整树重发）。
        // applyLayout 的唯一职责就是套一次壳，页面渲染入口处调用它是对的。
        let tree = this.renderPageTree(session,
            { => RenderContext.expandTree(applyLayout(session.path, page.renderWithScope()), "") })
        session.page = page
        session.tree = tree
        session.refreshHandlers(tree)

        ctx.contentType("text/html; charset=utf-8")
            .append("Cache-Control", "no-store, no-cache, must-revalidate")
            .append("Pragma", "no-cache")
            .writeString(this.generatePageDocument(session))
    }

    /**
     * 生成会话当前树的完整 HTML 文档（CSS/JS 资源引用 + 内联初始树）。
     *
     * 初始树直接内联进首屏：页面不必等 WS 建连才显示内容（首屏 = 一次 HTTP 往返，
     * 无白屏窗口）；同时记下这棵树的指纹，WS 连上时若服务端待发树与之一致就不再重复下发。
     */
    private func generatePageDocument(session: Session): String {
        let cssLinks = ArrayList<String>()
        for ((hash, _) in this.cssBlobs) {
            cssLinks.add("${this.config.basePath}/_cjxt/css/${hash}.css")
        }
        let jsLinks = ArrayList<String>()
        for ((hash, _) in this.jsBlobs) {
            jsLinks.add("${this.config.basePath}/_cjxt/js/${hash}.js")
        }
        let initialTree = serializeSubtree(session.tree, session.handlers)
        session.inlinedTreeHash = treeFingerprint(initialTree)
        generateHtmlShell(
            session.id,
            config: this.config,
            extraCSS: cssLinks.toArray(),
            extraJS: jsLinks.toArray(),
            initialTree: initialTree
        )
    }


    /**
     * 脱离连接的承载方做一次往返：喂入一条页面消息，取走本次产生的出站帧。
     *
     * `sid` 为空表示"页面的第一条消息"——此时建立会话并把引导帧作为返回值给出；
     * 后续调用沿用返回的 sid。返回的 frames 已按发生顺序排列，承载方按序注入页面。
     */
    public func detachedRoundTrip(sid: String, message: String): (String, Array<String>) {
        var sessionId = sid
        let frames = ArrayList<String>()
        if (sessionId == "") {
            match (this.openDetachedSession("/")) {
                case Some(newSid) => sessionId = newSid
                case None => return ("", Array<String>())
            }
        } else {
            let _ = this.feedDetachedMessage(sessionId, message)
        }
        for (f in this.drainDetachedFrames(sessionId)) { frames.add(f) }
        (sessionId, frames.toArray())
    }

    /**
     * 生成整页自包含的 HTML 壳（内联全部 CSS/JS，不引用外部 URL）。
     *
     * 供**无 HTTP 服务器**的承载使用：页面以 `file://` 打开时绝对路径资源取不到。
     * 框架只拼页面骨架与运行时，**不假定任何宿主协议**；引导脚本由承载方
     * 以 `bootstrap` 传入（桥对象名、方法名、信封格式都属承载方）。
     */
    public func selfContainedShell(bootstrap: String, csp!: String = ""): String {
        generateSelfContainedShell(
            config: this.config,
            css: this.embeddedCss().map({ e => e[1] }),
            js: this.embeddedJs().map({ e => e[1] }),
            bootstrap: bootstrap,
            csp: csp
        )
    }

    /**
     * 渲染 `path` 对应的页面，并生成**带首屏整树**的自包含 HTML 壳。
     *
     * 与 [selfContainedShell] 的区别：那个只拼骨架，首屏要靠与宿主往返一次才出内容；
     * 本方法把树直接内联进 HTML，**首屏不依赖宿主**。
     *
     * 为什么必须这样：静态承载（打包分发的 `file://` 页面）的壳是构建期生成的，
     * 运行时如果拿不到宿主应答（注入失败、应答被宿主缓冲截断、常驻进程没起来），
     * 页面就是**全白且没有任何可观察错误**——比报错更难查。HTTP 承载一直是这么做的
     * （见 `generatePageDocument`），静态承载必须对齐同一语义。
     *
     * 返回 `None` 表示该路径没有已注册页面。
     */
    public func selfContainedPage(
        path: String,
        bootstrap: String,
        csp!: String = ""
    ): Option<String> {
        let sid = match (this.openDetachedSession(path)) {
            case Some(id) => id
            case None => return None
        }
        let session = this.sessions.get(sid).getOrThrow()
        let tree = serializeSubtree(session.tree, session.handlers)
        Some(generateSelfContainedShell(
            config: this.config,
            css: this.embeddedCss().map({ e => e[1] }),
            js: this.embeddedJs().map({ e => e[1] }),
            bootstrap: bootstrap,
            initialTree: tree,
            csp: csp
        ))
    }

    /** 内嵌 CSS 资源（哈希 → 内容）。供承载方内联进自包含页面。 */
    public func embeddedCss(): Array<(String, String)> {
        let out = ArrayList<(String, String)>()
        for ((k, v) in this.cssBlobs) { out.add((k, v)) }
        out.toArray()
    }

    /** 内嵌 JS 资源（哈希 → 内容）。供承载方内联进自包含页面。 */
    public func embeddedJs(): Array<(String, String)> {
        let out = ArrayList<(String, String)>()
        for ((k, v) in this.jsBlobs) { out.add((k, v)) }
        out.toArray()
    }

    /** 页面配置（标题、字体等）。供承载方生成页面壳。 */
    public func appConfig(): AppConfig {
        this.config
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
        try {
            this.upgradeWSInner(ctx)
        } catch (e: Error) {
            println("cjxt-diag upgradeWS ERR(Error): " + e.toString())
        } catch (e: Exception) {
            println("cjxt-diag upgradeWS EX: " + e.toString())
            this.logStack(e)
        }
    }

    private func logStack(e: Exception): Unit {
        let st = e.getStackTrace()
        for (i in 0..st.size) {
            if (i < 12) { println("cjxt-diag stack " + st[i].toString()) }
        }
    }

    private func upgradeWSInner(ctx: TangHttpContext): Unit {
        let ws = ctx.upgrade()
        let sink = WebSocketSink(ws)
        println("cjxt-diag upgrade ok, waiting connect frame")
        let frame = ws.read()
        let raw = String.fromUtf8(frame.payload)
        let sid = readField(raw, "sessionId")
        let token = readField(raw, "token")

        if (sid != "") {
            match (sessions.get(sid)) {
                case Some(session) =>
                    println("cjxt-ws: RESUME sid=" + sid + " path=" + session.path)
                    this.resumeSession(sink, session, token)
                case None =>
                    println("cjxt-ws: NEW(sid-miss) sid=" + sid)
                    this.newSession(sink, sid)
            }
        } else {
            println("cjxt-ws: NEW(no-sid)")
            this.newSession(sink, sessions.generateId())
        }
    }

    private func resumeSession(sink: PageSink, session: Session, token: String): Unit {
        session.markConnected()
        session.sink = Some(sink)
        session.touch()
        // 令牌恢复：连接携带的 token → 应用钩子校验 → 写会话上下文（uid/角色等）+ 通知订阅者
        var restored = false
        if (token != "") {
            restored = this.restoreToken(session, token)
        }
        // HTTP 阶段守卫未通过时渲染的是登录页占位；令牌就绪后按 session.path
        // 重新渲染（守卫再次执行：通过 → 原页面，未通过 → 登录页）
        var sendFull = false
        if (session.deferred) {
            sendFull = this.rerenderDeferred(session)
            session.deferred = false
        } else if (restored) {
            // 公开页（HTTP 期守卫放行）不会走 deferred 分支：令牌恢复后必须就地重渲
            // 一次，否则首屏「未登录」版本（如公开导航里的管理入口）会被原样沿用
            this.rerenderInPlace(session)
        }
        let state = SessionState(session.page, session.path)
        // session.tree **已经**在产生它的那条路径上套过 layout 了：
        //   · HTTP 首渲 → renderPageTree({ => expandTree(applyLayout(path, page.render())) })
        //   · rerenderInPlace / rerenderDeferred 同样在渲染时套过
        // 这里只做 expandTree，不能再 applyLayout —— 否则页面被 layout 包两次，
        // 侧栏/菜单出现两遍（这就是"@Page 的 layout 会二次包裹"的根因）。
        // 注意与上面的 inlinedMatches 指纹判断配合：早先正是"两条路径形态不同"
        // 让指纹永远对不上、每次连接都整树下发。
        let tree = RenderContext.expandTree(session.tree, "")
        session.refreshHandlers(tree)
        session.refreshRefs(tree)
        // 初始渲染/恢复后清理脏标记（渲染出口统一清理，防止残留污染后续补丁）。
        // 只清本会话的：别的会话的脏标记由它自己的 sendPatch 处理
        RenderContext.clearDirtyForSession(session)
        sinkSendJson(sink, ConnectedMsg())
        // 首屏已内联整树、且本次连接未改变它（无 deferred 重渲、无令牌恢复重渲）时，
        // 若服务端待发树与内联那棵指纹一致，客户端手上就已是最终形态 → 跳过整树下发，
        // 避免刚显示就把根节点整棵替换（白白丢掉焦点/滚动位置与客户端组件局部状态）。
        // 指纹不一致（如 layout 在两条路径上的形态差异）则照常下发，保证正确性优先。
        let treeJson = serializeSubtree(tree, session.handlers)
        let inlinedMatches = session.inlinedTreeHash != "" && session.inlinedTreeHash == treeFingerprint(treeJson)
        let skipTreeSend = inlinedMatches && !sendFull && !restored
        session.inlinedTreeHash = ""
        if (skipTreeSend) {
            // 客户端已有的树与待发树一致：只回 connected，不重复下发
        } else if (sendFull) {
            sinkSendJson(sink, FullTreeMsg(tree, path: session.path))
        } else {
            sinkSendJson(sink, CombinedPatchMsg([], [TreePatchEntry("replace", "", Some(tree))]))
        }
        sendTitle(sink, session.path)
        this.listenLoop(sink, state, session)
    }

    /// 令牌校验并写会话上下文（校验回调返回的信息 + 令牌本身）。
    /// 返回 true 表示校验通过（调用方据此决定是否按新上下文就地重渲当前页）
    private func restoreToken(session: Session, token: String): Bool {
        match (AuthHooks.global()) {
            case Some(hooks) => this.applyRestoredContext(session, hooks.doValidateToken(token), token)
            case None => false
        }
    }

    /// 应用令牌校验结果：写会话上下文 + 同步令牌 + 通知响应式视图（SessionContextState）。
    /// None = 校验失败，不写任何上下文。
    /// （不标 private：同包测试需覆盖「恢复 → 上下文可见 / 订阅者被通知」）
    func applyRestoredContext(session: Session, validated: Option<HashMap<String, String>>, token: String): Bool {
        let ctxMap = match (validated) {
            case Some(m) => m
            case None => return false
        }
        for ((k, v) in ctxMap) {
            session.context[k] = v
        }
        session.context[TOKEN_KEY] = token
        session.syncedToken = token
        notifySessionContext(session.sessionContext)
        true
    }

    /// 令牌恢复后的就地重渲：同一页面实例重新 render（**不重跑 onMount**，避免
    /// 重置页面级信号）。因此页面必须在 render() 内读会话上下文
    /// （`SessionContextState`），不要只在 onMount 里缓存成普通字段。
    /// （不标 private：同包测试需覆盖「恢复 → 树里入口出现」）
    func rerenderInPlace(session: Session): Unit {
        session.tree = this.renderPageTree(session,
            { => RenderContext.expandTree(applyLayout(session.path, session.page.renderWithScope()), "") })
    }

    /// 延迟页面重渲：按 session.path 重新解析并渲染（守卫未通过 → 守卫指定页面）
    /// 返回 true 表示渲染了新页面（调用方以 fullTree 发送，携带新路径）
    private func rerenderDeferred(session: Session): Bool {
        let path = session.path
        match (RouteRegistry.global().resolveGuard(path, session.context)) {
            case Some(target) =>
                match (RouteRegistry.global().create(target)) {
                    case Some(fallbackPage) =>
                        this.initStates(session)
                        fallbackPage.onMount(LifecycleContext(session.id, HashMap<String, String>(), None, None, states: session.states, sessionContext: session.sessionContext))
                        session.page = fallbackPage
                        session.path = target
                        session.tree = this.renderPageTree(session,
                            { => RenderContext.expandTree(fallbackPage.renderWithScope(), "") })
                        return true
                    case None => return false
                }
            case None => ()
        }
        match (RouteRegistry.global().resolve(path)) {
            case Some(rm) =>
                this.initStates(session)
                rm.component.onMount(LifecycleContext(session.id, rm.params, None, None, states: session.states, sessionContext: session.sessionContext))
                session.page = rm.component
                session.tree = this.renderPageTree(session,
                    { => RenderContext.expandTree(rm.component.renderWithScope(), "") })
                return true
            case None => return false
        }
    }

    private func newSession(sink: PageSink, sid: String): Unit {
        match (RouteRegistry.global().create("/")) {
            case Some(page) => startSession(sink, sid, page)
            case None => sink.close()
        }
    }

    private func applyLayout(path: String, raw: IComponent): IComponent {
        match (RouteRegistry.global().getLayout(path)) {
            case Some(fn) =>
                // 把当前路径交给 layout：`LayoutFn` 的签名只有 (IComponent) -> IComponent，
                // 拿不到"这是哪一页"，而导航高亮、按页裁剪侧栏都需要它。
                // 用渲染期临时变量传递（layout 在 fn(raw) 里同步执行完，不跨请求）。
                currentLayoutPath = path
                try {
                    fn(raw)
                } finally {
                    currentLayoutPath = ""
                }
            case None => raw
        }
    }

    /**
     * 整页渲染：本轮渲染出的组件按「整页」归属登记到会话。
     *
     * 换页只替换 session.tree，不会自动解除旧页面组件在共享信号上的订阅；
     * 旧组件一旦被标脏，就会按**旧路径**把旧页面内容补丁进新页面
     * （实测：发布计划详情页下半个表格被计划列表覆盖）。所以每次整页渲染
     * 都要登记归属并让离树组件退订。
     */
    private func renderPageTree(session: Session, build: () -> IComponent): IComponent {
        RenderContext.beginCapture(session.id)
        var tree: IComponent = text("")
        try {
            tree = build()
        } finally {
            session.adoptPageComponents(RenderContext.endCapture())
        }
        tree
    }

    private func startSession(sink: PageSink, sid: String, page: IComponent): Unit {
        let session = sessions.save(sid, page, div([text("")]))
        session.markConnected()
        session.sink = Some(sink)
        this.initStates(session)
        // onMount 里起的推送要等初始树发下去（见 suspendPushes 的注释）
        this.suspendPushes(session)
        let mountCtx = LifecycleContext(sid, HashMap<String, String>(), None, None, states: session.states, sessionContext: session.sessionContext)
        page.onMount(mountCtx)
        let state = SessionState(page, "/")
        session.path = "/"
        this.initSignals(sink, state, session)
        sinkSendJson(sink, ConnectedMsg())
        sinkSendJson(sink, CombinedPatchMsg([], [TreePatchEntry("replace", "", Some(session.tree))]))
        sendTitle(sink, "/")
        this.drainPushes(session)
        this.listenLoop(sink, state, session)
    }

    private func initSignals(sink: PageSink, state: SessionState, session: Session): Unit {
        let tree = this.renderPageTree(session,
            { => RenderContext.expandTree(applyLayout(state.path, state.page.renderWithScope()), "") })
        session.refreshHandlers(tree)
        session.refreshRefs(tree)
        session.tree = tree
        // 初始渲染后清理脏标记（渲染出口统一清理，防止残留污染后续补丁）
        RenderContext.clearDirtyForSession(session)
    }

    private func listenLoop(sink: PageSink, state: SessionState, session: Session): Unit {
        // WS 专属读取路径：只有 WS 承载才有可读帧；其它承载下没有入站流，
        // 交互由宿主在自己的通道上驱动（见 dispatchHostInput）。
        let ws: WebSocket = match (sink) {
            case s: WebSocketSink => s.underlying()
            case _ => return
        }
        try {
            while (true) {
                let frame = ws.read()
                if (frame.frameType == WebSocketFrameType.TextWebFrame) {
                    let raw = String.fromUtf8(frame.payload)
                    this.dispatchInbound(sink, state, session, raw)
                } else if (frame.frameType == WebSocketFrameType.BinaryWebFrame) {
                    this.handleUploadBinary(ws, state, session, frame)
                } else if (frame.frameType == WebSocketFrameType.PingWebFrame) {
                    // 协议要求：收到 ping 一定要回 pong（保持连接活性）
                    ws.writePongFrame(frame.payload)
                } else if (frame.frameType == WebSocketFrameType.CloseWebFrame) {
                    ws.writeCloseFrame()
                    break
                }
            }
        } finally {
            // 连接断开（正常 Close 帧 break、对端直接断连抛 ConnectionException、
            // 或处理中任意异常逃逸）都必须关闭底层连接，否则 CLOSE_WAIT/fd 泄漏
            // （与 mcp-cj SSE 长连接同款问题——每次进界面/刷新/关页即泄漏一条）。
            // 对端断开时 stdx read() 抛 ConnectionException，不会自动 closeConn，
            // 必须在这里兜底显式关闭。
            ws.closeConn()
        }
        // 连接断开：清理进行中的上传（删除半成品文件）
        this.cleanupUpload(session)
        session.wsState = WsState.Disconnected
        session.sink = None
        session.tree = this.renderPageTree(session,
            { => RenderContext.expandTree(state.page.renderWithScope(), "") })
    }

    /// 一条页面入站文本消息的分发（WS 文本帧与宿主绑定共用同一套语义）。
    /// 返回是否命中已知消息类型（未知类型不算分发）。
    private func dispatchInbound(sink: PageSink, state: SessionState, session: Session, raw: String): Bool {
        let t = readField(raw, "type")
        if (t == "ack") {
            let ev = readField(raw, "event")
            if (ev == "mount") {
                // mount ack — 不重复调 onMount（states 已由会话建立时设置）
            } else if (ev == "update") {
                state.page.onUpdate(LifecycleContext("", HashMap<String, String>(), None, None, sessionContext: session.sessionContext))
            }
            return true
        } else if (t == "action") {
            let name = readField(raw, "name")
            if (name != "") {
                let params = readActionParams(raw)
                this.dispatchAction(sink, state, session, name, params)
            }
            return true
        } else if (t == "bind") {
            let name = readField(raw, "name")
            let value = readBindValue(raw)
            if (name != "") { this.dispatchBind(sink, state, session, name, value) }
            return true
        } else if (t == "navigate") {
            let path = readField(raw, "path")
            if (path != "") { this.handleNavigate(sink, state, session, path) }
            return true
        } else if (t == "dom_result") {
            let txId = readField(raw, "txId")
            let results = readResults(raw)
            if (txId != "") { this.dispatchDomResult(sink, state, session, txId, results) }
            return true
        } else if (t == "upload_begin") {
            this.handleUploadBegin(sink, state, session, raw)
            return true
        }
        return false
    }

    // ============ WS 二进制帧流式上传 ============

    /// upload_begin（文本帧 JSON）：校验 → 建空文件 → 挂 session.upload
    private func handleUploadBegin(sink: PageSink, state: SessionState, session: Session, raw: String): Unit {
        match (parseUploadBegin(raw)) {
            case None =>
                sinkSendJson(sink, UploadErrorMsg("", "bad upload_begin"))
            case Some(b) =>
                if (this.uploadDir == "" || this.uploadPrefix == "") {
                    sinkSendJson(sink, UploadErrorMsg(b.id, "upload not configured (serveUpload missing)"))
                    return
                }
                match (session.upload) {
                    case Some(_) =>
                        sinkSendJson(sink, UploadErrorMsg(b.id, "upload already in progress"))
                    case None =>
                        if (b.size <= 0) {
                            sinkSendJson(sink, UploadErrorMsg(b.id, "empty file"))
                            return
                        }
                        let stored = "${nextId()}-${b.name}"
                        let path = "${this.uploadDir}/${stored}"
                        try {
                            let f = File(path, OpenMode.Write)
                            f.close()
                            session.upload = Some(UploadState(b.id, b.name, b.size, b.action, stored))
                        } catch (e: Exception) {
                            sinkSendJson(sink, UploadErrorMsg(b.id, "can not open storage: ${e.message}"))
                        }
                }
        }
    }

    /// 二进制帧：拼接分段帧 → 边收边写 → 块级 ack → 收满 dispatch action
    private func handleUploadBinary(ws: WebSocket, state: SessionState, session: Session, first: WebSocketFrame): Unit {
        // 二进制入站只存在于 WS 承载；出站仍走会话 sink（同一连接）
        match (session.sink) {
            case None => this.cleanupUpload(session)
            case Some(sink) =>
                match (collectBinaryPayload(ws, first)) {
                    case Some(bytes) => this.onUploadChunk(sink, state, session, bytes)
                    case None => this.cleanupUpload(session)
                }
        }
    }

    /// 读取并拼接一个完整的二进制消息（浏览器可能把单个消息分段发送）。
    /// 帧间穿插 Ping 控制帧时回 Pong；收到 Close / 非法帧 → None（调用方中止）。
    private func collectBinaryPayload(ws: WebSocket, first: WebSocketFrame): Option<Array<UInt8>> {
        if (first.fin) {
            return Some(first.payload)
        }
        var data = ArrayList<UInt8>()
        appendBytes(data, first.payload)
        var f = first
        while (!f.fin) {
            f = ws.read()
            match (f.frameType) {
                case ContinuationWebFrame => appendBytes(data, f.payload)
                case PingWebFrame => ws.writePongFrame(f.payload)
                case CloseWebFrame =>
                    ws.writeCloseFrame()
                    return None
                case _ => return None
            }
        }
        Some(data.toArray())
    }

    /// 写一块字节：写盘 → 进度 ack → 收满后 dispatch uploaded action
    private func onUploadChunk(sink: PageSink, state: SessionState, session: Session, bytes: Array<UInt8>): Unit {
        if (bytes.size == 0) {
            return
        }
        match (session.upload) {
            case None =>
                // 没有进行中的上传却收到数据帧：忽略并提示
                sinkSendJson(sink, UploadErrorMsg("", "no active upload"))
            case Some(u) =>
                if (uploadWouldOverflow(u, bytes.size)) {
                    this.abortUpload(sink, session, "size exceeded")
                    return
                }
                try {
                    let f = File("${this.uploadDir}/${u.stored}", OpenMode.Append)
                    f.write(bytes)
                    f.close()
                } catch (e: Exception) {
                    this.abortUpload(sink, session, "write failed: ${e.message}")
                    return
                }
                let done = uploadFeed(u, bytes.size)
                sinkSendJson(sink, UploadProgressMsg(u.id, u.received))
                if (done) {
                    session.upload = None
                    // 完成：走标准 action 链路（handler 由 Upload 组件的 data-action-uploaded 提供）
                    let params = HashMap<String, String>()
                    params["name"] = u.name
                    params["url"] = "${this.uploadPrefix}/${u.stored}"
                    params["size"] = u.received.toString()
                    this.dispatchAction(sink, state, session, u.action, params)
                }
        }
    }

    /// 中止上传：删半成品文件 + 清 session.upload + 回错误帧
    private func abortUpload(sink: PageSink, session: Session, message: String): Unit {
        match (session.upload) {
            case Some(u) =>
                this.removeUploadFile(u)
                session.upload = None
                sinkSendJson(sink, UploadErrorMsg(u.id, message))
            case None => ()
        }
    }

    /// 连接断开 / 协议异常时清理进行中的上传
    private func cleanupUpload(session: Session): Unit {
        match (session.upload) {
            case Some(u) =>
                this.removeUploadFile(u)
                session.upload = None
            case None => ()
        }
    }

    private func removeUploadFile(u: UploadState): Unit {
        try {
            remove(Path("${this.uploadDir}/${u.stored}"))
        } catch (e: Exception) {
            ()
        }
    }

    private func dispatchAction(sink: PageSink, state: SessionState, session: Session, name: String, params: HashMap<String, String>): Unit {
        println("cjxt-diag dispatch name=" + name + " handlers=" + session.handlers.size.toString() + " sid=" + session.id)
        match (session.handlers.get(name)) {
            case Some(fn) =>
                this.runAction(sink, state, session, name, fn, params)
            case None =>
                println("cjxt dispatch MISS " + name + " (handlers=" + session.handlers.size.toString() + ")")
        }
    }

    private func runAction(sink: PageSink, state: SessionState, session: Session, name: String, fn: ActionHandler, params: HashMap<String, String>): Unit {
        session.renderLock.lock()
        let flag = NavFlag()
        let router = Router("", { path => this.execNavAction(sink, state, session, flag, path) })
        let keyEvent = parseKeyEvent(params)
        let ctx = ActionContext(session.id, session.context, params, router, pushFn: { patches =>
            sinkSendJson(sink, PushMsg(patches))
        }, sessionStates: session.states, keyEvent: keyEvent, dom: Some(DomApi(this, sink, session)), sessionContext: session.sessionContext)
        try {
            let t0 = DateTime.now().toUnixTimeStamp().toMilliseconds()
            match (fn(ctx)) {
                case PatchResult.ReRender =>
                    if (!flag.done) { this.sendPatch(sink, state, session) }
                case _ => ()
            }
            println("cjxt-diag action done name=" + name + " ms=" + (DateTime.now().toUnixTimeStamp().toMilliseconds() - t0).toString() + " sid=" + session.id)
            // 登录/登出等动作可能修改上下文 token → 同步给前端（localStorage）
            this.syncAuthToken(sink, session)
        } catch (e: Exception) {
            println("cjxt runAction ERROR: " + e.toString())
            println("cjxt-diag stack " + e.getStackTrace().toString())
            state.page.onError(ErrorContext("", name, e))
        } catch (e: Error) {
            println("cjxt runAction ERROR(Error): " + e.toString())
        } finally {
            // 必须保证释放 renderLock：handler 抛非 Error 异常时
            // 若跳过 unlock，该会话永久卡死（后续消息全阻塞）
            session.renderLock.unlock()
        }
    }

    /// 会话上下文 token 变化时，通过 WS 同步给前端（前端存 localStorage，
    /// 下次连接时回传用于恢复会话）。登出（token 清空）时同步空串清除。
    private func syncAuthToken(sink: PageSink, session: Session): Unit {
        let token = match (session.context.get(TOKEN_KEY)) {
            case Some(t) => t
            case None => ""
        }
        if (token != session.syncedToken) {
            session.syncedToken = token
            sinkSendJson(sink, AuthMsg(token))
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
        // 先守住原有契约：会话不存在 / 未连接 / 无连接引用 → false（调用方据此判断"推没推出去"）
        match (session.wsState) {
            case WsState.Connected => ()
            case _ => return false
        }
        match (session.sink) {
            case Some(_) => ()
            case None => return false
        }
        // 回调**同步执行**（调用方依赖它改状态）；初始树尚未下发时，补丁由 runPush 压住，
        // 等树发完 drainPushes 再补（见 suspendPushes）
        this.runPush(session, update)
        true
    }

    /**
     * 初始化窗口：onMount 到「初始树下发」之间挂起推送。
     *
     * 为什么需要：onMount 必须早于初始渲染（页面在那里注入 states），而 onMount 里起线程
     * 或直接推补丁是很自然的写法。那段时间客户端只有空壳，补丁到了也无处可施——此前是
     * **静默丢弃**（pushUpdate 返回 true、界面却永远停在初始状态，直到下一次操作才补上）。
     */
    // 同包可见：单测要能直接驱动初始化窗口的开/合（行为本身在 startSession 里自动发生）
    func suspendPushes(session: Session): Unit {
        session.pushSuspended = true
    }

    /** 初始树下发后：开闸；窗口内被压住的补丁在这里补发（一次，反映最终状态） */
    // 同包可见（同上）
    func drainPushes(session: Session): Unit {
        session.pushSuspended = false
        if (session.pendingPatch) {
            session.pendingPatch = false
            this.markPushPending(session.id)
        }
    }

    /** 推送的实际执行（与用户操作共用同一套脏追踪/补丁机制）；返回 Unit，会话不在线即跳过 */
    private func runPush(session: Session, update: (ActionContext) -> PatchResult): Unit {
        let sid = session.id
        match (session.wsState) {
            case WsState.Connected => ()
            case _ => return
        }
        let sink: PageSink = match (session.sink) {
            case Some(w) => w
            case None => return
        }
        let state = SessionState(session.page, session.path)
        session.refreshHandlers(session.tree)
        session.refreshRefs(session.tree)
        // 单会话推送：只锁本会话（别的会话的渲染不受影响）
        session.renderLock.lock()
        let flag = NavFlag()
        let router = Router("", { path => this.execNavAction(sink, state, session, flag, path) })
        let ctx = ActionContext(sid, session.context, HashMap<String, String>(), router, pushFn: { patches =>
            sinkSendJson(sink, PushMsg(patches))
        }, sessionStates: session.states, dom: Some(DomApi(this, sink, session)), sessionContext: session.sessionContext)
        try {
            match (update(ctx)) {
                case PatchResult.ReRender =>
                    if (!flag.done) {
                        // 初始树还没下发：客户端手上是空壳，补丁发过去也无处可施 —— 压住，
                        // 等整树发完由 drainPushes 补一次（回调本身已经同步跑过了）
                        if (session.pushSuspended) {
                            session.pendingPatch = true
                        } else {
                            this.markPushPending(sid)
                        }
                    }
                case _ => ()
            }
            // 与 runAction 对齐：推送回调里也可能写会话上下文（如「先出 loading 补丁、
            // 异步完成登录再推送」的模式），token 变化同样要同步给前端 localStorage，
            // 否则刷新后拿不到 token 会丢登录态。
            this.syncAuthToken(sink, session)
        } catch (e: Exception) {
            // 对齐 runAction：onError 默认是 no-op，框架层不留痕的话，推送回调抛的异常
            // 在整条链路上完全不可见（表现为「界面没反应」却查不到原因）
            println("cjxt pushUpdate ERROR: " + e.toString())
            println("cjxt-diag stack " + e.getStackTrace().toString())
            state.page.onError(ErrorContext("", "push", e))
        } finally {
            session.renderLock.unlock()
        }
    }

    /**
     * 推送合并：流式场景下短时间内多个 pushUpdate（每 token 一次）合并为一次
     * sendPatch——避免每 token 都整页重渲染 + 下发。首个 pending 启动后台
     * flush 线程，窗口（config.pushFlushMs）内后续 pushUpdate 只追加会话，
     * 窗口到期后统一取走并逐个 sendPatch。用户触发的 runAction 不受影响（即时）。
     */
    private func markPushPending(sid: String): Unit {
        if (this.pushCoalescer.mark(sid)) {
            this.spawnPushFlush()
        }
    }

    private func spawnPushFlush(): Unit {
        let app = this
        let flushMs = this.config.pushFlushMs
        spawn {
            sleep(Duration.millisecond * flushMs)
            // 合并器本身是共享状态（多个 push 调用方都会 mark），单独加锁
            let sids = app.pushCoalescer.beginFlush()
            // 每个会话只锁它自己：不同会话的 flush 互不阻塞
            for (sid in sids) {
                app.flushSessionPush(sid)
            }
        }
    }

    /// 启动会话巡检线程（幂等）。`serve()` 会自动调用；测试可手动调用。
    ///
    /// 巡检做的事：`sessions.cleanup()` 回收过期会话（已建 WS 用长 TTL，
    /// 一次性 HTTP 请求用短 TTL）。不做这一步，每个 HTTP 页面请求都会留下
    /// 一棵永远不被释放的渲染树。
    public func startSessionSweeper(): Unit {
        if (this.sweeperStarted) { return }
        this.sweeperStarted = true
        this.sweeperRunning = true
        let app = this
        spawn {
            while (app.sweeperRunning) {
                // 分片睡眠：停止后最多 1s 退出，而不是等满一个巡检周期
                var slept = Int64(0)
                let total = app.sessionSweepMs / 1000
                while (slept < total && app.sweeperRunning) {
                    sleep(Duration.second)
                    slept += 1
                }
                if (!app.sweeperRunning) { break }
                // 会话表已按分片加锁（见 SessionManager），cleanup 每片在自己的
                // 写锁内完成「遍历 + 删除」，不再需要一把全局执行锁。
                // 注意 dispose 掉的组件订阅是各会话自己的（ReactiveNode.subs 有锁），
                // 不需要跨会话协调。代价：不是原子的全局快照，但"回收过期"允许这点误差。
                app.sessions.cleanup()
            }
        }
    }

    /// 停止巡检线程（服务器关闭 / 测试收尾用）
    public func stopSessionSweeper(): Unit {
        this.sweeperRunning = false
    }

    /// 手动触发一次巡检（测试用：不必等后台周期）
    public func sweepSessionsOnce(): Int64 {
        this.sessions.cleanup()
    }

    private func flushSessionPush(sid: String): Unit {
        let session = match (this.sessions.get(sid)) {
            case Some(s) => s
            case None => return
        }
        match (session.wsState) {
            case WsState.Connected => ()
            case _ => return
        }
        let sink = match (session.sink) {
            case Some(w) => w
            case None => return
        }
        let state = SessionState(session.page, session.path)
        session.renderLock.lock()
        try {
            this.sendPatch(sink, state, session)
        } finally {
            session.renderLock.unlock()
        }
    }

    // 超时/取消分发：若 tx 仍 pending 则跑其续体（ReRender→sendPatch）；已正常完成则忽略
    public func dispatchDomTimeout(session: Session, txId: String): Bool {
        match (session.wsState) {
            case WsState.Connected => ()
            case _ => return false
        }
        let sink = match (session.sink) { case Some(w) => w case None => return false }
        let state = SessionState(session.page, session.path)
        let results = HashMap<String, String>()
        this.dispatchDomResult(sink, state, session, txId, results)
        true
    }

    // DOM 事务结果分发：dom_result 到达 → 取 session.pendingTx 续体 → 锁内跑 → ReRender 则 sendPatch
    private func dispatchDomResult(sink: PageSink, state: SessionState, session: Session, txId: String, results: HashMap<String, String>): Unit {
        session.renderLock.lock()
        try {
            match (session.pendingTx.get(txId)) {
                case Some(k) =>
                    session.pendingTx.remove(txId)
                    let flag = NavFlag()
                    let router = Router("", { path => this.execNavAction(sink, state, session, flag, path) })
                    let ctx = ActionContext(session.id, session.context, HashMap<String, String>(), router, pushFn: { patches =>
                        sinkSendJson(sink, PushMsg(patches))
                    }, sessionStates: session.states, dom: Some(DomApi(this, sink, session)), sessionContext: session.sessionContext)
                    match (k(results)) {
                        case PatchResult.ReRender => if (!flag.done) { this.sendPatch(sink, state, session) }
                        case _ => ()
                    }
                case None => ()
            }
        } catch (e: Exception) {
            // 续体异常不杀连接：捕获并走 onError（与 runAction 一致）
            state.page.onError(ErrorContext("", "dom_result", e))
        } finally {
            session.renderLock.unlock()
        }
    }

    private func dispatchBind(sink: PageSink, state: SessionState, session: Session, name: String, value: String): Unit {
        session.renderLock.lock()
        try {
            match (session.handlers.get(name)) {
                case Some(fn) => this.doBind(sink, state, session, fn, value, name)
                case None => ()
            }
        } finally {
            session.renderLock.unlock()
        }
    }

    private func doBind(sink: PageSink, state: SessionState, session: Session, fn: ActionHandler, value: String, aname: String): Unit {
        let params = HashMap<String, String>()
        params["value"] = value
        let flag = NavFlag()
        let router = Router("", { path => this.execNavAction(sink, state, session, flag, path) })
        let ctx = ActionContext(session.id, session.context, params, router, pushFn: { patches =>
            sinkSendJson(sink, PushMsg(patches))
        }, sessionStates: session.states, dom: Some(DomApi(this, sink, session)), sessionContext: session.sessionContext)
        try {
            match (fn(ctx)) {
                case PatchResult.ReRender =>
                    if (!flag.done) { this.sendPatch(sink, state, session) }
                case _ => ()
            }
        } catch (e: Exception) {
            state.page.onError(ErrorContext("", aname, e))
        }
    }

    private func execNavAction(sink: PageSink, state: SessionState, session: Session, flag: NavFlag, path: String): Unit {
        this.handleNavigate(sink, state, session, path)
        flag.done = true
    }

    private func handleNavigate(sink: PageSink, state: SessionState, session: Session, path: String): Unit {
        match (RouteRegistry.global().resolveGuard(path, session.context)) {
            case Some(target) =>
                // 拒绝导航并告知守卫指定的跳转目标，前端据此自动跳转
                sinkSendJson(sink, DenyMsg("无权限访问", path: target))
                return
            case None => ()
        }
        state.page.onUnmount(LifecycleContext("", HashMap<String, String>(), None, None))
        match (RouteRegistry.global().resolve(path)) {
            case Some(rm) => this.applyNav(sink, state, session, rm.component, path, rm.params)
            case None => ()
        }
    }

    private func applyNav(sink: PageSink, state: SessionState, session: Session, newPage: IComponent, path: String, routeParams: HashMap<String, String>): Unit {
        state.page = newPage
        state.path = path
        let mountCtx = LifecycleContext(session.id, routeParams, None, None, states: session.states, sessionContext: session.sessionContext)
        newPage.onMount(mountCtx)
        let tree = this.renderPageTree(session,
            { => RenderContext.expandTree(applyLayout(path, newPage.renderWithScope()), "") })
        session.refreshHandlers(tree)
        session.refreshRefs(tree)
        session.updatePage(newPage, tree)
        session.path = path
        // 导航后清理脏标记：旧页面实例（如登录页）的 markDirty 残留会在下次
        // sendPatch 被误渲染并整树替换（path="" 时 replace 整个页面）。
        // 所有渲染出口必须统一清理，否则残留脏组件污染后续增量补丁。
        // 只清本会话的：别的会话的更新由它自己的 sendPatch 处理
        RenderContext.clearDirtyForSession(session)
        println("cjxt-diag applyNav path=" + path + " sid=" + session.id + " treeBytes=" + serializeSubtree(tree, HashMap<String, ActionHandler>()).size.toString())
        sinkSendJson(sink, FullTreeMsg(tree, path: path))
        sendTitle(sink, path)
    }

    private func sendTitle(sink: PageSink, path: String): Unit {
        match (RouteRegistry.global().getTitle(path)) {
            case Some(t) => sinkSendJson(sink, TitleMsg(t))
            case None => ()
        }
    }

    private func sendPatch(sink: PageSink, state: SessionState, session: Session): Unit {
        App.sendPatchCount += 1
        // 只补丁本会话**当前页面树**上的组件：补丁路径是会话树内的位置，
        // 旧页面/其它会话的组件按同路径套用会替换掉本页面的节点
        let dirty = RenderContext.collectOwnedDirty(session)
        if (dirty.size == 0) { return }

        for (component in dirty) {
            let path = component.getPath()
            RenderContext.beginCapture(session.id)
            var expanded: IComponent = component
            try {
                // renderWithScope 直接返回渲染结果 VNode，嵌套组件的组件级事件
                // （Component.on）由 expandTree 的 Component 分支挂载；根组件的事件
                // 需在此挂载，否则 patch 后 data-action-* 丢失（如输入框回车失效）
                let newSubtree = match (component) {
                    case c: Component => attachComponentEvents(c, c.renderWithScope(path), path)
                    case _ => component.renderWithScope(path)
                }
                expanded = RenderContext.expandTree(newSubtree, path)
            } finally {
                // 本轮渲染出的组件接替该子树路径下的旧实例（旧实例退订作废）
                session.adoptSubtreeComponents(path, RenderContext.endCapture())
            }
            let json = serializeSubtree(expanded, HashMap<String, ActionHandler>())
            session.tree = RenderContext.replaceTreeAtPath(session.tree, path, expanded)

            let msg = "{\"kind\":\"patch\",\"trees\":[{\"op\":\"replace\",\"path\":\"${path}\",\"tree\":${json}}]}"
            sink.sendText(msg)
            // 已下发的组件清脏；未下发的（别的会话）留在队列里等各自会话处理
            component.clearDirty()
        }

        session.handlers.clear()
        RenderContext.collectHandlersFromTree(session.tree, session.handlers)
        session.refreshRefs(session.tree)
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

// ── 报文解析（全部按 **Rune** 索引）────────────────────────────────────
//
// 仓颉的 `String` 有两套下标语义，混用会炸：
//   - `s.size` / `s.indexOf(x)` 返回**字节**偏移；
//   - `s[i..j]` 切片要求 i、j 落在**字符边界**上。
// 于是 `s[i..(i+1)]` 这种"逐字节推进"的写法碰到多字节字符（中文等）
// 直接抛 `Invalid utf8 byte sequence`——ASCII 报文完全正常，一有中文就断，
// 且异常被上层 catch 吞掉后表现为"消息静默不分发"。
//
// 统一做法：先 `toRuneArray()`，之后 size/下标/比较全用字符序，比较用码点数值
// （`UInt32(r)`，避免 Rune 字面量的转义歧义）。拼接用 `String(runes[a..b])`。

let CH_QUOTE: UInt32 = 34
let CH_BACKSLASH: UInt32 = 92
let CH_LBRACE: UInt32 = 123
let CH_RBRACE: UInt32 = 125
let CH_COLON: UInt32 = 58
let CH_SPACE: UInt32 = 32
let CH_TAB: UInt32 = 9
let CH_LF: UInt32 = 10
let CH_CR: UInt32 = 13

func isJsonSpaceRune(r: Rune): Bool {
    let c = UInt32(r)
    c == CH_SPACE || c == CH_TAB || c == CH_LF || c == CH_CR
}

/// 在 runes 中从 `from` 起找字符 `ch` 的字符下标
func findRune(runes: Array<Rune>, ch: UInt32, from: Int64): Option<Int64> {
    var i = from
    while (i < runes.size) {
        if (UInt32(runes[i]) == ch) { return Some(i) }
        i += 1
    }
    None
}

/// 读 `"key": "value"` / `"key":"value"` 的字符串值（容忍冒号后空白）
private func readField(raw: String, field: String): String {
    let runes = raw.toRuneArray()
    match (findSubRunes(runes, "\"${field}\":")) {
        case Some(markStart) =>
            var from = markStart + "\"${field}\":".toRuneArray().size
            while (from < runes.size && isJsonSpaceRune(runes[from])) { from += 1 }
            if (from >= runes.size || UInt32(runes[from]) != CH_QUOTE) { return "" }
            match (findRune(runes, CH_QUOTE, from + 1)) {
                case Some(e) => String(runes[(from + 1)..e])
                case None => ""
            }
        case None => ""
    }
}

/// 在 runes 中找子串（按字符）；返回起始字符下标
func findSubRunes(runes: Array<Rune>, needle: String): Option<Int64> {
    let pat = needle.toRuneArray()
    if (pat.size == 0 || pat.size > runes.size) { return None }
    var i = 0
    while (i + pat.size <= runes.size) {
        var k = 0
        var matched = true
        while (k < pat.size) {
            if (UInt32(runes[i + k]) != UInt32(pat[k])) { matched = false; break }
            k += 1
        }
        if (matched) { return Some(i) }
        i += 1
    }
    None
}

func readBindValue(raw: String): String {
    // 与 readField 同款解析：`"value":"<值>"`，读到值结束引号为止。
    // （旧实现取到字符串末尾，导致值带引号/尾部字段，String 绑定靠 JSON
    // 反序列化巧合剥掉引号，而 Int64 等强类型绑定的 parse 直接抛异常崩连接）
    readField(raw, "value")
}

// 解析 action 消息中的 params 对象（前端所有参数值均为字符串，如按键信息）
// 解析 dom_result 的 results 对象：{"r1":"<值>",...} → HashMap
func readResults(raw: String): HashMap<String, String> {
    let result = HashMap<String, String>()
    let runes = raw.toRuneArray()
    match (findSubRunes(runes, "\"results\":{")) {
        case Some(start) =>
            let body = extractJsonObjectBodyRunes(runes, start + "\"results\":{".toRuneArray().size)
            if (body != "") { parseStringPairs(body, result) }
        case None => ()
    }
    result
}

func readActionParams(raw: String): HashMap<String, String> {
    let result = HashMap<String, String>()
    let runes = raw.toRuneArray()
    match (findSubRunes(runes, "\"params\":")) {
        case Some(start) =>
            var from = start + "\"params\":".toRuneArray().size
            while (from < runes.size && isJsonSpaceRune(runes[from])) { from += 1 }
            if (from < runes.size && UInt32(runes[from]) == CH_LBRACE) {
                let body = extractJsonObjectBodyRunes(runes, from + 1)
                if (body != "") { parseStringPairs(body, result) }
            }
        case None => ()
    }
    result
}

// 从指定起点提取匹配的 JSON 对象体（跳过字符串字面量，处理嵌套 {}）。
// 传入 runes 与**字符**下标（不是字节），返回值同为字符序切片。
func extractJsonObjectBodyRunes(runes: Array<Rune>, from: Int64): String {
    var depth: Int64 = 1
    var i = from
    while (i < runes.size) {
        let c = UInt32(runes[i])
        if (c == CH_LBRACE) {
            depth += 1
        } else if (c == CH_RBRACE) {
            depth -= 1
            if (depth == 0) {
                return String(runes[from..i])
            }
        } else if (c == CH_QUOTE) {
            i += 1
            while (i < runes.size) {
                let ic = UInt32(runes[i])
                if (ic == CH_BACKSLASH) {
                    i += 2
                } else if (ic == CH_QUOTE) {
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

// 解析 body 内所有 "key":"value" 键值对（值为字符串；跳过非字符串值）。
// 全程按 Rune 索引：值里出现中文才不会在切片处抛异常。
func parseStringPairs(body: String, out: HashMap<String, String>): Unit {
    let runes = body.toRuneArray()
    var i: Int64 = 0
    while (i < runes.size) {
        let q1 = match (findRune(runes, CH_QUOTE, i)) {
            case Some(x) => x
            case None => break
        }
        let q2 = match (findRune(runes, CH_QUOTE, q1 + 1)) {
            case Some(x) => x
            case None => break
        }
        let key = String(runes[(q1 + 1)..q2])
        // 跳过键后的空白与冒号
        var j = q2 + 1
        while (j < runes.size) {
            let c = UInt32(runes[j])
            if (c == CH_SPACE || c == CH_COLON || c == CH_TAB || c == CH_LF || c == CH_CR) { j += 1 } else { break }
        }
        if (j < runes.size && UInt32(runes[j]) == CH_QUOTE) {
            let vs = j + 1
            match (findRune(runes, CH_QUOTE, vs)) {
                case Some(ve) =>
                    out[key] = String(runes[vs..ve])
                    i = ve + 1
                case None => break
            }
        } else {
            i = j
        }
    }
}


// 上传结果（JSON 响应）
public struct UploadResult <: JsonSerializable {
    public let name: String
    public let url: String
    public let size: Int64

    public init(name: String, url: String, size: Int64) {
        this.name = name
        this.url = url
        this.size = size
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("name").writeValue(this.name)
        w.writeName("url").writeValue(this.url)
        w.writeName("size").writeValue(this.size)
        w.endObject()
    }
}


// 提取 key 后带引号的值（键以 \" 结尾，值到下一个 \" 为止）
func extractQuotedAfter(text: String, key: String): String {
    let runes = text.toRuneArray()
    match (findSubRunes(runes, key)) {
        case Some(start) =>
            let after = start + key.toRuneArray().size
            match (findRune(runes, CH_QUOTE, after)) {
                case Some(e) => String(runes[after..e])
                case None => ""
            }
        case None => ""
    }
}
