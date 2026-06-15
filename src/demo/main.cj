package cjxt.demo

import cjxt.*
import tang.*
import stdx.net.http.{WebSocket, WebSocketFrameType}
import stdx.encoding.json.JsonValue
import std.collection.HashMap

var count: Int64 = 0

func handleRoot(ctx: TangHttpContext): Unit {
    ctx.contentType("text/html; charset=utf-8").writeString(generateHtmlShell("demo"))
}

func doSend(ws: WebSocket, s: String): Unit {
    ws.write(WebSocketFrameType.TextWebFrame, s.toArray())
}

func handleWS(ctx: TangHttpContext): Unit {
    let ws = ctx.upgrade()
    doSend(ws, "{\"type\":\"connected\"}")

    let tree = div([
        h1([text("cjxt Counter")], HashMap<String, String>(), None, HashMap<String, String>()),
        p([text("count: 0")], HashMap<String, String>(), None, HashMap<String, String>()),
        button([text("+")], HashMap<String, String>(), None, HashMap<String, String>())
    ], HashMap<String, String>(), None, HashMap<String, String>())

    let json = treeToJson(tree).toJsonString()
    doSend(ws, "{\"type\":\"patch\",\"patches\":[{\"op\":\"replace\",\"path\":\"\",\"value\":${json}}]}")

    while (true) {
        let frame = ws.read()
        if (frame.frameType == WebSocketFrameType.TextWebFrame) {
            count = count + 1
            let newTree = div([
                h1([text("cjxt Counter")], HashMap<String, String>(), None, HashMap<String, String>()),
                p([text("count: ${count}")], HashMap<String, String>(), None, HashMap<String, String>()),
                button([text("+")], HashMap<String, String>(), None, HashMap<String, String>())
            ], HashMap<String, String>(), None, HashMap<String, String>())
            doSend(ws, "{\"type\":\"patch\",\"patches\":[{\"op\":\"replace\",\"path\":\"\",\"value\":${treeToJson(newTree).toJsonString()}}]}")
        }
    }
}

main() {
    let app = Tang()
    app.get("/", handleRoot)
    app.get("/ws", handleWS)
    println("running...")
    app.listen(8080)
}
