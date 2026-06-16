package cjxt

import std.collection.HashMap
import std.reflect.*

public type ActionHandler = (ActionContext) -> PatchResult

public interface Component {
    func render(): ComponentNode
    func getComponentKey(): String { "" }

    func reRender(): Unit {
        SignalTracker.pendingRender = true
    }

    func renderWithScope(): ComponentNode {
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
