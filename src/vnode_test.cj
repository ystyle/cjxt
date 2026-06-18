package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

import std.io.{ByteBuffer, SeekPosition}
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable, JsonReader, JsonDeserializable}

func getTag(c: Component): String {
    match (c) { case v: VNode => v._tag; case t: TextNode => "text"; case _ => "unknown" }
}

func getVNode(c: Component): VNode {
    match (c) { case v: VNode => v; case _ => throw Exception("not VNode") }
}

func getAttr(node: VNode, key: String): Option<String> {
    match (node._attrs) {
        case Some(m) => m.get(key)
        case None => None
    }
}

func assertAction(node: VNode, key: String, expected: String): Unit {
    match (node._actions) {
        case Some(m) => @Expect(m.get(key), Some(expected))
        case None => @Fail("no actions")
    }
}

func assertAttr(node: VNode, key: String, expected: String): Unit {
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
        @Expect(node._tag, "div")
    }

    @TestCase
    public func testCreateText(): Unit {
        let t = text("hello")
        @Expect(t._text, "hello")
    }

    @TestCase
    public func testDivWithChildren(): Unit {
        let node = div([
            h1([text("title")]),
            p([text("content")])
        ])
        @Expect(node._children.size, 2)
        @Expect(getTag(node._children[0]), "h1")
        @Expect(getTag(node._children[1]), "p")
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
        @Expect(getTag(node._children[0]), "ul")
        @Expect(getVNode(node._children[0])._children.size, 2)
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
        match (node) {
            case v: VNode => doCheckBindAttrs(v)
            case _ => @Fail("not VNode")
        }
    }

    @TestCase
    public func testBindHandlerSetValue(): Unit {
        let s = Signal<String>("")
        let node = input().bind(s)
        match (node) {
            case v: VNode => doBindHandlerTest(v, s)
            case _ => @Fail("not VNode")
        }
    }
    @TestCase
    public func testExpandCustomComponent(): Unit {
        let wrapper = Wrapper()
        let expanded = RenderContext.expandTree(wrapper, "")
        doCheckExpanded(expanded)
    }

    @TestCase
    public func testExpandActionIdsConsistent(): Unit {
        let wrapper = Wrapper()
        let expanded = RenderContext.expandTree(wrapper, "")
        doCheckActionIds(expanded)
    }
}

func doCheckExpanded(c: Component): Unit {
    match (c) {
        case v: VNode => doCheckVNode(v)
        case _ => @Fail("expected VNode")
    }
}

func doCheckVNode(v: VNode): Unit {
    @Expect(v._tag, "div")
    @Expect(v._children.size, 1)
    match (v._children[0]) {
        case span: VNode => @Expect(span._tag, "span")
        case _ => @Fail("expected span")
    }
}

func doCheckActionIds(expanded: Component): Unit {
    let handlers = HashMap<String, ActionHandler>()
    expanded.collectHandlers(handlers)

    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    expanded.toJson(w)
    w.flush()
    buf.flush()
    let json = String.fromUtf8(buf.bytes())

    for ((id, _) in handlers) {
        if (!json.contains(id)) {
            @Fail("handler id ${id} not found in serialized json")
        }
    }
}

public class Wrapper <: BaseComponent {
    public init() {}
    public func render(): Component {
        div([span([text("hello")]).onClick({ _ => PatchResult.ReRender })])
    }
}

func doBindHandlerTest(node: VNode, s: Signal<String>): Unit {
    let bid = getAttr(node, "data-bind-id")
    match (bid) {
        case Some(id) => doTestBindHandler(node, s, id)
        case None => @Fail("no data-bind-id")
    }
}

func doTestBindHandler(node: VNode, s: Signal<String>, bid: String): Unit {
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

func doCheckBindAttrs(node: VNode): Unit {
    match (node._attrs) {
        case Some(m) => match (m.get("data-bind-id")) {
            case Some(id) => doCheckBindHandler(node, id)
            case None => @Fail("no data-bind-id attr")
        }
        case None => @Fail("no attrs")
    }
}

func doCheckBindHandler(node: VNode, id: String): Unit {
    match (node._handlers) {
        case Some(h) => match (h.get(id)) {
            case Some(_) => @Expect(true, true)
            case None => @Fail("bind handler not found")
        }
        case None => @Fail("no handlers")
    }
}
