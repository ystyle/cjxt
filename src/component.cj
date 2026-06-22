package cjxt

import std.collection.HashMap
import std.reflect.*
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable, JsonDeserializable}

public type ActionHandler = (ActionContext) -> PatchResult

// 框架内部接口，match 用。自定义组件应继承 Component 类而非直接实现此接口
public interface IComponent <: JsonSerializable {
    func render(): IComponent
    func getComponentKey(): String { "" }

    // dirty 标记 + 路径追踪（默认空实现，Component 类覆写）
    func markDirty(): Unit { SignalTracker.pendingRender = true }
    func isDirty(): Bool { false }
    func clearDirty(): Unit {}
    func getPath(): String { "" }
    func setPath(p: String): Unit {}

    func reRender(): Unit {
        SignalTracker.pendingRender = true
    }

    func renderWithScope(path: String): IComponent {
        this.setPath(path)
        SignalTracker.enterScope({ => this.markDirty() })
        let tree = this.render()
        SignalTracker.exitScope()
        tree
    }

    func renderWithScope(): IComponent {
        this.renderWithScope("")
    }

    func getActions(): HashMap<String, ActionHandler> {
        HashMap<String, ActionHandler>()
    }

    func onMount(ctx: LifecycleContext): Unit {}
    func onUpdate(ctx: LifecycleContext): Unit {}
    func onUnmount(ctx: LifecycleContext): Unit {}
    func onError(ctx: ErrorContext): Unit {}

    // 默认序列化 — 内部类型直接序列化
    func toJson(w: JsonWriter): Unit {
        match (this) {
            case v: VNode => v.toJson(w)
            case t: TextNode => t.toJson(w)
            case f: FragmentNode => f.toJson(w)
            case e: EmptyNode => e.toJson(w)
            case _ => throw Exception("toJson on non-expanded component")
        }
    }

    // 收集 action handler
    func collectHandlers(out: HashMap<String, ActionHandler>): Unit {
        match (this) {
            case v: VNode => vnodeCollectHandlers(v, out)
            case f: FragmentNode => for (c in f._children) { c.collectHandlers(out) }
            case _ => ()
        }
    }
}

// 自定义组件的唯一基类。继承此类即可获得脏追踪、路径、事件注册等能力
public abstract class Component <: IComponent {
    var _dirty: Bool = false
    var _path: String = ""
    var _events = HashMap<String, ActionHandler>()

    public init() {}

    public func markDirty(): Unit {
        if (!this._dirty) {
            this._dirty = true
            SignalTracker.dirtyComponents.add(this)
        }
        SignalTracker.pendingRender = true
    }

    public func isDirty(): Bool { this._dirty }
    public func clearDirty(): Unit { this._dirty = false }
    public func getPath(): String { this._path }
    public func setPath(p: String): Unit { this._path = p }

    // 注册事件回调
    public func on(ev: String, h: ActionHandler): Component {
        this._events[ev] = h
        this
    }
}

public struct LifecycleContext {
    let sessionId: String
    public let routeParams: HashMap<String, String>
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
