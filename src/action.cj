package cjxt

import std.collection.HashMap
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}

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
    let pushFn: (Array<PatchEntryMsg>) -> Unit

    public init(sessionId: String, params: HashMap<String, String>, router: Router, pushFn!: (Array<PatchEntryMsg>) -> Unit = { _ => () }) {
        this.sessionId = sessionId
        this.params = params
        this.router = router
        this.pushFn = pushFn
    }

    public func push(patches: Array<PatchEntryMsg>): Unit {
        (this.pushFn)(patches)
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

// ---- WS 协议消息类型 ----

public struct ConnectedMsg <: JsonSerializable {
    public init() {}

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("connected")
        w.endObject()
    }
}

public struct PatchEntryMsg <: JsonSerializable {
    let op: String
    let path: String
    let value: ComponentNode

    public init(op: String, path: String, value: ComponentNode) {
        this.op = op
        this.path = path
        this.value = value
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("op").writeValue(this.op)
        w.writeName("path").writeValue(this.path)
        w.writeName("value").writeValue(this.value)
        w.endObject()
    }
}

public struct PatchMsg <: JsonSerializable {
    let patches: Array<PatchEntryMsg>

    public init(patches: Array<PatchEntryMsg>) {
        this.patches = patches
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("patch")
        w.writeName("patches").writeValue(this.patches)
        w.endObject()
    }
}

public struct FullTreeMsg <: JsonSerializable {
    let tree: ComponentNode

    public init(tree: ComponentNode) {
        this.tree = tree
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("fullTree")
        w.writeName("tree")
        this.tree.toJson(w)
        w.endObject()
    }
}

public struct PushMsg <: JsonSerializable {
    let patches: Array<PatchEntryMsg>

    public init(patches: Array<PatchEntryMsg>) {
        this.patches = patches
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("push")
        w.writeName("patches").writeValue(this.patches)
        w.endObject()
    }
}

public struct TitleMsg <: JsonSerializable {
    let title: String

    public init(title: String) {
        this.title = title
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("title")
        w.writeName("title").writeValue(this.title)
        w.endObject()
    }
}
