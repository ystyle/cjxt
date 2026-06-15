package cjxt

import std.collection.*

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
    let attrs: Attributes
    let children: Array<ComponentNode>
    let key: Option<String>
    let actions: ActionMap

    public init(typ: ComponentType, attrs: Attributes, children: Array<ComponentNode>, key: Option<String>, actions: ActionMap) {
        this.typ = typ
        this.attrs = attrs
        this.children = children
        this.key = key
        this.actions = actions
    }
}

public func div(children: Array<ComponentNode>, attrs: Attributes, key: Option<String>, actions: ActionMap): ComponentNode {
    ComponentNode(ComponentType.Div, attrs, children, key, actions)
}

public func span(children: Array<ComponentNode>, attrs: Attributes, key: Option<String>, actions: ActionMap): ComponentNode {
    ComponentNode(ComponentType.Span, attrs, children, key, actions)
}

public func button(children: Array<ComponentNode>, attrs: Attributes, key: Option<String>, actions: ActionMap): ComponentNode {
    ComponentNode(ComponentType.Button, attrs, children, key, actions)
}

public func text(content: String): ComponentNode {
    let attrs = HashMap<String, String>()
    attrs["text"] = content
    ComponentNode(ComponentType.Text, attrs, [], None, HashMap<String, String>())
}

public func h1(children: Array<ComponentNode>, attrs: Attributes, key: Option<String>, actions: ActionMap): ComponentNode {
    ComponentNode(ComponentType.H1, attrs, children, key, actions)
}

public func h2(children: Array<ComponentNode>, attrs: Attributes, key: Option<String>, actions: ActionMap): ComponentNode {
    ComponentNode(ComponentType.H2, attrs, children, key, actions)
}

public func p(children: Array<ComponentNode>, attrs: Attributes, key: Option<String>, actions: ActionMap): ComponentNode {
    ComponentNode(ComponentType.P, attrs, children, key, actions)
}

public func input(attrs: Attributes, key: Option<String>, actions: ActionMap): ComponentNode {
    ComponentNode(ComponentType.Input, attrs, [], key, actions)
}

public func form(children: Array<ComponentNode>, attrs: Attributes, key: Option<String>, actions: ActionMap): ComponentNode {
    ComponentNode(ComponentType.Form, attrs, children, key, actions)
}

public func image(attrs: Attributes, key: Option<String>): ComponentNode {
    ComponentNode(ComponentType.Image, attrs, [], key, HashMap<String, String>())
}

public func a(children: Array<ComponentNode>, attrs: Attributes, key: Option<String>, actions: ActionMap): ComponentNode {
    ComponentNode(ComponentType.A, attrs, children, key, actions)
}

public func ul(children: Array<ComponentNode>, attrs: Attributes, key: Option<String>, actions: ActionMap): ComponentNode {
    ComponentNode(ComponentType.Ul, attrs, children, key, actions)
}

public func li(children: Array<ComponentNode>, attrs: Attributes, key: Option<String>, actions: ActionMap): ComponentNode {
    ComponentNode(ComponentType.Li, attrs, children, key, actions)
}
