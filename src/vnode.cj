package cjxt

import std.collection.{HashMap, ArrayList}
import std.io.{ByteBuffer, SeekPosition}
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable, JsonReader, JsonDeserializable}

public type Attributes = HashMap<String, String>
public type ActionMap = HashMap<String, String>

let _hid = [0]
let _bid = [0]

func nextHid(): String {
    _hid[0] = _hid[0] + 1
    "_h${_hid[0]}"
}

func nextBid(): String {
    _bid[0] = _bid[0] + 1
    "_b${_bid[0]}"
}

// ============ VNode — HTML 元素 ============

public struct VNode <: IComponent {
    let _tag: String
    let _attrs: Option<Attributes>
    let _children: Array<IComponent>
    let _key: Option<String>
    let _actions: Option<ActionMap>
    let _handlers: Option<HashMap<String, ActionHandler>>

    public init(tag: String, children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None, handlers!: Option<HashMap<String, ActionHandler>> = None) {
        this._tag = tag
        this._attrs = attrs
        this._children = children
        this._key = key
        this._actions = actions
        this._handlers = handlers
    }

    public func render(): IComponent { this }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("type").writeValue(this._tag)
        w.writeName("attrs").writeValue(this._attrs)
        w.writeName("actions").writeValue(this._actions)
        w.writeName("children").writeValue(this._children)
        w.endObject()
    }

    // ---- 链式方法 ----

    public func attrs(m: HashMap<String, String>): VNode {
        VNode(this._tag, this._children, attrs: Some(m), key: this._key, actions: this._actions, handlers: this._handlers)
    }

    public func actions(m: HashMap<String, String>): VNode {
        VNode(this._tag, this._children, attrs: this._attrs, key: this._key, actions: Some(m), handlers: this._handlers)
    }

    public func children(c: Array<IComponent>): VNode {
        VNode(this._tag, c, attrs: this._attrs, key: this._key, actions: this._actions, handlers: this._handlers)
    }

    public func key(k: String): VNode {
        VNode(this._tag, this._children, attrs: this._attrs, key: Some(k), actions: this._actions, handlers: this._handlers)
    }

    public func onClick(name: String): VNode {
        let m = HashMap<String, String>()
        m["click"] = name
        this.actions(m)
    }

    public func onClick(h: Option<ActionHandler>): VNode {
        match (h) {
            case Some(hh) => this.onClick(hh)
            case None => this
        }
    }

    public func onClick(h: ActionHandler): VNode {
        let id = nextHid()
        let acts = HashMap<String, String>()
        acts["click"] = id
        let hmap = HashMap<String, ActionHandler>()
        hmap[id] = h
        VNode(this._tag, this._children, attrs: this._attrs, key: this._key, actions: Some(acts), handlers: Some(hmap))
    }

    // 泛用事件注册（合并已有 events/handlers）
    public func on(ev: String, h: ActionHandler): VNode {
        let id = nextHid()
        let acts = match (this._actions) {
            case Some(a) => doCloneActionMap(a)
            case None => HashMap<String, String>()
        }
        acts[ev] = id
        let hmap = match (this._handlers) {
            case Some(hh) => doCloneHandlerMap(hh)
            case None => HashMap<String, ActionHandler>()
        }
        hmap[id] = h
        VNode(this._tag, this._children, attrs: this._attrs, key: this._key, actions: Some(acts), handlers: Some(hmap))
    }

    public func bind<T>(signal: Signal<T>): VNode where T <: ToString & JsonDeserializable<T> {
        let id = nextBid()
        let attrs = addAttrItem(this._attrs, "data-bind-id", id)
        attrs["value"] = signal.get().toString()
        let handler: ActionHandler = { ctx =>
            let raw = match (ctx.params.get("value")) { case Some(v) => v case None => "" }
            let buf = ByteBuffer()
            let w = JsonWriter(buf)
            w.jsonValue(raw)
            w.flush()
            buf.flush()
            buf.seek(SeekPosition.Begin(0))
            let reader = JsonReader(buf)
            let parsed = reader.readValue<T>()
            signal.set(parsed)
            PatchResult.ReRender
        }
        let hmap = HashMap<String, ActionHandler>()
        hmap[id] = handler
        VNode(this._tag, this._children, attrs: Some(attrs), key: this._key, actions: this._actions, handlers: Some(hmap))
    }

    public func style(v: String): VNode {
        let m = HashMap<String, String>()
        m["style"] = v
        this.attrs(m)
    }

    public func className(v: String): VNode {
        let m = HashMap<String, String>()
        m["class"] = v
        this.attrs(m)
    }

    public func attr(k: String, v: String): VNode {
        let m = HashMap<String, String>()
        m[k] = v
        this.attrs(m)
    }
    // （IComponent 接口的默认实现通过 match 转发到这些）
}

// ============ TextNode ============

public struct TextNode <: IComponent {
    let _text: String

    public init(text: String) {
        this._text = text
    }

    public func render(): IComponent { this }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("type").writeValue("text")
        w.writeName("attrs")
        w.startObject()
        w.writeName("text").writeValue(this._text)
        w.endObject()
        w.endObject()
    }
}

