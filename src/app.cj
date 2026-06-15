package cjxt

import std.collection.HashMap
import stdx.net.http.{WebSocket, WebSocketFrameType}
import tang.{Tang, TangHttpContext}

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
        wsSendJson(ws, ConnectedMsg())
        wsSendJson(ws, PatchMsg([PatchEntryMsg("replace", "", page.render())]))
        this.readLoop(ws, page, page.getActions())
    }

    private func readLoop(ws: WebSocket, page: Component, actions: HashMap<String, ActionHandler>): Unit {
        while (true) {
            let frame = ws.read()
            if (frame.frameType == WebSocketFrameType.TextWebFrame) {
                let raw = String.fromUtf8(frame.payload)
                let name = parseName(raw)
                if (name != "") { this.doAction(ws, page, actions, name) }
            } else if (frame.frameType == WebSocketFrameType.CloseWebFrame) {
                ws.writeCloseFrame()
                break
            }
        }
    }

    private func doAction(ws: WebSocket, page: Component, actions: HashMap<String, ActionHandler>, name: String): Unit {
        match (actions.get(name)) {
            case Some(fn) => this.runAction(ws, page, fn)
            case None => ()
        }
    }

    private func runAction(ws: WebSocket, page: Component, fn: ActionHandler): Unit {
        let ctx = ActionContext("", HashMap<String, String>(), Router("", { p => () }))
        match (fn(ctx)) {
            case PatchResult.ReRender => this.sendPatch(ws, page)
            case _ => ()
        }
    }

    private func sendPatch(ws: WebSocket, page: Component): Unit {
        wsSendJson(ws, PatchMsg([PatchEntryMsg("replace", "", page.render())]))
    }
}

private func parseName(raw: String): String {
    let mark = "\"name\":\""
    match (raw.indexOf(mark)) {
        case Some(idx) => readStr(raw, idx + mark.size)
        case None => ""
    }
}

private func readStr(s: String, from: Int64): String {
    match (s.indexOf("\"", from)) {
        case Some(e) => s[from..e]
        case None => ""
    }
}
