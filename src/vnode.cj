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

public struct VNode <: Component {
    let _tag: String
    let _attrs: Option<Attributes>
    let _children: Array<Component>
    let _key: Option<String>
    let _actions: Option<ActionMap>
    let _handlers: Option<HashMap<String, ActionHandler>>

    public init(tag: String, children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None, handlers!: Option<HashMap<String, ActionHandler>> = None) {
        this._tag = tag
        this._attrs = attrs
        this._children = children
        this._key = key
        this._actions = actions
        this._handlers = handlers
    }

    public func render(): Component { this }

    public func expand(): Component {
        let expanded = ArrayList<Component>()
        for (c in this._children) {
            expanded.add(c.expand())
        }
        VNode(this._tag, expanded.toArray(), attrs: this._attrs, key: this._key, actions: this._actions, handlers: this._handlers)
    }

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

    public func children(c: Array<Component>): VNode {
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
    // （Component 接口的默认实现通过 match 转发到这些）
}

// ============ TextNode ============

public struct TextNode <: Component {
    let _text: String

    public init(text: String) {
        this._text = text
    }

    public func render(): Component { this }

    public func expand(): Component { this }

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

public struct FragmentNode <: Component {
    let _children: Array<Component>

    public init(children: Array<Component>) {
        this._children = children
    }

    public func render(): Component { this }

    public func expand(): Component {
        let expanded = ArrayList<Component>()
        for (c in this._children) {
            expanded.add(c.expand())
        }
        FragmentNode(expanded.toArray())
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("type").writeValue("fragment")
        w.writeName("children").writeValue(this._children)
        w.endObject()
    }
}

// ============ EmptyNode ============

public struct EmptyNode <: Component {
    public init() {}

    public func render(): Component { this }

    public func expand(): Component { this }

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

public func div(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("div", children, attrs: attrs, key: key, actions: actions)
}

public func span(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("span", children, attrs: attrs, key: key, actions: actions)
}

public func button(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("button", children, attrs: attrs, key: key, actions: actions)
}

public func text(content: String): TextNode {
    TextNode(content)
}

public func input(attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("input", [], attrs: attrs, key: key, actions: actions)
}

public func h1(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("h1", children, attrs: attrs, key: key, actions: actions)
}

public func h2(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("h2", children, attrs: attrs, key: key, actions: actions)
}

public func h3(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("h3", children, attrs: attrs, key: key, actions: actions)
}

public func p(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("p", children, attrs: attrs, key: key, actions: actions)
}

public func form(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("form", children, attrs: attrs, key: key, actions: actions)
}

public func image(attrs!: Option<Attributes> = None, key!: Option<String> = None): VNode {
    VNode("image", [], attrs: attrs, key: key)
}

public func a(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("a", children, attrs: attrs, key: key, actions: actions)
}

public func ul(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("ul", children, attrs: attrs, key: key, actions: actions)
}

public func li(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("li", children, attrs: attrs, key: key, actions: actions)
}

public func Fragment(children: Array<Component>): FragmentNode {
    FragmentNode(children)
}

public func Empty(): EmptyNode {
    EmptyNode()
}

public func i(children: Array<Component>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): VNode {
    VNode("i", children, attrs: attrs, key: key, actions: actions)
}

public func cssStyle(content: String): VNode {
    let a = HashMap<String, String>()
    a["text"] = content
    VNode("style", [], attrs: Some(a))
}