// ============ FragmentNode ============

public struct FragmentNode <: IComponent {
    let _children: Array<IComponent>

    public init(children: Array<IComponent>) {
        this._children = children
    }

    public func render(): IComponent { this }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("type").writeValue("fragment")
        w.writeName("children").writeValue(this._children)
        w.endObject()
    }
}

// ============ EmptyNode ============

public struct EmptyNode <: IComponent {
    public init() {}

    public func render(): IComponent { this }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("type").writeValue("empty")
        w.endObject()
    }
}

// ============ 辅助函数 ============

func addAttrItem(existing: Option<HashMap<String, String>>, k: String, v: String): HashMap<String, String> {
    let m = match (existing) {
        case Some(mm) => let c = HashMap<String, String>(); for ((kk, vv) in mm) { c[kk] = vv }; c
        case None => HashMap<String, String>()
    }
    m[k] = v
    m
}

// 标签辅助函数

public func div(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("div", children, attrs: attrs, key: key, actions: actions)
}

public func span(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("span", children, attrs: attrs, key: key, actions: actions)
}

public func button(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("button", children, attrs: attrs, key: key, actions: actions)
}

public func text(content: String): TextNode {
    TextNode(content)
}

public func input(attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("input", [], attrs: attrs, key: key, actions: actions)
}

public func h1(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("h1", children, attrs: attrs, key: key, actions: actions)
}

public func h2(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("h2", children, attrs: attrs, key: key, actions: actions)
}

public func h3(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("h3", children, attrs: attrs, key: key, actions: actions)
}

public func p(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("p", children, attrs: attrs, key: key, actions: actions)
}

public func form(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("form", children, attrs: attrs, key: key, actions: actions)
}

public func image(attrs!: Option<Attributes> = None, key!: Option<String> = None): VNode {
    VNode("image", [], attrs: attrs, key: key)
}

public func a(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("a", children, attrs: attrs, key: key, actions: actions)
}

public func ul(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("ul", children, attrs: attrs, key: key, actions: actions)
}

public func li(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("li", children, attrs: attrs, key: key, actions: actions)
}

public func Fragment(children: Array<IComponent>): FragmentNode {
    FragmentNode(children)
}

public func Empty(): EmptyNode {
    EmptyNode()
}

public func i(children: Array<IComponent>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("i", children, attrs: attrs, key: key, actions: actions)
}

public func cssStyle(content: String): VNode {
    let a = HashMap<String, String>()
    a["text"] = content
    VNode("style", [], attrs: Some(a))
}

// ============ ClientComponentNode — 客户端组件节点 ============

public class ClientComponentNode <: IComponent {
    let _componentName: String
    let _props: HashMap<String, String>
    let _events: ArrayList<String>
    let _methods: ArrayList<String>
    var _handlers: HashMap<String, ActionHandler>
    var _componentId: String
    var _jsHash: String

    public init(componentName: String, props: HashMap<String, String>,
                events: ArrayList<String>, methods: ArrayList<String>) {
        this._componentName = componentName
        this._props = props
        this._events = events
        this._methods = methods
        this._handlers = HashMap<String, ActionHandler>()
        this._componentId = nextHid()
        this._jsHash = ""
    }

    public func jsHash(h: String): ClientComponentNode {
        this._jsHash = h
        this
    }

    public func on(eventName: String, h: ActionHandler): ClientComponentNode {
        this._handlers[eventName] = h
        this
    }

    public func getComponentId(): String { this._componentId }
    public func getComponentName(): String { this._componentName }

    public func render(): IComponent { this }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("type").writeValue("client:${this._componentName}")
        w.writeName("componentId").writeValue(this._componentId)
        w.writeName("jsHash").writeValue(this._jsHash)
        w.writeName("props").writeValue(this._props)
        w.writeName("events")
        w.startArray()
        for (e in this._events) { w.writeValue(e) }
        w.endArray()
        w.writeName("methods")
        w.startArray()
        for (m in this._methods) { w.writeValue(m) }
        w.endArray()
        w.endObject()
    }

    public func collectHandlers(out: HashMap<String, ActionHandler>): Unit {
        for ((k, v) in this._handlers) { out[k] = v }
    }
}

// ============ JSRegistry — 前端 JS 注册 ============

public class JSRegistry {
    static var _blobs: HashMap<String, String> = HashMap<String, String>()

    public static func register(name: String, js: String): Unit {
        _blobs[name] = js
    }

    public static func getJS(name: String): ?String {
        _blobs.get(name)
    }

    public static func all(): HashMap<String, String> { _blobs }
}

func doCloneActionMap(m: HashMap<String, String>): HashMap<String, String> {
    let c = HashMap<String, String>()
    for ((k, v) in m) { c[k] = v }
    c
}

func doCloneHandlerMap(m: HashMap<String, ActionHandler>): HashMap<String, ActionHandler> {
    let c = HashMap<String, ActionHandler>()
    for ((k, v) in m) { c[k] = v }
    c
}
