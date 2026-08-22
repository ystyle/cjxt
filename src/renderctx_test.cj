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

    /**
     * 回归：action 里 set 信号（如登录成功后 errorMsg.set("")）会标记组件脏；
     * 若该次 ReRender 被导航短路（flag.done，不调 sendPatch），脏标记必须由
     * 渲染出口（applyNav/初始渲染）的 clearDirty 清理——否则残留脏组件会在
     * 下次 sendPatch 被误渲染并整树替换（path="" 时 replace 整个页面，表现为
     * 页面突然变成登录页）。
     */
    @TestCase
    public func testStaleDirtyClearedOnRenderExit(): Unit {
        let probe = DirtyProbe()
        RenderContext.expandTree(probe, "")
        RenderContext.clearDirty()
        @Expect(SignalTracker.dirtyComponents.size, 0)

        // action 中 set 信号 → 订阅组件被标记脏
        probe.sig.set("done")
        @Expect(probe.isDirty(), true)
        @Expect(SignalTracker.dirtyComponents.size, 1)

        // 渲染出口清理残留（修复点）
        RenderContext.clearDirty()
        @Expect(probe.isDirty(), false)
        @Expect(SignalTracker.dirtyComponents.size, 0)

        // 后续增量补丁不再包含残留脏组件
        @Expect(RenderContext.collectDirty().size, 0)
    }
}

class TestComponent <: Component {
    let tag: String
    let children: Array<IComponent>

    public init(tag: String, children: Array<IComponent>) {
        this.tag = tag
        this.children = children
    }

    public func render(): IComponent {
        VNode(this.tag, this.children)
    }
}

/** 渲染时读取信号的探针组件（模拟登录页：render 读信号 → 订阅 markDirty） */
class DirtyProbe <: Component {
    var sig = Signal<String>("")

    public func render(): IComponent {
        let _ = this.sig.get()
        VNode("div", [])
    }
}
