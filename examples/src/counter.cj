package examples

import cjxt.*
import cjxt.macros.*
import cjxt.components.*
import examples.showcase.*
import std.collection.HashMap

class CounterState <: AppState {
    var value = Signal<Int64>(0)
}

@Page["/", "Counter", noGuard, siteLayout]
class CounterPage <: Component {
    var state: CounterState

    public init() {
        this.state = CounterState()
    }

    public func onMount(ctx: LifecycleContext): Unit {
        this.state = ctx.getState<CounterState>()
    }

    public func render(): IComponent {
        let st = this.state
        let attrContainer = HashMap<String, String>([("class", cls("container"))])
        div([
            div([
                div([text("Global Counter")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
                div([text("${st.value.get()}")], attrs: Some(HashMap<String, String>([("class", cls("counter-value"))]))),
                div([
                DangerButton("-5").onClick({ ctx => st.value.set(st.value.get() - 5) }),
                DangerButton("-1").onClick({ ctx => st.value.set(st.value.get() - 1) }),
                PrimaryButton("+1").onClick({ ctx => st.value.set(st.value.get() + 1) }),
                PrimaryButton("+5").onClick({ ctx => st.value.set(st.value.get() + 5) }),
                ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
                div([text("每个 session 独立计数")], attrs: Some(HashMap<String, String>([("class", cls("desc"))]))),
            ], attrs: Some(HashMap<String, String>([("class", cls("card"))]))),
            div([text("cjxt v0.1")], attrs: Some(HashMap<String, String>([("class", cls("footer"))]))),
        ], attrs: Some(attrContainer))
    }
}

