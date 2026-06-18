package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class RenderContextTest {
    @TestCase
    public func testExpandTreeSimple(): Unit {
        let root = TestComponent("div", [text("hello")])
        let expanded = RenderContext.expandTree(root, "")
        match (expanded) {
            case v: VNode =>
                @Expect(v._tag, "div")
                @Expect(v._children.size, 1)
                match (v._children[0]) {
                    case t: TextNode => @Expect(t._text, "hello")
                    case _ => @Fail("expected text")
                }
            case _ => @Fail("expected VNode")
        }
    }

    @TestCase
    public func testExpandTreeAssignsPath(): Unit {
        let child = TestComponent("span", [text("ok")])
        let root = div([child])
        let expanded = RenderContext.expandTree(root, "")
        match (expanded) {
            case v: VNode =>
                match (v._children[0]) {
                    case span: VNode =>
                        @Expect(span._tag, "span")
                        @Expect(child._path, "children/0")
                    case _ => @Fail("expected VNode for span")
                }
            case _ => @Fail("expected VNode")
        }
    }

    @TestCase
    public func testExpandTreeNestedComponent(): Unit {
        let inner = TestComponent("b", [text("bold")])
        let wrapper = TestComponent("div", [inner])
        let expanded = RenderContext.expandTree(wrapper, "")
        match (expanded) {
            case v: VNode =>
                @Expect(v._tag, "div")
                match (v._children[0]) {
                    case b: VNode =>
                        @Expect(b._tag, "b")
                        @Expect(inner._path, "children/0")
                    case _ => @Fail("expected VNode for b")
                }
            case _ => @Fail("expected VNode")
        }
    }
}

class TestComponent <: BaseComponent {
    let tag: String
    let children: Array<Component>

    public init(tag: String, children: Array<Component>) {
        this.tag = tag
        this.children = children
    }

    public func render(): Component {
        VNode(this.tag, this.children)
    }
}
