package examples

import cjxt.*
import cjxt.macros.*
import cjxt.components.*
import std.collection.HashMap

let css = @importCSS("style.css")
func cls(name: String): String { css.get(name) }

class CounterState <: AppState {
    var value = Signal<Int64>(0)
}

@Page["/"]
class CounterPage <: Component {
    var state: CounterState

    public init() {
        this.state = CounterState()
    }

    public func onMount(ctx: LifecycleContext): Unit {
        this.state = ctx.getState<CounterState>()
    }

    public func render(): ComponentNode {
        let st = this.state
        let attrContainer = HashMap<String, String>([("class", cls("container"))])
        div([
            renderTabs("/"),
            div([
                div([text("Global Counter")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
                div([text("${st.value.get()}")], attrs: Some(HashMap<String, String>([("class", cls("counter-value"))]))),
                div([
                Button("-5", "danger", "default", false, false).onClick({ ctx => st.value.set(st.value.get() - 5); PatchResult.ReRender }),
                Button("-1", "danger", "default", false, false).onClick({ ctx => st.value.set(st.value.get() - 1); PatchResult.ReRender }),
                PrimaryButton("+1").onClick({ ctx => st.value.set(st.value.get() + 1); PatchResult.ReRender }),
                PrimaryButton("+5").onClick({ ctx => st.value.set(st.value.get() + 5); PatchResult.ReRender }),
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
