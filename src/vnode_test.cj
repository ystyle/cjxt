package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

func getAttr(node: ComponentNode, key: String): Option<String> {
    match (node._attrs) {
        case Some(m) => m.get(key)
        case None => None
    }
}

func assertAction(node: ComponentNode, key: String, expected: String): Unit {
    match (node._actions) {
        case Some(m) => @Expect(m.get(key), Some(expected))
        case None => @Fail("no actions")
    }
}

func assertAttr(node: ComponentNode, key: String, expected: String): Unit {
    match (node._attrs) {
        case Some(m) => @Expect(m.get(key), Some(expected))
        case None => @Fail("no attrs")
    }
}

@Test
public class VnodeTest {
    @TestCase
    public func testCreateDiv(): Unit {
        let node = div()
        @Expect(node._typ, ComponentType.Div)
    }

    @TestCase
    public func testCreateText(): Unit {
        let node = text("hello")
        @Expect(node._typ, ComponentType.Text)
        @Expect(getAttr(node, "text"), Some("hello"))
    }

    @TestCase
    public func testDivWithChildren(): Unit {
        let node = div([
            h1([text("title")]),
            p([text("content")])
        ])
        @Expect(node._children.size, 2)
        @Expect(node._children[0]._typ, ComponentType.H1)
        @Expect(node._children[1]._typ, ComponentType.P)
    }

    @TestCase
    public func testButtonWithAction(): Unit {
        let acts = HashMap<String, String>([("click", "submit")])
        let node = button(actions: acts)
        assertAction(node, "click", "submit")
    }

    @TestCase
    public func testNestedStructure(): Unit {
        let node = div([
            ul([
                li([text("item1")]),
                li([text("item2")])
            ])
        ])
        @Expect(node._children[0]._typ, ComponentType.Ul)
        @Expect(node._children[0]._children.size, 2)
    }

    @TestCase
    public func testKeyAndAttrs(): Unit {
        let attrs = HashMap<String, String>([("class", "container"), ("id", "main")])
        let node = div([], attrs: attrs, key: Some("root"))
        @Expect(node._key, Some("root"))
        assertAttr(node, "class", "container")
        assertAttr(node, "id", "main")
    }

    @TestCase
    public func testBindString(): Unit {
        let s = Signal<String>("")
        let node = input().bind(s)
        doCheckBindAttrs(node)
    }

    @TestCase
    public func testBindHandlerSetValue(): Unit {
        let s = Signal<String>("")
        let node = input().bind(s)
        let bid = getAttr(node, "data-bind-id")
        match (bid) {
            case Some(id) => doTestBindHandler(node, s, id)
            case None => @Fail("no data-bind-id")
        }
    }
}

func doTestBindHandler(node: ComponentNode, s: Signal<String>, bid: String): Unit {
    match (node._handlers) {
        case Some(h) => match (h.get(bid)) {
            case Some(fn) => doInvokeBind(fn, s)
            case None => @Fail("handler not found")
        }
        case None => @Fail("no handlers")
    }
}

func doInvokeBind(fn: ActionHandler, s: Signal<String>): Unit {
    let p = HashMap<String, String>([("value", "\"hello\"")])
    let ctx = ActionContext("", HashMap<String, String>(), p, Router("", { _ => () }))
    let r = fn(ctx)
    @Expect(s.get(), "hello")
    match (r) {
        case PatchResult.ReRender => @Expect(true, true)
        case _ => @Fail("expected ReRender")
    }
}

func doCheckBindAttrs(node: ComponentNode): Unit {
    match (node._attrs) {
        case Some(m) => match (m.get("data-bind-id")) {
            case Some(id) => doCheckBindHandler(node, id)
            case None => @Fail("no data-bind-id attr")
        }
        case None => @Fail("no attrs")
    }
}

func doCheckBindHandler(node: ComponentNode, id: String): Unit {
    match (node._handlers) {
        case Some(h) => match (h.get(id)) {
            case Some(_) => @Expect(true, true)
            case None => @Fail("bind handler not found")
        }
        case None => @Fail("no handlers")
    }
}
