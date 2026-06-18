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

    @TestCase
    public func testCollectDirtyParentOverrideChild(): Unit {
        let parent = TestComponent("div", [])
        let child = TestComponent("span", [])
        parent._path = "children/0"
        child._path = "children/0/children/2"

        parent.markDirty()
        child.markDirty()

        let dirty = RenderContext.collectDirty()
        RenderContext.clearDirty()

        // 父覆盖子 — child 不应出现在结果中
        @Expect(dirty.size, 1)
        @Expect(dirty[0].getPath(), "children/0")
    }

    @TestCase
    public func testCollectDirtyIndependent(): Unit {
        let a = TestComponent("div", [])
        let b = TestComponent("span", [])
        a._path = "children/0"
        b._path = "children/1"

        a.markDirty()
        b.markDirty()

        let dirty = RenderContext.collectDirty()
        RenderContext.clearDirty()

        @Expect(dirty.size, 2)
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
