package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Image 渲染结构测试。
// 对齐点：EP image.vue 的 `.el-image > img.el-image__inner`、
// fit → 内联 object-fit、previewSrcList 非空 → __preview 类 + 可点击、
// placeholder/error 两支、简化版 ImageViewer 遮罩与关闭。
func renderImageJson(t: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(t, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

func makeActionCtx(): ActionContext {
    ActionContext("s-img", HashMap<String, String>(), HashMap<String, String>(),
        Router("s-img", { _ => () }))
}

@Test
public class ImageTest {
    @TestCase
    public func testBasicStructure(): Unit {
        let (json, _) = renderImageJson(Image("/a.png").alt("示意图"))
        @Expect(json.contains("el-image"), true)
        @Expect(json.contains("\"img\""), true)
        @Expect(json.contains("el-image__inner"), true)
        @Expect(json.contains("\"src\":\"/a.png\""), true)
        @Expect(json.contains("\"alt\":\"示意图\""), true)
    }

    @TestCase
    public func testFitWritesInlineObjectFit(): Unit {
        // EP imageStyle: { objectFit: fit }，写在 img 内联样式上（不是 class）
        let (json, _) = renderImageJson(Image("/a.png").fit(ImageFit.Cover))
        @Expect(json.contains("object-fit:cover"), true)

        let (j2, _) = renderImageJson(Image("/a.png").fit(ImageFit.ScaleDown))
        @Expect(j2.contains("object-fit:scale-down"), true)

        // 未设 fit 时不写 style（EP 的 fit 默认 '' → 空对象）
        let (j3, _) = renderImageJson(Image("/a.png"))
        @Expect(j3.contains("object-fit"), false)
    }

    @TestCase
    public func testAllFitVariants(): Unit {
        let cases: Array<(ImageFit, String)> = [
            (ImageFit.Fill, "fill"),
            (ImageFit.Contain, "contain"),
            (ImageFit.Cover, "cover"),
            (ImageFit.None, "none"),
            (ImageFit.ScaleDown, "scale-down"),
        ]
        for ((f, name) in cases) {
            let (json, _) = renderImageJson(Image("/a.png").fit(f))
            @Expect(json.contains("object-fit:${name}"), true)
        }
    }

    @TestCase
    public func testLazyUsesNativeLoadingAttr(): Unit {
        // EP 用 IntersectionObserver；服务端改用原生 loading=lazy（语义等价、无需前端代码）
        let (json, _) = renderImageJson(Image("/a.png").lazy())
        @Expect(json.contains("loading"), true)
        @Expect(json.contains("lazy"), true)
        // 非懒加载时不得有 loading 属性
        let (j2, _) = renderImageJson(Image("/a.png"))
        @Expect(j2.contains("loading"), false)
    }

    @TestCase
    public func testPlaceholderBranch(): Unit {
        // 加载中：img 带 is-loading（opacity:0），另有 wrapper > placeholder
        let (json, _) = renderImageJson(Image("/a.png").placeholder())
        @Expect(json.contains("is-loading"), true)
        @Expect(json.contains("el-image__wrapper"), true)
        @Expect(json.contains("el-image__placeholder"), true)
        // 占位态不应出现错误块
        @Expect(json.contains("el-image__error"), false)
    }

    @TestCase
    public func testErrorBranch(): Unit {
        let (json, _) = renderImageJson(Image("/a.png").error("载入失败"))
        @Expect(json.contains("el-image__error"), true)
        @Expect(json.contains("载入失败"), true)
        // 错误态不渲染 img（EP 的 v-else 结构）
        @Expect(json.contains("\"img\""), false)
        @Expect(json.contains("el-image__placeholder"), false)
    }

    @TestCase
    public func testNoPreviewMeansNoPreviewClassAndNoHandler(): Unit {
        // EP: preview = previewSrcList.length > 0；为空时 img 无 __preview、也不挂点击
        let (json, handlers) = renderImageJson(Image("/a.png"))
        @Expect(json.contains("el-image__preview"), false)
        @Expect(handlers.size, 0)
    }

    @TestCase
    public func testPreviewAddsClassAndClickHandler(): Unit {
        let (json, handlers) = renderImageJson(Image("/a.png")
            .previewSrcList(["/big1.png", "/big2.png"]))
        @Expect(json.contains("el-image__preview"), true)
        @Expect(handlers.size, 1)
        // 未点击时遮罩不渲染
        @Expect(json.contains("el-image-viewer__wrapper"), false)
    }

    @TestCase
    public func testClickOpensViewerAndCloseCloses(): Unit {
        // 交互：点图 → 遮罩打开（含 mask/close/canvas + 大图）；点关闭 → 遮罩消失
        let vis = Signal<Bool>(false)
        let img = Image("/a.png")
            .previewSrcList(["/big1.png", "/big2.png"])
            .initialIndex(1)
            .viewerVisible(vis)

        let (json, handlers) = renderImageJson(img)
        @Expect(json.contains("el-image__preview"), true)
        @Expect(handlers.size, 1)

        // 触发 img 的 click
        var clicked = false
        for ((_, h) in handlers) {
            let _ = h(makeActionCtx())
            clicked = true
        }
        @Expect(clicked, true)
        @Expect(vis.get(), true)

        // 重渲：遮罩结构 + initialIndex=1 → 显示第二张大图
        let (j2, handlers2) = renderImageJson(img)
        @Expect(j2.contains("el-image-viewer__wrapper"), true)
        @Expect(j2.contains("el-image-viewer__mask"), true)
        @Expect(j2.contains("el-image-viewer__close"), true)
        @Expect(j2.contains("el-image-viewer__canvas"), true)
        @Expect(j2.contains("/big2.png"), true)
        // 遮罩打开后有两个 action：关闭按钮 + （hideOnClickModal 时的）遮罩本体
        @Expect(handlers2.size, 2)

        // 点关闭按钮（精确定位 el-image-viewer__close 上的 click），遮罩应关闭
        let closeId = probeActionId(j2, "el-image-viewer__close", "click")
        @Expect(closeId != "", true)
        match (handlers2.get(closeId)) {
            case Some(h) => let _ = h(makeActionCtx())
            case None => @Expect(false, true)
        }
        @Expect(vis.get(), false)
        let (j3, _) = renderImageJson(img)
        @Expect(j3.contains("el-image-viewer__wrapper"), false)
    }

    @TestCase
    public func testInitialIndexOutOfRangeFallsBackToFirst(): Unit {
        // EP imageIndex：initialIndex > list.length-1 → 0
        let vis = Signal<Bool>(false)
        let img = Image("/a.png")
            .previewSrcList(["/big1.png"])
            .initialIndex(5)
            .viewerVisible(vis)
        let (_, handlers) = renderImageJson(img)
        for ((_, h) in handlers) { let _ = h(makeActionCtx()) }
        let (j2, _) = renderImageJson(img)
        @Expect(j2.contains("/big1.png"), true)
    }

    @TestCase
    public func testImageViewerNotRenderedWhenSignalFalse(): Unit {
        let vis = Signal<Bool>(false)
        let (json, _) = renderImageJson(Image("/a.png")
            .previewSrcList(["/big.png"]).viewerVisible(vis))
        @Expect(json.contains("el-image-viewer__wrapper"), false)
    }

    // ── 尺寸与 style（2026-10-23 补）────────────────────────────────
    // 背景：错误态没有 img 撑开、占位态依赖 img 尺寸，容器会塌缩到内容宽
    // （浏览器实测错误态 56×20 而非期望的 160×90）→ 提供显式 width/height。

    @TestCase
    public func testWidthAndHeightInlineStyle(): Unit {
        let (json, _) = renderImageJson(Image("/a.png").width("160px").height("90px"))
        @Expect(json.contains("width:160px"), true)
        @Expect(json.contains("height:90px"), true)
    }

    @TestCase
    public func testWidthOnly(): Unit {
        let (json, _) = renderImageJson(Image("/a.png").width("240px"))
        @Expect(json.contains("width:240px"), true)
        @Expect(json.contains("height:"), false)
    }

    @TestCase
    public func testErrorStateKeepsExplicitSize(): Unit {
        // 钉住缺陷：错误态无 img，尺寸必须由根元素内联样式提供
        let (json, _) = renderImageJson(Image("/bad.png").error("加载失败").width("160px").height("90px"))
        @Expect(json.contains("el-image__error"), true)
        @Expect(json.contains("width:160px"), true)
        @Expect(json.contains("height:90px"), true)
    }

    @TestCase
    public func testPlaceholderStateKeepsExplicitSize(): Unit {
        let (json, _) = renderImageJson(Image("/a.png").placeholder().width("160px"))
        @Expect(json.contains("el-image__placeholder"), true)
        @Expect(json.contains("width:160px"), true)
    }

    @TestCase
    public func testExtraStyleMergedWithSize(): Unit {
        let (json, _) = renderImageJson(Image("/a.png").width("100px").style("border:1px solid red"))
        @Expect(json.contains("width:100px"), true)
        @Expect(json.contains("border:1px solid red"), true)
    }

    @TestCase
    public func testNoStyleAttrWhenNoSizeAndNoExtraStyle(): Unit {
        // 不设尺寸时不写 style，让 scss / 外层布局决定
        let (json, _) = renderImageJson(Image("/a.png"))
        @Expect(json.contains("\"style\":\"\""), false)
    }
}
