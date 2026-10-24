package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Anchor / AnchorLink 渲染结构测试。
// 对齐点：EP anchor.vue 的 `.el-anchor[.--vertical|--horizontal][.--underline]` >
//   `.el-anchor__marker`? + `.el-anchor__list` > `.el-anchor__item` > `a.el-anchor__link`；
// EP anchor-link.vue 的标题/href、is-active、sub-link 只在纵向渲染。
//
// 跳转走原生 `<a href="#id">`（无前端 JS）；offset 补偿走 scroll-margin（见 scrollOffsetStyle）。
func renderAnchorJson(t: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(t, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

func makeAnchorCtx(): ActionContext {
    ActionContext("s-an", HashMap<String, String>(), HashMap<String, String>(),
        Router("s-an", { _ => () }))
}

@Test
public class AnchorTest {
    @TestCase
    public func testBasicStructure(): Unit {
        let (json, _) = renderAnchorJson(Anchor([
            AnchorLink("小节一", "#sec1"),
            AnchorLink("小节二", "#sec2"),
        ]))
        @Expect(json.contains("el-anchor"), true)
        @Expect(json.contains("el-anchor__list"), true)
        @Expect(json.contains("el-anchor__item"), true)
        @Expect(json.contains("el-anchor__link"), true)
        @Expect(json.contains("\"a\""), true)
        @Expect(json.contains("#sec1"), true)
        @Expect(json.contains("小节一"), true)
    }

    @TestCase
    public func testVerticalByDefaultWithDirectionClass(): Unit {
        // EP: cls = [ns.b(), type==underline ? --underline : '', ns.m(direction)]
        // direction 默认 vertical
        let (json, _) = renderAnchorJson(Anchor([AnchorLink("a", "#a")]))
        @Expect(json.contains("el-anchor--vertical"), true)
        @Expect(json.contains("el-anchor--horizontal"), false)
        @Expect(json.contains("el-anchor--underline"), false)
    }

    @TestCase
    public func testHorizontalDirection(): Unit {
        let (json, _) = renderAnchorJson(Anchor([AnchorLink("a", "#a")]).direction(AnchorDirection.Horizontal))
        @Expect(json.contains("el-anchor--horizontal"), true)
        @Expect(json.contains("el-anchor--vertical"), false)
    }

    @TestCase
    public func testUnderlineVariant(): Unit {
        // EP type="underline" → 根节点加 --underline（scss 据此画左/下基准线）
        let (json, _) = renderAnchorJson(Anchor([AnchorLink("a", "#a")]).underline())
        @Expect(json.contains("el-anchor--underline"), true)
        @Expect(json.contains("el-anchor--vertical"), true)
    }

    @TestCase
    public func testMarkerRenderedByDefaultAndRemovable(): Unit {
        // EP marker 默认 true，元素在 list 之前
        let (json, _) = renderAnchorJson(Anchor([AnchorLink("a", "#a")]))
        @Expect(json.contains("el-anchor__marker"), true)

        let (j2, _) = renderAnchorJson(Anchor([AnchorLink("a", "#a")]).marker(false))
        @Expect(j2.contains("el-anchor__marker"), false)
    }

    @TestCase
    public func testCurrentMarksActiveLink(): Unit {
        // EP: is-active 来自 currentAnchor === href；这里可用静态 current(href)
        let (json, _) = renderAnchorJson(Anchor([
            AnchorLink("一", "#a"),
            AnchorLink("二", "#b"),
        ]).current("#b"))
        @Expect(json.contains("is-active"), true)
        @Expect(json.contains("aria-current"), true)
        // 激活的必须是 #b 那一条
        let (j1, _) = renderAnchorJson(Anchor([AnchorLink("一", "#a")]).current("#a"))
        @Expect(j1.contains("is-active"), true)
        let (j2, _) = renderAnchorJson(Anchor([AnchorLink("一", "#a")]).current("#zzz"))
        @Expect(j2.contains("is-active"), false)
    }

    @TestCase
    public func testCurrentDrivenBySignal(): Unit {
        // 滚动位置是客户端状态：外置 Signal 驱动高亮（与 VirtualList 同一套结论）
        let cur = Signal<String>("")
        let a = Anchor([AnchorLink("一", "#a")]).bindAnchorCurrent(cur)
        let (j0, _) = renderAnchorJson(a)
        @Expect(j0.contains("is-active"), false)

        cur.set("#a")
        let (j1, _) = renderAnchorJson(a)
        @Expect(j1.contains("is-active"), true)
    }

    @TestCase
    public func testSubLinksOnlyInVertical(): Unit {
        // EP anchor-link: sub-link 容器仅在 direction==='vertical' 时渲染
        let parent = AnchorLink("父", "#p").subLinks([AnchorLink("子", "#c")])
        let (jv, _) = renderAnchorJson(Anchor([parent]).direction(AnchorDirection.Vertical))
        @Expect(jv.contains("#c"), true)
        @Expect(jv.contains("el-anchor__list"), true)

        let parent2 = AnchorLink("父", "#p").subLinks([AnchorLink("子", "#c")])
        let (jh, _) = renderAnchorJson(Anchor([parent2]).direction(AnchorDirection.Horizontal))
        @Expect(jh.contains("#c"), false)
    }

    @TestCase
    public func testNoHandlerMeansNativeJumpOnly(): Unit {
        // 不给 onClick 时不应挂任何 action：跳转完全靠原生 href（静态页可用）
        let (_, handlers) = renderAnchorJson(Anchor([AnchorLink("a", "#a")]))
        @Expect(handlers.size, 0)
    }

    @TestCase
    public func testOptionalClickHandlerFires(): Unit {
        let hits = Box<Int64>(0)
        let h: ActionHandler = { ctx => hits.value += 1; PatchResult.ReRender }
        let (json, handlers) = renderAnchorJson(Anchor([
            AnchorLink("a", "#a").onClick(h),
        ]))
        // 回调不替代跳转：href 仍在
        @Expect(json.contains("#a"), true)
        @Expect(handlers.size, 1)
        for ((_, fn) in handlers) { let _ = fn(makeAnchorCtx()) }
        @Expect(hits.value, 1)
    }

    @TestCase
    public func testOffsetMarkedOnLink(): Unit {
        // offset 标记在锚点上（真正生效要落到跳转目标元素，见下一条用例）
        let (json, _) = renderAnchorJson(Anchor([AnchorLink("a", "#a")]).offset(60))
        @Expect(json.contains("data-anchor-offset"), true)
        @Expect(json.contains("60"), true)
    }

    @TestCase
    public func testScrollOffsetStyleForTargetElement(): Unit {
        // 原生锚点没有 EP 的 `distance - offset` 补偿；等价能力是把 scroll-margin 写进目标元素
        @Expect(scrollOffsetStyle(60), "scroll-margin-top:60px")
        // 非正数不产生样式（避免污染目标元素 style）
        @Expect(scrollOffsetStyle(0), "")
        @Expect(scrollOffsetStyle(-5), "")
    }

    @TestCase
    public func testRootHasNavigationRole(): Unit {
        // EP 根节点没有显式 role，但语义上是导航；这里补 role=navigation + aria-label
        let (json, _) = renderAnchorJson(Anchor([AnchorLink("a", "#a")]))
        @Expect(json.contains("\"role\":\"navigation\""), true)
        @Expect(json.contains("aria-label"), true)
    }

    @TestCase
    public func testNonLinkChildrenRenderedAsIs(): Unit {
        // Anchor 子节点允许混入普通组件（如说明文字），不应被吞掉
        let (json, _) = renderAnchorJson(Anchor([text("导航标题"), AnchorLink("a", "#a")]))
        @Expect(json.contains("导航标题"), true)
        @Expect(json.contains("el-anchor__link"), true)
    }

    // ── 点击/滚动高亮改由前端按 location.hash 驱动（2026-10-23）──────
    // 高亮不需要滚动高度：点击后 hash 立刻变化，前端比对 href 即可决定 is-active，
    // 零往返、天然支持前进后退与带 hash 打开。服务端只负责打标记。

    @TestCase
    public func testRootCarriesHashActiveMarker(): Unit {
        // 根元素必须带 data-anchor-active，前端据此挂 hashchange 高亮
        let (out, _) = renderAnchorJson(Anchor([
            AnchorLink("第一节", "#s1"),
            AnchorLink("第二节", "#s2"),
        ]))
        @Expect(out.contains("data-anchor-active"), true)
    }

    @TestCase
    public func testStaticCurrentStillRenderedAsActive(): Unit {
        // 无 hash 时前端沿用服务端渲染的静态高亮，所以它必须照常输出 is-active
        let (out, _) = renderAnchorJson(Anchor([
            AnchorLink("第一节", "#s1"),
            AnchorLink("第二节", "#s2"),
        ]).current("#s1"))
        @Expect(out.contains("el-anchor__link is-active"), true)
        @Expect(out.contains("aria-current"), true)
    }

    @TestCase
    public func testNoScrollMathInComponent(): Unit {
        // 锚点滚动是浏览器原生能力（href 跳转），组件不该做滚动计算。
        // 这里从渲染产物侧确认：链接的 href 就是纯锚点，没有额外的滚动属性/脚本钩子。
        let (out, _) = renderAnchorJson(Anchor([AnchorLink("第一节", "#s1")]))
        @Expect(out.contains("#s1"), true)
        @Expect(out.contains("data-scroll-to"), false)
    }
}
