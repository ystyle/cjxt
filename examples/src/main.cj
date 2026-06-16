package examples

import cjxt.*
import cjxt.macros.*
import std.collection.{ArrayList, HashMap}
import std.convert.*

let STYLE = """
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f0f2f5; color: #333; min-height: 100vh; }
.container { max-width: 640px; margin: 0 auto; padding: 24px 16px; }
.tabs { display: flex; gap: 0; background: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.08); margin-bottom: 20px; }
.tab { flex: 1; padding: 14px 20px; text-align: center; border: none; background: transparent; font-size: 15px; font-weight: 500; cursor: pointer; color: #666; transition: all 0.15s; }
.tab.active { color: #4f46e5; background: #f5f3ff; box-shadow: inset 0 -2px 0 #4f46e5; }
.card { background: #fff; border-radius: 12px; padding: 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); margin-bottom: 16px; }
.card-title { font-size: 16px; font-weight: 600; color: #111; margin-bottom: 16px; }
.counter-value { font-size: 48px; font-weight: 700; color: #4f46e5; text-align: center; padding: 20px 0; }
.row { display: flex; gap: 8px; }
.btn { padding: 10px 20px; border: none; border-radius: 8px; font-size: 14px; font-weight: 500; cursor: pointer; transition: all 0.12s; }
.btn-primary { background: #4f46e5; color: #fff; }
.btn-outline { background: transparent; border: 1px solid #d1d5db; color: #374151; }
.btn-sm { padding: 6px 12px; font-size: 13px; }
.btn-danger { background: #fee2e2; color: #dc2626; }
.input { flex: 1; padding: 10px 14px; border: 1px solid #d1d5db; border-radius: 8px; font-size: 14px; outline: none; }
.input:focus { border-color: #4f46e5; box-shadow: 0 0 0 3px rgba(79,70,229,0.1); }
.label { font-size: 13px; font-weight: 500; color: #6b7280; margin-bottom: 6px; }
.desc { font-size: 13px; color: #9ca3af; margin-top: 4px; }
.todo-item { display: flex; align-items: center; gap: 12px; padding: 10px 0; border-bottom: 1px solid #f3f4f6; }
.todo-text { flex: 1; font-size: 14px; color: #333; }
.todo-empty { text-align: center; color: #9ca3af; padding: 40px 0; font-size: 14px; }
.footer { text-align: center; font-size: 12px; color: #d1d5db; margin-top: 24px; }
"""

class TabState <: AppState {
    var active = Signal<String>("counter")
    var globalCount = Store<Int64>(0)
    var bindText = Signal<String>("")
}

@Page["/"]
class ExampleApp <: Component {
    var data: Option<TabState> = None

    public func onMount(ctx: LifecycleContext): Unit {
        this.data = Some(ctx.getState<TabState>())
    }

    public func render(): ComponentNode {
        let d = match (this.data) {
            case Some(dd) => dd
            case None => TabState()
        }
        let tab = d.active.get()
        let tabContent = match (tab) {
            case "counter" => renderCounter(d)
            case "todo" => renderTodo(d)
            case _ => div([])
        }
        div(
            cssStyle(STYLE),
            renderTabs(d, tab),
            tabContent,
            div([text("cjxt v0.1")], attrs: Some(HashMap<String, String>([("class", "footer")]))),
        attrs: Some(HashMap<String, String>([("class", "container")]))
    )
}
}

func renderTabs(d: TabState, active: String): ComponentNode {
    div(
        renderTab("counter", "Counter", active == "counter", d),
        renderTab("todo", "Todo", active == "todo", d),
        attrs: Some(HashMap<String, String>([("class", "tabs")]))
    )
}

func renderTab(key: String, title: String, isActive: Bool, d: TabState): ComponentNode {
    let cls = if (isActive) { "tab active" } else { "tab" }
    button(
        [text(title)],
        attrs: Some(HashMap<String, String>([("class", cls)]))
    ).onClick({ ctx =>
        d.active.set(key)
        PatchResult.ReRender
    })
}

func renderCounter(d: TabState): ComponentNode {
    div(
        div(
            div([text("Global Counter")], attrs: Some(HashMap<String, String>([("class", "card-title")]))),
            div([text("${d.globalCount.get()}")], attrs: Some(HashMap<String, String>([("class", "counter-value")]))),
            div(
                button([text("-5")], attrs: Some(HashMap<String, String>([("class", "btn btn-outline")]))).onClick({ ctx =>
                    d.globalCount.set({ v => v - 5 })
                    PatchResult.ReRender
                }),
                button([text("-1")], attrs: Some(HashMap<String, String>([("class", "btn btn-outline")]))).onClick({ ctx =>
                    d.globalCount.set({ v => v - 1 })
                    PatchResult.ReRender
                }),
                button([text("+1")], attrs: Some(HashMap<String, String>([("class", "btn btn-primary")]))).onClick({ ctx =>
                    d.globalCount.set({ v => v + 1 })
                    PatchResult.ReRender
                }),
                button([text("+5")], attrs: Some(HashMap<String, String>([("class", "btn btn-primary")]))).onClick({ ctx =>
                    d.globalCount.set({ v => v + 5 })
                    PatchResult.ReRender
                }),
                attrs: Some(HashMap<String, String>([("class", "row")]))
            ),
            attrs: Some(HashMap<String, String>([("class", "card")]))
        ),
        div(
            div([text("Input Bind")], attrs: Some(HashMap<String, String>([("class", "card-title")]))),
            div([text("输入内容")], attrs: Some(HashMap<String, String>([("class", "label")]))),
            input(attrs: Some(HashMap<String, String>([("class", "input"), ("placeholder", "输入文字实时回显...")]))).bind(d.bindText),
            div([text("实时回显: ${d.bindText.get()}")], attrs: Some(HashMap<String, String>([("class", "desc")]))),
            attrs: Some(HashMap<String, String>([("class", "card")]))
        ),
        div(
            div([text("关于 cjxt")], attrs: Some(HashMap<String, String>([("class", "card-title")]))),
            div([text("切换到 Todo 标签页查看待办列表示例。")], attrs: Some(HashMap<String, String>([("class", "desc")]))),
            div([text("框架特性: Signal / Store / AppState / 数据绑定 / 路由守卫")], attrs: Some(HashMap<String, String>([("class", "desc")]))),
            attrs: Some(HashMap<String, String>([("class", "card")]))
        ),
        attrs: Some(HashMap<String, String>([("class", "container")]))
    )
}

func renderTodo(d: TabState): ComponentNode {
    div(
        div(
            div([text("添加待办")], attrs: Some(HashMap<String, String>([("class", "card-title")]))),
            div(
                input(attrs: Some(HashMap<String, String>([("class", "input"), ("placeholder", "输入待办事项...")]))).bind(d.bindText),
                button([text("添加")], attrs: Some(HashMap<String, String>([("class", "btn btn-primary")]))).onClick({ ctx =>
                    let item = d.bindText.get()
                    if (item != "") {
                        d.bindText.set("")
                    }
                    PatchResult.ReRender
                }),
                attrs: Some(HashMap<String, String>([("class", "row")]))
            ),
            attrs: Some(HashMap<String, String>([("class", "card")]))
        ),
        div(
            div([text("待办列表")], attrs: Some(HashMap<String, String>([("class", "card-title")]))),
            div([text("TODO: 待办功能实现中")], attrs: Some(HashMap<String, String>([("class", "todo-empty")]))),
            attrs: Some(HashMap<String, String>([("class", "card")]))
        ),
        attrs: Some(HashMap<String, String>([("class", "container")]))
    )
}
