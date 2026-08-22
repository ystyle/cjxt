package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

import std.io.{ByteBuffer, SeekPosition}
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable, JsonReader, JsonDeserializable}

func getTag(c: IComponent): String {
    match (c) { case v: VNode => v._tag; case t: TextNode => "text"; case _ => "unknown" }
}

func getVNode(c: IComponent): VNode {
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

    // handler id 稳定性：同一组件重复展开（模拟服务端重渲染），
    // 事件 handler id / bind id 必须保持不变，否则前端 DOM 的
    // data-action-* 属性会过期导致事件失效
    @TestCase
    public func testHandlerIdsStableAcrossRender(): Unit {
        let wrapper = Wrapper()
        let t1 = RenderContext.expandTree(wrapper, "")
        let t2 = RenderContext.expandTree(wrapper, "")
        @Expect(findFirstActionId(t1), findFirstActionId(t2))
    }

    @TestCase
    public func testHandlerIdPathScoped(): Unit {
        let wrapper = Wrapper()
        let t1 = RenderContext.expandTree(wrapper, "children/0")
        let t2 = RenderContext.expandTree(wrapper, "children/1")
        // 不同路径 → 不同 id（避免同页面多个节点共用同一 id）
        @Expect(findFirstActionId(t1) == findFirstActionId(t2), false)
    }

    @TestCase
    public func testBindIdStableAcrossRender(): Unit {
        let s = Signal<String>("")
        let node = input().bind(s)
        let e1 = RenderContext.expandTree(node, "children/0")
        let e2 = RenderContext.expandTree(node, "children/0")
        @Expect(getBindId(e1), getBindId(e2))
        // bind id 与 action id 必须不同（数据绑定 vs 事件）
        @Expect(getBindId(e1) == findFirstActionId(e1), false)
    }
}

func doCheckExpanded(c: IComponent): Unit {
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

func doCheckActionIds(expanded: IComponent): Unit {
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

// 找到树中第一个事件 action 的 handler id（用于稳定性断言）
func findFirstActionId(c: IComponent): String {
    match (c) {
        case v: VNode =>
            match (v._actions) {
                case Some(a) =>
                    for ((_, id) in a) { return id }
                    findFirstActionIdInChildren(v._children)
                case None => findFirstActionIdInChildren(v._children)
            }
        case f: FragmentNode => findFirstActionIdInChildren(f._children)
        case _ => ""
    }
}

func findFirstActionIdInChildren(children: Array<IComponent>): String {
    for (c in children) {
        let id = findFirstActionId(c)
        if (id != "") { return id }
    }
    ""
}

// 找出树的 data-bind-id 值
func getBindId(c: IComponent): String {
    match (c) {
        case v: VNode =>
            match (v._attrs) {
                case Some(m) => match (m.get("data-bind-id")) {
                    case Some(id) => id
                    case None => findFirstBindId(v._children)
                }
                case None => findFirstBindId(v._children)
            }
        case f: FragmentNode => findFirstBindId(f._children)
        case _ => ""
    }
}

func findFirstBindId(children: Array<IComponent>): String {
    for (c in children) {
        let id = getBindId(c)
        if (id != "") { return id }
    }
    ""
}

public class Wrapper <: Component {
    public init() {}
    public func render(): IComponent {
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
    // 对齐修复后的 readBindValue：value 是干净字符串（不含引号）
    let p = HashMap<String, String>([("value", "hello")])
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
