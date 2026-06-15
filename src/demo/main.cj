package cjxt.demo

import cjxt.*
import cjxt.macros.*
import std.collection.HashMap

@Page["/"]
class HomePage <: Component {
    var count: Int64 = 0

    public func render(): ComponentNode {
        div([
            h1([text("cjxt Counter")]),
            p([text("count: ${count}")]),
            button([text("+")]).onClick("increment"),
            button([text("关于")]).onClick("goAbout")
        ])
    }

    public func getActions(): HashMap<String, ActionHandler> {
        HashMap<String, ActionHandler>([
            ("increment", { ctx => this.count = this.count + 1; PatchResult.ReRender }),
            ("goAbout", { ctx => ctx.router.push("/about"); PatchResult.ReRender })
        ])
    }
}

@Page["/about"]
class AboutPage <: Component {
    public func render(): ComponentNode {
        div([
            h1([text("关于 cjxt")]).style("color: #2c6b9e; font-family: sans-serif;"),
            p([text("服务端驱动 UI 框架，纯仓颉实现。")]),
            button([text("返回")]).onClick("goBack")
        ])
    }

    public func getActions(): HashMap<String, ActionHandler> {
        HashMap<String, ActionHandler>([
            ("goBack", { ctx => ctx.router.push("/"); PatchResult.ReRender })
        ])
    }
}

main() {
    App().host("0.0.0.0").port(8080).serve()
}
