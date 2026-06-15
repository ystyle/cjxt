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
        ctx.contentType("text/html; charset=utf-8").writeString(generateHtmlShell("app"))
    }

    private func upgradeWS(ctx: TangHttpContext): Unit {
        let ws = ctx.upgrade()
        match (RouteRegistry.global().create("/")) {
            case Some(page) => this.sessionLoop(ws, page)
            case None => ws.closeConn()
        }
    }

    private func sessionLoop(ws: WebSocket, page: Component): Unit {
        let state = SessionState(page)
        wsSendJson(ws, ConnectedMsg())
        let tree = page.render()
        state.refresh(tree)
        wsSendJson(ws, PatchMsg([PatchEntryMsg("replace", "", tree)]))
        this.readLoop(ws, state)
        state.page.onUnmount(LifecycleContext("", HashMap<String, String>(), None, None))
    }

    private func readLoop(ws: WebSocket, state: SessionState): Unit {
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
                    if (name != "") { this.dispatchAction(ws, state, name) }
                } else if (t == "navigate") {
                    let path = readField(raw, "path")
                    if (path != "") { this.handleNavigate(ws, state, path) }
                }
            } else if (frame.frameType == WebSocketFrameType.CloseWebFrame) {
                ws.writeCloseFrame()
                break
            }
        }
    }

    private func dispatchAction(ws: WebSocket, state: SessionState, name: String): Unit {
        match (state.actions.get(name)) {
            case Some(fn) => this.runAction(ws, state, name, fn)
            case None => match (state.handlers.get(name)) {
                case Some(fn) => this.runAction(ws, state, name, fn)
                case None => ()
            }
        }
    }

    private func runAction(ws: WebSocket, state: SessionState, name: String, fn: ActionHandler): Unit {
        let flag = NavFlag()
        let router = Router("", { path => this.execNavAction(ws, state, flag, path) })
        let ctx = ActionContext("", HashMap<String, String>(), router, pushFn: { patches =>
            wsSendJson(ws, PushMsg(patches))
        })
        try {
            match (fn(ctx)) {
                case PatchResult.ReRender => if (!flag.done) { this.sendPatch(ws, state) }
                case _ => ()
            }
        } catch (e: Error) {
            state.page.onError(ErrorContext("", name, e))
        }
    }

    private func execNavAction(ws: WebSocket, state: SessionState, flag: NavFlag, path: String): Unit {
        this.handleNavigate(ws, state, path)
        flag.done = true
    }

    private func handleNavigate(ws: WebSocket, state: SessionState, path: String): Unit {
        state.page.onUnmount(LifecycleContext("", HashMap<String, String>(), None, None))
        match (RouteRegistry.global().create(path)) {
            case Some(newPage) => applyNav(ws, state, newPage)
            case None => ()
        }
    }

    private func applyNav(ws: WebSocket, state: SessionState, newPage: Component): Unit {
        state.page = newPage
        state.actions = newPage.getActions()
        let tree = newPage.render()
        state.refresh(tree)
        wsSendJson(ws, FullTreeMsg(tree))
    }

    private func sendPatch(ws: WebSocket, state: SessionState): Unit {
        let tree = state.page.render()
        state.refresh(tree)
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
