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

@Test
public class ComponentEventTest {
    @TestCase
    public func testComponentOnAttachedToRootVNode(): Unit {
        // Component.on(ev, h) 的事件必须挂到渲染结果根 VNode 的 actions/handlers
        // （此前 _events 只存不接，组件级事件全部失效）
        let clicked = EventProbe()
        let comp = EventComponent(clicked)
        let expanded = RenderContext.expandTree(comp, "")
        match (expanded) {
            case v: VNode =>
                match (v._actions) {
                    case Some(a) =>
                        @Expect(a.get("click").isSome(), true)
                        let id = a.get("click").getOrThrow()
                        @Expect(id.contains("click"), true)
                        match (v._handlers) {
                            case Some(h) =>
                                @Expect(h.get(id).isSome(), true)
                            case None => @Fail("no handlers")
                        }
                    case None => @Fail("no actions")
                }
            case _ => @Fail("expected VNode")
        }
        @Expect(clicked.count, 0)
    }

    @TestCase
    public func testComponentEventStableIdAcrossRenders(): Unit {
        // 重渲染（同一路径展开两次）后事件 id 不变（路径派生）
        let clicked = EventProbe()
        let comp = EventComponent(clicked)
        let first = RenderContext.expandTree(comp, "")
        let second = RenderContext.expandTree(comp, "")
        let id1 = extractClickId(first)
        let id2 = extractClickId(second)
        @Expect(id1 != "", true)
        @Expect(id1 == id2, true)
    }

    func extractClickId(node: IComponent): String {
        match (node) {
            case v: VNode =>
                match (v._actions) {
                    case Some(a) =>
                        match (a.get("click")) {
                            case Some(id) => id
                            case None => ""
                        }
                    case None => ""
                }
            case _ => ""
        }
    }

    @TestCase
    public func testNoEventsKeepsNodeUntouched(): Unit {
        let comp = TestComponent("div", [text("x")])
        let expanded = RenderContext.expandTree(comp, "")
        match (expanded) {
            case v: VNode => @Expect(v._actions.isNone(), true)
            case _ => @Fail("expected VNode")
        }
    }
}

class EventProbe {
    var count: Int64 = 0

    public func bump(): Unit {
        this.count++
    }
}

class EventComponent <: Component {
    let probe: EventProbe

    public init(probe: EventProbe) {
        this.probe = probe
        this.on("click", { ctx =>
            this.probe.bump()
            PatchResult.ReRender
        })
    }

    public func render(): IComponent {
        VNode("div", [text("evt")])
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
