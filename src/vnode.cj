package cjxt

import std.collection.HashMap
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}

public enum ComponentType <: ToString & Equatable<ComponentType> {
    | Div | Span | Button | Input | Form
    | Table | Text | Image | H1 | H2 | H3
    | P | Select | Textarea | A | Ul | Li

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
        }
    }

    public operator func ==(other: ComponentType): Bool {
        this.toString() == other.toString()
    }
}

public type Attributes = HashMap<String, String>
public type ActionMap = HashMap<String, String>

public struct ComponentNode <: JsonSerializable {
    let typ: ComponentType
    let attrs: Option<Attributes>
    let children: Array<ComponentNode>
    let key: Option<String>
    let actions: Option<ActionMap>

    public init(typ: ComponentType, children: Array<ComponentNode>, attrs!: Option<Attributes> = None, key!: Option<String> = None, actions!: Option<ActionMap> = None) {
        this.typ = typ
        this.attrs = attrs
        this.children = children
        this.key = key
        this.actions = actions
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("type").writeValue(this.typ.toString())
        w.writeName("attrs").writeValue(this.attrs)
        w.writeName("actions").writeValue(this.actions)
        w.writeName("children").writeValue(this.children)
        w.endObject()
    }
}

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
