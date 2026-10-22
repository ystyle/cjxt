package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Backtop 渲染结构测试。
// 对齐点：EP backtop.vue 的 `.el-backtop`（fixed 圆按钮）+ `.el-backtop__icon` 默认插槽 +
// 内联 right/bottom 定位。回顶动作在本仓走**原生 `<a href="#">`**（见 Backtop.cj 文件头），
// 因此测试钉住的是「锚点可点、href 正确、样式不被浏览器链接默认样式破坏」，
// 而不是 EP 的 scrollTo({behavior:'smooth'})（服务端侧没有滚动指令）。
func renderBacktopJson(t: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(t, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

func makeBacktopCtx(): ActionContext {
    ActionContext("s-bt", HashMap<String, String>(), HashMap<String, String>(),
        Router("s-bt", { _ => () }))
}

@Test
public class BacktopTest {
    @TestCase
    public func testBasicStructure(): Unit {
        let (json, _) = renderBacktopJson(Backtop())
        @Expect(json.contains("el-backtop"), true)
        @Expect(json.contains("\"a\""), true)
        @Expect(json.contains("el-backtop__link"), true)
        @Expect(json.contains("data-backtop"), true)
    }

    @TestCase
    public func testDefaultHrefIsDocumentTop(): Unit {
        // 原生锚点回顶：href="#" 是浏览器滚动到文档顶部的标准做法（无需 JS）
        let (json, _) = renderBacktopJson(Backtop())
        @Expect(json.contains("\"href\":\"#\""), true)
        @Expect(json.contains("aria-label"), true)
    }

    @TestCase
    public func testCustomHrefScrollsToElement(): Unit {
        let (json, _) = renderBacktopJson(Backtop().href("#top-anchor"))
        @Expect(json.contains("#top-anchor"), true)
    }

    @TestCase
    public func testRightBottomPositioning(): Unit {
        // EP: backtopStyle = { right: `${right}px`, bottom: `${bottom}px` }，默认 40/40
        let (json, _) = renderBacktopJson(Backtop())
        @Expect(json.contains("right:40px"), true)
        @Expect(json.contains("bottom:40px"), true)

        let (j2, _) = renderBacktopJson(Backtop().right(80).bottom(120))
        @Expect(j2.contains("right:80px"), true)
        @Expect(j2.contains("bottom:120px"), true)
    }

    @TestCase
    public func testDefaultIconIsArrowUp(): Unit {
        // EP 默认插槽是 caret-top 图标；仓内图标表无 caret-top，用同样语义的 arrow-up
        let (json, _) = renderBacktopJson(Backtop())
        @Expect(json.contains("el-backtop__icon"), true)
        @Expect(json.contains("el-icon"), true)
        // 图标有实际 path（不是 Icon 的兜底方框）
        @Expect(json.contains("\"path\""), true)
    }

    @TestCase
    public func testCustomSlotReplacesIcon(): Unit {
        // EP 默认插槽可替换：给了内容就不渲染默认图标
        let (json, _) = renderBacktopJson(Backtop([text("UP")]))
        @Expect(json.contains("UP"), true)
        @Expect(json.contains("el-backtop__icon"), false)
    }

    @TestCase
    public func testLinkStyleNeutralisesBrowserDefaults(): Unit {
        // <a> 必须铺满按钮且继承按钮前景色：否则只有图标可点、文字色被链接蓝覆盖
        let (json, _) = renderBacktopJson(Backtop())
        @Expect(json.contains("text-decoration:none"), true)
        @Expect(json.contains("color:inherit"), true)
        @Expect(json.contains("width:100%"), true)
    }

    @TestCase
    public func testNoHandlerWhenNoClickGiven(): Unit {
        // 未给 onClick 时不挂 action：回顶完全靠原生锚点，服务端不需要参与
        let (_, handlers) = renderBacktopJson(Backtop())
        @Expect(handlers.size, 0)
    }

    @TestCase
    public func testOptionalClickHandlerFires(): Unit {
        // 旁路回调（埋点用）：给了就挂上，且不影响原生 href 跳转
        let hits = Box<Int64>(0)
        let h: ActionHandler = { ctx => hits.value += 1; PatchResult.ReRender }
        let (json, handlers) = renderBacktopJson(Backtop().onClick(h))
        @Expect(json.contains("\"href\":\"#\""), true)
        @Expect(handlers.size, 1)
        for ((_, fn) in handlers) { let _ = fn(makeBacktopCtx()) }
        @Expect(hits.value, 1)
    }

    @TestCase
    public func testVisibilityHeightExposedAsDataAttr(): Unit {
        // EP 靠 scrollTop >= visibilityHeight 控制显隐；服务端读不到滚动位置 → 恒显示，
        // 阈值以 data 属性输出，供后续接监听或业务 CSS 使用
        let (json, _) = renderBacktopJson(Backtop())
        @Expect(json.contains("data-visibility-height"), true)
        @Expect(json.contains("200"), true)
        let (j2, _) = renderBacktopJson(Backtop().visibilityHeight(500))
        @Expect(j2.contains("500"), true)
    }
}
