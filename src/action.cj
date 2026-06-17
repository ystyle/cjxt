package cjxt

import std.collection.{HashMap, ArrayList}
import std.reflect.*
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}
import stdx.net.http.WebSocket

public interface AppState {}

func doGetState<T>(s: AppState): T where T <: AppState {
    match (s) {
        case t: T => t
        case _ => throw Exception("type mismatch for AppState")
    }
}

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

// 颗粒 patch（用于 diffTree，value 为字符串）
public struct TreePatchEntry <: JsonSerializable {
    let op: String
    let path: String
    let tree: Option<Component>

    public init(op: String, path: String, tree: Option<Component>) {
        this.op = op
        this.path = path
        this.tree = tree
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("op").writeValue(this.op)
        w.writeName("path").writeValue(this.path)
        match (this.tree) {
            case Some(t) => w.writeName("tree"); t.toJson(w)
            case None => ()
        }
        w.endObject()
    }
}

public enum GranularPatch {
    | AttrPatch(AttrPatchEntry)
    | SubtreePatch(TreePatchEntry)

    public func op(): String {
        match (this) {
            case GranularPatch.AttrPatch(a) => a.op
            case GranularPatch.SubtreePatch(t) => t.op
        }
    }
}

public func sendGranularPatch(ws: WebSocket, patches: ArrayList<GranularPatch>): Unit {
    if (patches.size == 0) { return }
    let attrs = ArrayList<AttrPatchEntry>()
    let trees = ArrayList<TreePatchEntry>()
    for (p in patches) {
        match (p) {
            case GranularPatch.AttrPatch(a) => attrs.add(a)
            case GranularPatch.SubtreePatch(t) => trees.add(t)
        }
    }
    wsSendJson(ws, CombinedPatchMsg(attrs.toArray(), trees.toArray()))
}

public struct AttrPatchEntry <: JsonSerializable {
    let op: String
    let path: String
    let value: Option<String>

    public init(op: String, path: String, value: Option<String>) {
        this.op = op
        this.path = path
        this.value = value
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("op").writeValue(this.op)
        w.writeName("path").writeValue(this.path)
        match (this.value) {
            case Some(v) => w.writeName("value").writeValue(v)
            case None => ()
        }
        w.endObject()
    }
}

public struct CombinedPatchMsg <: JsonSerializable {
    let attrs: Array<AttrPatchEntry>
    let trees: Array<TreePatchEntry>

    public init(attrs: Array<AttrPatchEntry>, trees: Array<TreePatchEntry>) {
        this.attrs = attrs
        this.trees = trees
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("patch")
        w.writeName("attrs").writeValue(this.attrs)
        w.writeName("trees").writeValue(this.trees)
        w.endObject()
    }
}

public struct ActionContext {
    let sessionId: String
    let context: HashMap<String, String>
    let params: HashMap<String, String>
    let router: Router
    let pushFn: (Array<PatchEntryMsg>) -> Unit
    let sessionStates: HashMap<String, AppState>

    public init(sessionId: String, context: HashMap<String, String>, params: HashMap<String, String>, router: Router, pushFn!: (Array<PatchEntryMsg>) -> Unit = { _ => () }, sessionStates!: HashMap<String, AppState> = HashMap<String, AppState>()) {
        this.sessionId = sessionId
        this.context = context
        this.params = params
        this.router = router
        this.pushFn = pushFn
        this.sessionStates = sessionStates
    }

    public func push(patches: Array<PatchEntryMsg>): Unit {
        (this.pushFn)(patches)
    }

    public func navigate(path: String): Unit {
        this.router.push(path)
    }

    public func getState<T>(): T where T <: AppState {
        let key = TypeInfo.of<T>().qualifiedName
        let raw = this.sessionStates.get(key)
        match (raw) {
            case Some(s) => doGetState<T>(s)
            case None => throw Exception("AppState not registered: ${key}")
        }
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
    let value: Component

    public init(op: String, path: String, value: Component) {
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
    let tree: Component

    public init(tree: Component) {
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

public struct DenyMsg <: JsonSerializable {
    let reason: String

    public init(reason: String) {
        this.reason = reason
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("deny")
        w.writeName("reason").writeValue(this.reason)
        w.endObject()
    }
}
