package cjxt

import std.collection.HashMap
import stdx.net.http.{WebSocket, WebSocketFrameType}
import tang.{Tang, TangHttpContext}

class SessionState {
    var page: Component
    var actions: HashMap<String, ActionHandler>
    var handlers: HashMap<String, ActionHandler>

    public init(page: Component) {
        this.page = page
        this.actions = page.getActions()
        this.handlers = HashMap<String, ActionHandler>()
    }

    public func refresh(tree: ComponentNode): Unit {
        this.handlers = HashMap<String, ActionHandler>()
        collectHandlers(tree, this.handlers)
    }
}

public class App {
    let tangApp: Tang
    let sessions = SessionManager(300000)
    var bindHost: String
    var bindPort: UInt16

    public init() {
        this.tangApp = Tang()
        this.bindHost = "0.0.0.0"
        this.bindPort = 8080
    }

    public func host(h: String): App { this.bindHost = h; this }
    public func port(p: UInt16): App { this.bindPort = p; this }

    public func serve(): Unit {
        this.tangApp.get("/", { ctx => this.renderHTTP(ctx) })
        this.tangApp.get("/ws", { ctx => this.upgradeWS(ctx) })
        this.tangApp.setHost(this.bindHost).setPort(this.bindPort).listen()
    }

    private func renderHTTP(ctx: TangHttpContext): Unit {
        match (RouteRegistry.global().create("/")) {
            case Some(p) => servePage(ctx, p)
            case None => ctx.status(404).writeString("Not Found")
        }
    }

    private func servePage(ctx: TangHttpContext, p: Component): Unit {
        let tree = p.render()
        let session = sessions.create(p, tree)
        ctx.contentType("text/html; charset=utf-8").writeString(generateHtmlShell(session.id))
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
        session.touch()
        let state = SessionState(session.page)
        state.refresh(session.tree)
        wsSendJson(ws, ConnectedMsg())
        this.listenLoop(ws, state, session)
    }

    private func newSession(ws: WebSocket, sid: String): Unit {
        match (RouteRegistry.global().create("/")) {
            case Some(page) => startSession(ws, sid, page)
            case None => ws.closeConn()
        }
    }

    private func startSession(ws: WebSocket, sid: String, page: Component): Unit {
        let state = SessionState(page)
        let tree = page.render()
        state.refresh(tree)
        let session = sessions.save(sid, page, tree)
        wsSendJson(ws, ConnectedMsg())
        wsSendJson(ws, PatchMsg([PatchEntryMsg("replace", "", tree)]))
        this.listenLoop(ws, state, session)
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
                        state.page.onMount(LifecycleContext("", HashMap<String, String>(), None, None))
                    } else if (ev == "update") {
                        state.page.onUpdate(LifecycleContext("", HashMap<String, String>(), None, None))
                    }
                } else if (t == "action") {
                    let name = readField(raw, "name")
                    if (name != "") { this.dispatchAction(ws, state, session, name) }
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
        session.tree = state.page.render()
    }

    private func dispatchAction(ws: WebSocket, state: SessionState, session: Session, name: String): Unit {
        match (state.actions.get(name)) {
            case Some(fn) => this.runAction(ws, state, session, name, fn)
            case None => match (state.handlers.get(name)) {
                case Some(fn) => this.runAction(ws, state, session, name, fn)
                case None => ()
            }
        }
    }

    private func runAction(ws: WebSocket, state: SessionState, session: Session, name: String, fn: ActionHandler): Unit {
        let flag = NavFlag()
        let router = Router("", { path => this.execNavAction(ws, state, session, flag, path) })
        let ctx = ActionContext("", HashMap<String, String>(), router, pushFn: { patches =>
            wsSendJson(ws, PushMsg(patches))
        })
        try {
            match (fn(ctx)) {
                case PatchResult.ReRender => if (!flag.done) { this.sendPatch(ws, state, session) }
                case _ => ()
            }
        } catch (e: Error) {
            state.page.onError(ErrorContext("", name, e))
        }
    }

    private func execNavAction(ws: WebSocket, state: SessionState, session: Session, flag: NavFlag, path: String): Unit {
        this.handleNavigate(ws, state, session, path)
        flag.done = true
    }

    private func handleNavigate(ws: WebSocket, state: SessionState, session: Session, path: String): Unit {
        state.page.onUnmount(LifecycleContext("", HashMap<String, String>(), None, None))
        match (RouteRegistry.global().create(path)) {
            case Some(newPage) => applyNav(ws, state, session, newPage)
            case None => ()
        }
    }

    private func applyNav(ws: WebSocket, state: SessionState, session: Session, newPage: Component): Unit {
        state.page = newPage
        state.actions = newPage.getActions()
        let tree = newPage.render()
        state.refresh(tree)
        session.updatePage(newPage, tree)
        wsSendJson(ws, FullTreeMsg(tree))
    }

    private func sendPatch(ws: WebSocket, state: SessionState, session: Session): Unit {
        let tree = state.page.render()
        state.refresh(tree)
        session.tree = tree
        wsSendJson(ws, PatchMsg([PatchEntryMsg("replace", "", tree)]))
    }
}

class NavFlag {
    var done: Bool
    public init() { this.done = false }
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
