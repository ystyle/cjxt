package examples

import cjxt.*
import cjxt.macros.*
import std.collection.HashMap

let css = @importCSS("style.css")
func cls(name: String): String { css.get(name) }

class CounterState <: AppState {
    var value = Signal<Int64>(0)
}

@Page["/"]
class CounterPage <: Component {
    var data: Option<CounterState> = None

    public func onMount(ctx: LifecycleContext): Unit {
        this.data = Some(ctx.getState<CounterState>())
    }

    public func render(): ComponentNode {
        let st = match (this.data) {
            case Some(s) => s
            case None => CounterState()
        }
        let attrContainer = HashMap<String, String>([("class", cls("container"))])
        div([
            renderTabs("/"),
            div([
                div([text("Global Counter")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
                div([text("${st.value.get()}")], attrs: Some(HashMap<String, String>([("class", cls("counter-value"))]))),
                div([
                btn("-5", "btn-outline", { ctx => let s = ctx.getState<CounterState>(); s.value.set(s.value.get() - 5); PatchResult.ReRender }),
                btn("-1", "btn-outline", { ctx => let s = ctx.getState<CounterState>(); s.value.set(s.value.get() - 1); PatchResult.ReRender }),
                btn("+1", "btn-primary", { ctx => let s = ctx.getState<CounterState>(); s.value.set(42); PatchResult.ReRender }),
                btn("+5", "btn-primary", { ctx => let s = ctx.getState<CounterState>(); s.value.set(s.value.get() + 5); PatchResult.ReRender }),
                ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
                div([text("每个 session 独立计数")], attrs: Some(HashMap<String, String>([("class", cls("desc"))]))),
            ], attrs: Some(HashMap<String, String>([("class", cls("card"))]))),
            div([text("cjxt v0.1")], attrs: Some(HashMap<String, String>([("class", cls("footer"))]))),
        ], attrs: Some(attrContainer))
    }
}

func renderTabs(active: String): ComponentNode {
    div([
        navTab("/", "Counter", active == "/"),
        navTab("/inputs", "Inputs", active == "/inputs"),
        navTab("/todo", "Todo", active == "/todo"),
    ], attrs: Some(HashMap<String, String>([("class", cls("tabs"))])))
}

func navTab(path: String, title: String, isActive: Bool): ComponentNode {
    let clsName = if (isActive) { cls("tab") + " " + cls("active") } else { cls("tab") }
    button(
        [text(title)],
        attrs: Some(HashMap<String, String>([("class", clsName)]))
    ).onClick({ ctx =>
        ctx.navigate(path)
        PatchResult.ReRender
    })
}

func btn(label: String, style: String, action: ActionHandler): ComponentNode {
    button([text(label)]).className(cls("btn") + " " + cls(style)).onClick(action)
}
