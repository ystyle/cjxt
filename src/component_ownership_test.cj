package cjxt

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

// 组件归属（页面树）语义：
//   ① 换页后旧页面的组件必须退订——否则共享信号一变，它就按旧路径把旧页面内容
//      补丁进新页面（同路径节点被覆盖）；
//   ② 补丁只认本会话当前树上的组件——别的会话的脏标记不得套用本树路径，
//      也不得被顺手清掉（清掉就是丢更新）；
//   ③ 就地重渲时组件重新订阅的依赖不能被归属登记顺手解除。
class OwnerProbeCell <: Component {
    let sig: Signal<String>
    public init(sig: Signal<String>) {
        this.sig = sig
    }
    public func render(): IComponent {
        text("cell:" + this.sig.get())
    }
}

class OwnerProbePage <: Component {
    let sig: Signal<String>
    let cell: OwnerProbeCell
    public init(sig: Signal<String>) {
        this.sig = sig
        this.cell = OwnerProbeCell(sig)
    }
    public func render(): IComponent {
        div([text("head"), div([this.cell])])
    }
}

class OwnerProbeLeaf <: Component {
    let sig: Signal<String>
    public init(sig: Signal<String>) {
        this.sig = sig
    }
    public func render(): IComponent {
        text("leaf:" + this.sig.get())
    }
}

// 每次渲染都新建子组件（组件实例不跨渲染复用）——用来验证子树补丁的归属接管
class OwnerProbeParent <: Component {
    let sig: Signal<String>
    var child: OwnerProbeLeaf
    public init(sig: Signal<String>) {
        this.sig = sig
        this.child = OwnerProbeLeaf(sig)
    }
    public func render(): IComponent {
        let c = OwnerProbeLeaf(this.sig)
        this.child = c
        div([text("parent"), c])
    }
}

func ownerProbeRenderPage(session: Session, page: IComponent): IComponent {
    RenderContext.beginCapture(session.id)
    var tree: IComponent = text("")
    try {
        tree = RenderContext.expandTree(page.renderWithScope(), "")
    } finally {
        session.adoptPageComponents(RenderContext.endCapture())
    }
    tree
}

func ownerProbeRenderSubtree(session: Session, comp: Component, path: String): IComponent {
    RenderContext.beginCapture(session.id)
    var tree: IComponent = text("")
    try {
        tree = RenderContext.expandTree(comp.renderWithScope(path), path)
    } finally {
        session.adoptSubtreeComponents(path, RenderContext.endCapture())
    }
    tree
}

func ownerProbeDirtyContains(c: Component): Bool {
    for (x in SignalTracker.dirtyComponents) {
        if (x.uid() == c.uid()) { return true }
    }
    false
}

@Test
public class ComponentOwnershipTest {
    @TestCase
    public func testPageSwapDisposesOldPageComponents(): Unit {
        RenderContext.clearDirty()
        let sig = Signal<String>("s0")
        let session = Session("owner-t-1", text(""), text(""))
        let pageA = OwnerProbePage(sig)
        ownerProbeRenderPage(session, pageA)
        @Expect(session.ownsComponent(pageA.cell), true)

        // 换页：旧页面的嵌套组件必须退订
        let pageB = OwnerProbeLeaf(Signal<String>("other"))
        ownerProbeRenderPage(session, pageB)
        @Expect(session.ownsComponent(pageA.cell), false)
        @Expect(session.ownsComponent(pageB), true)

        // 旧组件的信号变化不再产生脏标记（否则会按旧路径补丁进新页面）
        sig.set("s1")
        @Expect(ownerProbeDirtyContains(pageA.cell), false)
        @Expect(pageA.cell.isDirty(), false)
        RenderContext.clearDirty()
    }

    @TestCase
    public func testForeignSessionComponentNotPickedAndNotCleared(): Unit {
        RenderContext.clearDirty()
        let sig = Signal<String>("v0")
        let sessionA = Session("owner-t-a", text(""), text(""))
        let sessionB = Session("owner-t-b", text(""), text(""))
        let pageA = OwnerProbeLeaf(sig)
        ownerProbeRenderPage(sessionA, pageA)

        sig.set("v1")
        @Expect(pageA.isDirty(), true)

        // B 取补丁：A 的组件不属于 B 的树 → 不下发
        let pickedForB = RenderContext.collectOwnedDirty(sessionB)
        @Expect(pickedForB.size, 0)
        // 也不得被顺手清掉：A 的更新只能由 A 自己的 sendPatch 下发
        @Expect(pageA.isDirty(), true)

        let pickedForA = RenderContext.collectOwnedDirty(sessionA)
        @Expect(pickedForA.size, 1)
        RenderContext.clearDirty()
    }

    @TestCase
    public func testInPlaceReRenderKeepsFreshSubscriptions(): Unit {
        RenderContext.clearDirty()
        let sig = Signal<String>("v0")
        let session = Session("owner-t-2", text(""), text(""))
        let page = OwnerProbeLeaf(sig)
        ownerProbeRenderPage(session, page)
        RenderContext.clearDirty()

        // 同一实例就地重渲（令牌恢复路径）：重新订阅的依赖不能被归属登记解除
        ownerProbeRenderPage(session, page)
        sig.set("v1")
        @Expect(session.ownsComponent(page), true)
        @Expect(page.isDirty(), true)
        RenderContext.clearDirty()
    }

    @TestCase
    public func testSubtreePatchSupersedesOldChildInstance(): Unit {
        RenderContext.clearDirty()
        let sig = Signal<String>("v0")
        let session = Session("owner-t-3", text(""), text(""))
        let parent = OwnerProbeParent(sig)
        ownerProbeRenderSubtree(session, parent, "children/1")
        let firstChild = parent.child
        @Expect(session.ownsComponent(firstChild), true)

        // 子树补丁重渲父组件：新的子实例接管该路径，旧子实例退订
        ownerProbeRenderSubtree(session, parent, "children/1")
        @Expect(session.ownsComponent(parent.child), true)
        @Expect(session.ownsComponent(firstChild), false)

        sig.set("v1")
        @Expect(ownerProbeDirtyContains(firstChild), false)
        @Expect(ownerProbeDirtyContains(parent.child), true)
        RenderContext.clearDirty()
    }
}
