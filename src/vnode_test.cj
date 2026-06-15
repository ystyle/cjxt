package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

func getAttr(node: ComponentNode, key: String): Option<String> {
    match (node.attrs) {
        case Some(m) => m.get(key)
        case None => None
    }
}

@Test
public class VnodeTest {
    @TestCase
    public func testCreateDiv(): Unit {
        let node = div()
        @Expect(node.typ, ComponentType.Div)
    }

    @TestCase
    public func testCreateText(): Unit {
        let node = text("hello")
        @Expect(node.typ, ComponentType.Text)
        @Expect(getAttr(node, "text"), Some("hello"))
    }

    @TestCase
    public func testDivWithChildren(): Unit {
        let node = div([
            h1([text("title")]),
            p([text("content")])
        ])
        @Expect(node.children.size, 2)
        @Expect(node.children[0].typ, ComponentType.H1)
        @Expect(node.children[1].typ, ComponentType.P)
    }

    @TestCase
    public func testButtonWithAction(): Unit {
        let acts = HashMap<String, String>([("click", "submit")])
        let node = button(actions: Some(acts))
        match (node.actions) {
            case Some(m) => @Expect(m.get("click"), Some("submit"))
            case None => @Fail("no actions")
        }
    }

    @TestCase
    public func testNestedStructure(): Unit {
        let node = div([
            ul([
                li([text("item1")]),
                li([text("item2")])
            ])
        ])
        @Expect(node.children[0].typ, ComponentType.Ul)
        @Expect(node.children[0].children.size, 2)
    }

    @TestCase
    public func testKeyAndAttrs(): Unit {
        let attrs = HashMap<String, String>([("class", "container"), ("id", "main")])
        let node = div([], attrs: Some(attrs), key: Some("root"))
        @Expect(node.key, Some("root"))
        let a = getAttr(node, "class")
        let b = getAttr(node, "id")
        @Expect(a, Some("container"))
        @Expect(b, Some("main"))
    }
}
