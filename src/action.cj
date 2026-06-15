package cjxt

import std.collection.*

public enum PatchResult {
    | ReRender
    | Patch(Array<PatchEntry>)
}

public struct PatchEntry {
    let op: String
    let path: String
    let value: Option<String>
    let from: Option<String>

    public init(op: String, path: String, value: Option<String>, from: Option<String>) {
        this.op = op
        this.path = path
        this.value = value
        this.from = from
    }
}

public struct ActionContext {
    let sessionId: String
    let params: HashMap<String, String>
    let router: Router

    public init(sessionId: String, params: HashMap<String, String>, router: Router) {
        this.sessionId = sessionId
        this.params = params
        this.router = router
    }
}

public struct Router {
    let sessionId: String
    let navigateFn: (String) -> Unit

    public init(sessionId: String, navigateFn: (String) -> Unit) {
        this.sessionId = sessionId
        this.navigateFn = navigateFn
    }

    public func push(path: String): Unit {
        (this.navigateFn)(path)
    }
}
