package cjxt.demo

import cjxt.*
import cjxt.macros.*
import tang.{Tang, TangHttpContext}
import std.collection.HashMap

@Page["/"]
class IndexPage <: Component {
    var count: Int64 = 0

    public func render(): ComponentNode {
        let attrs = HashMap<String, String>()
        attrs["class"] = "counter"
        let dec = HashMap<String, String>()
        dec["click"] = "decrement"
        let inc = HashMap<String, String>()
        inc["click"] = "increment"

        div([
            h1([text("cjxt Counter")], HashMap<String, String>(), None, HashMap<String, String>()),
            div([
                button([text("-")], HashMap<String, String>(), None, dec),
                span([text("${count}")], HashMap<String, String>(), None, HashMap<String, String>()),
                button([text("+")], HashMap<String, String>(), None, inc)
            ], attrs, None, HashMap<String, String>())
        ], HashMap<String, String>(), None, HashMap<String, String>())
    }

    public func increment(ctx: ActionContext): PatchResult {
        this.count = this.count + 1
        PatchResult.ReRender
    }

    public func decrement(ctx: ActionContext): PatchResult {
        this.count = this.count - 1
        PatchResult.ReRender
    }
}

// ---- HTTP ----

func handleRoot(ctx: TangHttpContext): Unit {
    let html = generateHtmlShell("demo")
    ctx.contentType("text/html; charset=utf-8").writeString(html)
}

// ---- WebSocket ----

var globalPage: Option<IndexPage> = None
var globalTree: Option<ComponentNode> = None

func handleWS(ctx: TangHttpContext): Unit {
    let ws = ctx.upgrade()
    let page = IndexPage()
    var tree = page.render()

    globalPage = Some(page)
    globalTree = Some(tree)

    // 发送 connected + 初始 count
    wsSendText(ws, "{\"type\":\"connected\"}")
    wsSendText(ws, "{\"type\":\"patch\",\"patches\":[{\"op\":\"replace\",\"path\":\"\",\"value\":{\"type\":\"div\",\"children\":[{\"type\":\"h1\",\"children\":[{\"type\":\"text\",\"attrs\":{\"text\":\"cjxt Counter\"}}]},{\"type\":\"div\",\"attrs\":{\"class\":\"counter\"},\"children\":[{\"type\":\"button\",\"children\":[{\"type\":\"text\",\"attrs\":{\"text\":\"-\"}}],\"attrs\":{},\"actions\":{\"click\":\"decrement\"}},{\"type\":\"span\",\"children\":[{\"type\":\"text\",\"attrs\":{\"text\":\"${page.count}\"}}]},{\"type\":\"button\",\"children\":[{\"type\":\"text\",\"attrs\":{\"text\":\"+\"}}],\"attrs\":{},\"actions\":{\"click\":\"increment\"}}]}]}}]")

    while (true) {
        let msg = wsReadText(ws)
        if (msg.contains("action")) {
            let router = Router("demo", { p => () })
            let ctx = ActionContext("demo", HashMap<String, String>(), router)

            if (msg.contains("increment")) { page.increment(ctx) }
            else if (msg.contains("decrement")) { page.decrement(ctx) }

            let newTree = page.render()
            let patches = diffTree(tree, newTree, "")
            tree = newTree

            // 简化 patch 序列化
            var patchJson = "["
            for (i in 0..patches.size) {
                if (i > 0) { patchJson = patchJson + "," }
                let p = patches[i]
                patchJson = patchJson + "{\"op\":\"${p.op}\",\"path\":\"${p.path}\"}"
            }
            patchJson = patchJson + "]"

            wsSendText(ws, "{\"type\":\"patch\",\"patches\":${patchJson}}")
        }
    }
}

main() {
    let app = Tang()
    app.get("/", handleRoot)
    app.get("/ws", handleWS)
    println("cjxt demo running on :8080")
    app.listen(8080)
}
