package cjxt.demo

import cjxt.*
import cjxt.macros.*
import std.collection.HashMap
import std.convert.*

func needCount10(ctx: HashMap<String, String>): Bool {
    match (ctx.get("count")) {
        case Some(v) => (Int64.tryParse(v) ?? 0) >= 10
        case None => false
    }
}

@Page["/", "cjxt Counter"]
class HomePage <: Component {
    var count: Int64 = 0

    public func render(): ComponentNode {
        div(
            h1(text("cjxt Counter")),
            p(text("count: ${count}")),
            button(text("+")).onClick({ ctx =>
                this.count = this.count + 1
                ctx.context["count"] = "${this.count}"
                PatchResult.ReRender
            }),
            button(text("秘密页面")).onClick({ ctx =>
                ctx.router.push("/secret")
                PatchResult.ReRender
            })
        )
    }
}

@Page["/secret", "秘密页面", needCount10]
class SecretPage <: Component {
    public func render(): ComponentNode {
        div(
            h1(text("🔒 机密信息")),
            p(text("只有点够 10 次的人才能看到这里。")),
            button(text("返回")).onClick({ ctx =>
                ctx.router.push("/")
                PatchResult.ReRender
            })
        )
    }
}

@Page["/about", "关于 - cjxt"]
class AboutPage <: Component {
    public func render(): ComponentNode {
        div(
            h1(text("关于 cjxt")).style("color: #2c6b9e; font-family: sans-serif;"),
            p(text("服务端驱动 UI 框架，纯仓颉实现。")),
            button(text("返回")).onClick({ ctx =>
                ctx.router.push("/")
                PatchResult.ReRender
            })
        )
    }
}

main() {
    App().host("0.0.0.0").port(8080).serve()
}
