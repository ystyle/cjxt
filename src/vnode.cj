package cjxt

import std.collection.HashMap
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}

public enum ComponentType <: ToString & Equatable<ComponentType> {
    | Div | Span | Button | Input | Form
    | Table | Text | Image | H1 | H2 | H3
    | P | Select | Textarea | A | Ul | Li | Style

    public func toString(): String {
        match (this) {
            case Div => "div"
            case Span => "span"
            case Button => "button"
            case Input => "input"
            case Form => "form"
            case Table => "table"
            case Text => "text"
            case Image => "image"
            case H1 => "h1"
            case H2 => "h2"
            case H3 => "h3"
            case P => "p"
            case Select => "select"
            case Textarea => "textarea"
            case A => "a"
            case Ul => "ul"
            case Li => "li"
            case Style => "style"
        }
    }

    public operator func ==(other: ComponentType): Bool {
        this.toString() == other.toString()
    }
}

public type Attributes = HashMap<String, String>
public type ActionMap = HashMap<String, String>

public struct ComponentNode <: JsonSerializable {
    let _typ: ComponentType
    let _attrs: Option<Attributes>
    let _children: Array<ComponentNode>
    let _key: Option<String>
    let _actions: Option<ActionMap>

    public init(typ: ComponentType, children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None) {
        this._typ = typ
        this._attrs = attrs
        this._children = children
        this._key = key
        this._actions = actions
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("type").writeValue(this._typ.toString())
        w.writeName("attrs").writeValue(this._attrs)
        w.writeName("actions").writeValue(this._actions)
        w.writeName("children").writeValue(this._children)
        w.endObject()
    }

    // ---- 链式方法 ----

    public func attrs(m: HashMap<String, String>): ComponentNode {
        ComponentNode(this._typ, this._children, attrs: Some(m), key: this._key, actions: this._actions)
    }

    public func actions(m: HashMap<String, String>): ComponentNode {
        ComponentNode(this._typ, this._children, attrs: this._attrs, key: this._key, actions: Some(m))
    }

    public func children(c: Array<ComponentNode>): ComponentNode {
        ComponentNode(this._typ, c, attrs: this._attrs, key: this._key, actions: this._actions)
    }

    public func key(k: String): ComponentNode {
        ComponentNode(this._typ, this._children, attrs: this._attrs, key: Some(k), actions: this._actions)
    }

    public func onClick(name: String): ComponentNode {
        let m = HashMap<String, String>()
        m["click"] = name
        this.actions(m)
    }

    public func style(v: String): ComponentNode {
        this.attr("style", v)
    }

    public func className(v: String): ComponentNode {
        this.attr("class", v)
    }

    public func attr(k: String, v: String): ComponentNode {
        let m = HashMap<String, String>()
        m[k] = v
        this.attrs(m)
    }
}

// ---- 标签辅助函数 ----

public func div(children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.Div, children, attrs: attrs, key: key, actions: actions)
}

public func span(children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.Span, children, attrs: attrs, key: key, actions: actions)
}

public func button(children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.Button, children, attrs: attrs, key: key, actions: actions)
}

public func text(content: String): ComponentNode {
    let a = HashMap<String, String>()
    a["text"] = content
    ComponentNode(ComponentType.Text, [], attrs: Some(a))
}

public func h1(children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.H1, children, attrs: attrs, key: key, actions: actions)
}

public func h2(children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.H2, children, attrs: attrs, key: key, actions: actions)
}

public func p(children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.P, children, attrs: attrs, key: key, actions: actions)
}

public func input(attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.Input, [], attrs: attrs, key: key, actions: actions)
}

public func form(children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.Form, children, attrs: attrs, key: key, actions: actions)
}

public func image(attrs!: Option<Attributes> = None, key!: Option<String> = None): ComponentNode {
    ComponentNode(ComponentType.Image, [], attrs: attrs, key: key)
}

public func a(children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.A, children, attrs: attrs, key: key, actions: actions)
}

public func ul(children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.Ul, children, attrs: attrs, key: key, actions: actions)
}

public func li(children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.Li, children, attrs: attrs, key: key, actions: actions)
}

public func cssStyle(content: String): ComponentNode {
    let a = HashMap<String, String>()
    a["text"] = content
    ComponentNode(ComponentType.Style, [], attrs: Some(a))
}
