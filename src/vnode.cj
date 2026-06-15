package cjxt

import std.collection.*
import std.io.ByteBuffer
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}

public enum ComponentType {
    | Div | Span | Button | Input | Form
    | Table | Text | Image | H1 | H2 | H3
    | P | Select | Textarea | A | Ul | Li
}

public type Attributes = HashMap<String, String>
public type ActionMap = HashMap<String, String>

extend ComponentType <: Equatable<ComponentType> {
    public operator func ==(other: ComponentType): Bool {
        match (this) {
            case Div => match (other) { case Div => true; case _ => false }
            case Span => match (other) { case Span => true; case _ => false }
            case Button => match (other) { case Button => true; case _ => false }
            case Input => match (other) { case Input => true; case _ => false }
            case Form => match (other) { case Form => true; case _ => false }
            case Table => match (other) { case Table => true; case _ => false }
            case Text => match (other) { case Text => true; case _ => false }
            case Image => match (other) { case Image => true; case _ => false }
            case H1 => match (other) { case H1 => true; case _ => false }
            case H2 => match (other) { case H2 => true; case _ => false }
            case H3 => match (other) { case H3 => true; case _ => false }
            case P => match (other) { case P => true; case _ => false }
            case Select => match (other) { case Select => true; case _ => false }
            case Textarea => match (other) { case Textarea => true; case _ => false }
            case A => match (other) { case A => true; case _ => false }
            case Ul => match (other) { case Ul => true; case _ => false }
            case Li => match (other) { case Li => true; case _ => false }
        }
    }
}

public struct ComponentNode {
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
        w.writeName("type").writeValue(typeToStr(this.typ))

        w.writeName("attrs")
        w.startObject()
        match (this.attrs) {
            case Some(m) => eachMap(w, m)
            case None => ()
        }
        w.endObject()

        w.writeName("actions")
        w.startObject()
        match (this.actions) {
            case Some(m) => eachMap(w, m)
            case None => ()
        }
        w.endObject()

        w.writeName("children")
        w.startArray()
        for (c in this.children) { c.toJson(w) }
        w.endArray()

        w.endObject()
    }

    public func toJsonString(): String {
        let buf = ByteBuffer()
        let w = JsonWriter(buf)
        this.toJson(w)
        String.fromUtf8(buf.bytes())
    }
}

func eachMap(w: JsonWriter, m: HashMap<String, String>): Unit {
    for ((k, v) in m) { w.writeName(k).writeValue(v) }
}

extend ComponentNode <: JsonSerializable {}

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

// ---- JSON 序列化辅助 ----

func typeToStr(t: ComponentType): String {
    match (t) {
        case Div => "div"; case Span => "span"; case Button => "button"
        case Input => "input"; case Form => "form"; case Table => "table"
        case Text => "text"; case Image => "image"; case H1 => "h1"
        case H2 => "h2"; case H3 => "h3"; case P => "p"
        case Select => "select"; case Textarea => "textarea"; case A => "a"
        case Ul => "ul"; case Li => "li"
    }
}

public func toJsonString(node: ComponentNode): String {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    node.toJson(w)
    String.fromUtf8(buf.bytes())
}
