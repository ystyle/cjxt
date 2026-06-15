package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class VnodeTest {
    @TestCase
    public func testCreateDiv(): Unit {
        let node = div([], HashMap<String, String>(), None, HashMap<String, String>())
        @Expect(node.typ, ComponentType.Div)
    }

    @TestCase
    public func testCreateText(): Unit {
        let node = text("hello")
        @Expect(node.typ, ComponentType.Text)
        @Expect(node.attrs.get("text"), Some("hello"))
    }

    @TestCase
    public func testDivWithChildren(): Unit {
        let node = div([
            h1([text("title")], HashMap<String, String>(), None, HashMap<String, String>()),
            p([text("content")], HashMap<String, String>(), None, HashMap<String, String>())
        ], HashMap<String, String>(), None, HashMap<String, String>())
        @Expect(node.children.size, 2)
        @Expect(node.children[0].typ, ComponentType.H1)
        @Expect(node.children[1].typ, ComponentType.P)
    }

    @TestCase
    public func testButtonWithAction(): Unit {
        let actions = HashMap<String, String>()
        actions["click"] = "submit"
        let node = button([], HashMap<String, String>(), None, actions)
        @Expect(node.actions.get("click"), Some("submit"))
    }

    @TestCase
    public func testNestedStructure(): Unit {
        let node = div([
            ul([
                li([text("item1")], HashMap<String, String>(), None, HashMap<String, String>()),
                li([text("item2")], HashMap<String, String>(), None, HashMap<String, String>())
            ], HashMap<String, String>(), None, HashMap<String, String>())
        ], HashMap<String, String>(), None, HashMap<String, String>())
        @Expect(node.children[0].typ, ComponentType.Ul)
        @Expect(node.children[0].children.size, 2)
    }

    @TestCase
    public func testKeyAndAttrs(): Unit {
        let attrs = HashMap<String, String>()
        attrs["class"] = "container"
        attrs["id"] = "main"
        let node = div([], attrs, Some("root"), HashMap<String, String>())
        @Expect(node.key, Some("root"))
        @Expect(node.attrs.get("class"), Some("container"))
        @Expect(node.attrs.get("id"), Some("main"))
    }
}
