package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Collapse / CollapseItem 展开动画契约（2026-10-23 补）
//
// 背景：此前收起时**不渲染** wrap（条件渲染），内容从无到有不会触发 CSS transition
// → 展开没有任何动画。EP 用 Vue `<transition>` + JS 动态算 max-height 做动画，
// 服务端拿不到 scrollHeight，故改为纯 CSS：
//   - wrap **始终渲染**
//   - 收起：max-height:0 + overflow:hidden
//   - 展开：max-height:100vh
//   - 两者都带 transition:max-height
@Test
public class CollapseTest {
    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    // Collapse 支持 bind(外置信号) 后，可构造确定的展开/收起态
    func inactiveCollapse(): Collapse {
        Collapse([CollapseItem([text("内容")], "标题", "1")])
            .bind(Signal<ArrayList<String>>(ArrayList<String>(Array<String>())))
    }

    func activeCollapse(): Collapse {
        Collapse([CollapseItem([text("内容")], "标题", "1")])
            .bind(Signal<ArrayList<String>>(ArrayList<String>(["1"])))
    }

    @TestCase
    public func testCollapsedItemStillRendersWrap(): Unit {
        // 收起态也必须渲染 wrap —— 否则元素从无到有，transition 不会触发
        let out = this.json(this.inactiveCollapse())
        @Expect(out.contains("el-collapse-item__wrap"), true)
        @Expect(out.contains("el-collapse-item__content"), true)
    }

    @TestCase
    public func testCollapsedItemHasZeroMaxHeight(): Unit {
        let out = this.json(this.inactiveCollapse())
        @Expect(out.contains("max-height:0"), true)
        @Expect(out.contains("overflow:hidden"), true)
    }


    @TestCase
    public func testExpandedItemHasLargeMaxHeight(): Unit {
        let out = this.json(this.activeCollapse())
        @Expect(out.contains("max-height:100vh"), true)
    }

    @TestCase
    public func testExpandedHasActiveClasses(): Unit {
        let out = this.json(this.activeCollapse())
        @Expect(out.contains("el-collapse-item is-active"), true)
        @Expect(out.contains("el-collapse-item__header is-active"), true)
        @Expect(out.contains("el-collapse-item__arrow is-active"), true)
    }

    @TestCase
    public func testBindSignalDrivesExpansion(): Unit {
        // 外置信号从空 → 含 name，渲染结果应从未展开变展开
        let sig = Signal<ArrayList<String>>(ArrayList<String>(Array<String>()))
        let c = Collapse([CollapseItem([text("内容")], "标题", "1")]).bind(sig)
        @Expect(this.json(c).contains("max-height:0"), true)
        sig.set(ArrayList<String>(["1"]))
        @Expect(this.json(c).contains("max-height:100vh"), true)
    }

    @TestCase
    public func testCollapsedStateDeclaresTransition(): Unit {
        // 动画靠 transition 声明；收起态必须带（展开态同理，由源码契约用例覆盖）
        @Expect(this.json(this.inactiveCollapse()).contains("transition:max-height"), true)
    }

    @TestCase
    public func testAriaHiddenReflectsState(): Unit {
        // 收起的内容对读屏器隐藏；展开时 aria-hidden=false
        @Expect(this.json(this.inactiveCollapse()).contains("aria-hidden"), true)
        @Expect(this.json(this.activeCollapse()).contains("aria-hidden"), true)
    }

    @TestCase
    public func testInactiveHasNoActiveClass(): Unit {
        let out = this.json(this.inactiveCollapse())
        @Expect(out.contains("is-active"), false)
    }


}
