package cjxt

import std.collection.HashMap
import std.reflect.*
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable, JsonDeserializable}

public type ActionHandler = (ActionContext) -> PatchResult

public interface Component <: JsonSerializable {
    func render(): Component
    func getComponentKey(): String { "" }

    func reRender(): Unit {
        SignalTracker.pendingRender = true
    }

    func renderWithScope(): Component {
        SignalTracker.enterScope({ => this.reRender() })
        let tree = this.render()
        SignalTracker.exitScope()
        tree
    }

    func getActions(): HashMap<String, ActionHandler> {
        HashMap<String, ActionHandler>()
    }

    func onMount(ctx: LifecycleContext): Unit {}
    func onUpdate(ctx: LifecycleContext): Unit {}
    func onUnmount(ctx: LifecycleContext): Unit {}
    func onError(ctx: ErrorContext): Unit {}

    // 默认序列化 — 内部类型直接序列化，用户组件通过 render() 展开
    func toJson(w: JsonWriter): Unit {
        match (this) {
            case v: VNode => v.toJson(w)
            case t: TextNode => t.toJson(w)
            case f: FragmentNode => f.toJson(w)
            case e: EmptyNode => e.toJson(w)
            case _ => this.render().toJson(w)
        }
    }

    // 收集 action handler
    func collectHandlers(out: HashMap<String, ActionHandler>): Unit {
        match (this) {
            case v: VNode => vnodeCollectHandlers(v, out)
            case f: FragmentNode => for (c in f._children) { c.collectHandlers(out) }
            case _ => this.render().collectHandlers(out)
        }
    }
}

public struct LifecycleContext {
    let sessionId: String
    let routeParams: HashMap<String, String>
    let componentKey: Option<String>
    let triggerAction: Option<String>
    let states: HashMap<String, AppState>

    public init(sessionId: String, routeParams: HashMap<String, String>, componentKey: Option<String>, triggerAction: Option<String>, states!: HashMap<String, AppState> = HashMap<String, AppState>()) {
        this.sessionId = sessionId
        this.routeParams = routeParams
        this.componentKey = componentKey
        this.triggerAction = triggerAction
        this.states = states
    }

    public func getState<T>(): T where T <: AppState {
        let key = TypeInfo.of<T>().qualifiedName
        match (this.states.get(key)) {
            case Some(s) => doGetState<T>(s)
            case None => throw Exception("AppState not registered: ${key}")
        }
    }
}

public struct ErrorContext {
    let sessionId: String
    let actionName: String
    let error: Error

    public init(sessionId: String, actionName: String, error: Error) {
        this.sessionId = sessionId
        this.actionName = actionName
        this.error = error
    }
}

func vnodeCollectHandlers(v: VNode, out: HashMap<String, ActionHandler>): Unit {
    match (v._handlers) {
        case Some(m) => doCollect(m, out)
        case None => ()
    }
    for (c in v._children) { c.collectHandlers(out) }
}

func doCollect(m: HashMap<String, ActionHandler>, out: HashMap<String, ActionHandler>): Unit {
    for ((k, v) in m) { out.add(k, v) }
}
