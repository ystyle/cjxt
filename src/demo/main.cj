package cjxt.demo

import cjxt.*
import cjxt.macros.*
import std.collection.HashMap
import std.convert.*

// ===== 全局 Store（模块级） =====
// 所有 session 共享同一个值。适用于：在线用户数、全局配置等。
let globalCount = Store<Int64>(0)

// ===== AppState =====
// 实现 AppState 空接口。框架按类型名自动注册每个 session 一个实例。
// 跨页面/跨组件共享，但只能通过 ctx.getState<T>() 在 action handler 中访问。
// render 阶段需要同步值的话，组件用 var 字段暂存，action 中同步。
class AppData <: AppState {
    var counter = Store<Int64>(0)
}

func needCount10(ctx: HashMap<String, String>): Bool {
    match (ctx.get("count")) {
        case Some(v) => (Int64.tryParse(v) ?? 0) >= 10
        case None => false
    }
}

func cardLayout(page: ComponentNode): ComponentNode {
    div(
        div(page).style("max-width: 600px; margin: 2em auto; padding: 2em; border: 1px solid #ddd; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1)")
    ).style("background: #f5f5f5; min-height: 100vh")
}

@Page["/", "cjxt Counter"]
class HomePage <: Component {
    var count: Int64 = 0
    var sessionCount: Int64 = 0

    public func render(): ComponentNode {
        div(
            h1(text("cjxt Counter")),
            p(text("count: ${this.count}")),
            p(text("global: ${globalCount.get()}")),
            p(text("session: ${this.sessionCount}")),
            button(text("+")).onClick({ ctx =>
                this.count = this.count + 1
                ctx.context["count"] = "${this.count}"
                PatchResult.ReRender
            }),
            button(text("global+")).onClick({ ctx =>
                globalCount.set({ v => v + 1 })
                PatchResult.ReRender
            }),
            button(text("session+")).onClick({ ctx =>
                let d = ctx.getState<AppData>()
                d.counter.set({ v => v + 1 })
                this.sessionCount = d.counter.get()
                PatchResult.ReRender
            }),
            button(text("关于")).onClick({ ctx =>
                ctx.router.push("/about")
                PatchResult.ReRender
            }),
            button(text("秘密页面")).onClick({ ctx =>
                ctx.router.push("/secret")
                PatchResult.ReRender
            })
        )
    }
}

@Page["/secret", "秘密页面", needCount10, cardLayout]
class SecretPage <: Component {
    public func render(): ComponentNode {
        div(
            h1(text("🔒 机密信息")),
            p(text("只有点够 10 次的人才能看到这里。")),
            p(text("global: ${globalCount.get()}")),
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
    App()
        .state<AppData>({ => AppData() })
        .host("0.0.0.0").port(8080).serve()
}
