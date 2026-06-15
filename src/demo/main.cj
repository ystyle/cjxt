package cjxt.demo

import cjxt.*
import cjxt.macros.*
import std.collection.HashMap

@Page["/"]
class HomePage <: Component {
    var count: Int64 = 0
    let acts = HashMap<String, String>([("click", "increment")])

    public func render(): ComponentNode {
        div([
            h1([text("cjxt Counter")]),
            p([text("count: ${count}")]),
            button([text("+")], actions: this.acts)
        ])
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
