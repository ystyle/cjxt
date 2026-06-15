package cjxt

import std.collection.*

public type ActionHandler = (ActionContext) -> PatchResult

public interface Component {
    func render(): ComponentNode

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

    public init(sessionId: String, routeParams: HashMap<String, String>, componentKey: Option<String>, triggerAction: Option<String>) {
        this.sessionId = sessionId
        this.routeParams = routeParams
        this.componentKey = componentKey
        this.triggerAction = triggerAction
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
