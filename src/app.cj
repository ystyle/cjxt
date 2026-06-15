package cjxt

import std.collection.*
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
        this.tangApp.get("/", { ctx => renderHTTP(ctx) })
        this.tangApp.get("/ws", { ctx => upgradeWS(ctx) })
    }

    public func host(h: String): App {
        this.bindHost = h
        this
    }

    public func port(p: UInt16): App {
        this.bindPort = p
        this
    }

    public func serve(): Unit {
        tangApp.setHost(bindHost).setPort(bindPort).listen()
    }
}

func renderHTTP(ctx: TangHttpContext): Unit {
    ctx.contentType("text/html; charset=utf-8").writeString(generateHtmlShell("app"))
}

func upgradeWS(ctx: TangHttpContext): Unit {
    let ws = ctx.upgrade()
    let pageOpt = RouteRegistry.global().create("/")
    match (pageOpt) {
        case Some(page) => sessionLoop(ws, page)
        case None => ws.closeConn()
    }
}

func sessionLoop(ws: WebSocket, page: Component): Unit {
    wsSend(ws, "{\"type\":\"connected\"}")
    wsSend(ws, "{\"type\":\"patch\",\"patches\":[{\"op\":\"replace\",\"path\":\"\",\"value\":${treeToJson(page.render()).toJsonString()}}]}")

    let actions = page.getActions()
    readLoop(ws, page, actions)
}

func readLoop(ws: WebSocket, page: Component, actions: HashMap<String, ActionHandler>): Unit {
    while (true) {
        let frame = ws.read()
        if (frame.frameType == WebSocketFrameType.TextWebFrame) {
            let raw = String.fromUtf8(frame.payload)
            let name = parseAction(raw)
            if (name != "") {
                runAction(ws, page, actions, name)
            }
        } else if (frame.frameType == WebSocketFrameType.CloseWebFrame) {
            ws.writeCloseFrame()
            break
        }
    }
}

func runAction(ws: WebSocket, page: Component, actions: HashMap<String, ActionHandler>, name: String): Unit {
    let handlerOpt = actions.get(name)
    match (handlerOpt) {
        case Some(fn) => runHandler(ws, page, fn)
        case None => ()
    }
}

func runHandler(ws: WebSocket, page: Component, fn: ActionHandler): Unit {
    let router = Router("", { p => () })
    let ctx = ActionContext("", HashMap<String, String>(), router)
    let result = fn(ctx)
    applyResult(ws, page, result)
}

func applyResult(ws: WebSocket, page: Component, result: PatchResult): Unit {
    match (result) {
        case PatchResult.ReRender => sendPatch(ws, page)
        case _ => ()
    }
}

func sendPatch(ws: WebSocket, page: Component): Unit {
    let json = treeToJson(page.render()).toJsonString()
    wsSend(ws, "{\"type\":\"patch\",\"patches\":[{\"op\":\"replace\",\"path\":\"\",\"value\":${json}}]}")
}

func parseAction(msg: String): String {
    let mark = "\"name\":\""
    let start = msg.indexOf(mark)
    match (start) {
        case Some(idx) => readQuoted(msg, idx + mark.size)
        case None => ""
    }
}

func readQuoted(msg: String, from: Int64): String {
    let end = msg.indexOf("\"", from)
    match (end) {
        case Some(e) => msg[from..e]
        case None => ""
    }
}

func wsSend(ws: WebSocket, s: String): Unit {
    ws.write(WebSocketFrameType.TextWebFrame, s.toArray())
}
