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

func renderPage(ctx: TangHttpContext, page: Component): Unit {
    let html = generateHtmlShell("demo")
    ctx.contentType("text/html; charset=utf-8").writeString(html)
}

func handleRoot(ctx: TangHttpContext): Unit {
    let pageOpt = RouteRegistry.global().create("/")
    match (pageOpt) {
        case Some(page) => renderPage(ctx, page)
        case None => ctx.contentType("text/plain; charset=utf-8").writeString("404")
    }
}

main() {
    let app = Tang()
    app.get("/", handleRoot)
    println("cjxt demo running on :8080")
    app.listen(8080)
}
