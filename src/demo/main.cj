package cjxt.demo

import cjxt.*
import cjxt.macros.*
import std.collection.HashMap

@Page["/"]
class HomePage <: Component {
    var count: Int64 = 0

    public func render(): ComponentNode {
        div([
            h1([text("cjxt Counter")], HashMap<String, String>(), None, HashMap<String, String>()),
            p([text("count: ${count}")], HashMap<String, String>(), None, HashMap<String, String>()),
            button([text("+")], HashMap<String, String>(), None, HashMap<String, String>())
        ], HashMap<String, String>(), None, HashMap<String, String>())
    }

    public func getActions(): HashMap<String, ActionHandler> {
        HashMap<String, ActionHandler>([
            ("increment", { ctx => this.count = this.count + 1; PatchResult.ReRender })
        ])
    }
}

main() {
    App().host("0.0.0.0").port(8080).serve()
}
