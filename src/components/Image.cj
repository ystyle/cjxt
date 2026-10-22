package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ── Image 图片 ────────────────────────────────────────────────────────────────
//
// 对齐 element-plus image/src/image.vue：
//
//   div.el-image
//     img.el-image__inner[.el-image__preview]
//     div.el-image__wrapper > div.el-image__placeholder     （加载中占位）
//     div.el-image__error                                    （加载失败）
//     ↳ 预览打开时追加 el-image-viewer__wrapper 遮罩
//
// 服务端的取舍（都写在这里，避免以后误以为是漏做）：
// - **加载中/失败状态由调用方驱动**：EP 靠 img 的 load/error 原生事件切 `isLoading` /
//   `hasLoadError`，服务端拿不到这两个事件。这里提供 `placeholder()` / `error()` 两个显式
//   入口，由业务按自己的数据状态决定渲染哪一支。
// - **lazy 用浏览器原生懒加载**：EP 用 IntersectionObserver + 滚动容器实测可见性后再置 src。
//   服务端不掌握视口，这里输出 `loading="lazy"` —— 原生 `<img loading=lazy>` 的语义正是
//   「进入视口才加载」，与 EP 的目的一致，且不需要额外前端代码。
// - **预览是简化版**：EP 是全屏 ImageViewer（缩放/旋转/切换/键盘）。这里只做
//   「点击 → 遮罩居中显示大图 → 关闭」，其余交互不实现。

public class Image <: Component {
    var _src: String = ""
    var _alt: String = ""
    // ImageFit 自带 None 变体，与 Option 的 None 同名 → 必须全限定（AGENTS.md 记过此坑）
    var _fit: Option<ImageFit> = Option<ImageFit>.None
    var _lazy: Bool = false
    var _previewSrcList: ArrayList<String> = ArrayList<String>()
    var _initialIndex: Int64 = 0
    // 显式状态：加载中占位 / 加载失败
    var _showPlaceholder: Bool = false
    var _showError: Bool = false
    var _errorText: String = "加载失败"
    // 预览遮罩是否打开 + 当前张（服务端 Signal 驱动，跨渲染持久化）
    var _viewerVisible: Signal<Bool> = Signal<Bool>(false)
    var _currentIndex: Signal<Int64> = Signal<Int64>(0)
    var _hideOnClickModal: Bool = false

    public init(src: String) { this._src = src }

    public func alt(v: String): Image { this._alt = v; this }
    public func fit(v: ImageFit): Image { this._fit = Some(v); this }
    public func lazy(): Image { this._lazy = true; this }
    // 可预览的地址列表。非空即开启预览（EP 的 preview = previewSrcList.length > 0）
    public func previewSrcList(v: Array<String>): Image {
        this._previewSrcList = ArrayList<String>()
        for (s in v) { this._previewSrcList.add(s) }
        this
    }
    public func initialIndex(v: Int64): Image { this._initialIndex = v; this }
    // 占位/错误状态显式开关（替代 EP 依赖的原生 load/error 事件）
    public func placeholder(): Image { this._showPlaceholder = true; this._showError = false; this }
    public func error(text: String): Image { this._showError = true; this._showPlaceholder = false; this._errorText = text; this }
    // 点击遮罩关闭（EP 的 hideOnClickModal；默认关，与 EP 默认 false 一致）
    public func hideOnClickModal(): Image { this._hideOnClickModal = true; this }
    // 预览可见性外置（与 Dialog 同思路：需要跨渲染保留时由调用方提供信号）
    public func viewerVisible(s: Signal<Bool>): Image { this._viewerVisible = s; this }

    public func render(): IComponent {
        let parts = ArrayList<IComponent>()

        if (this._showError) {
            parts.add(VNode("div", [text(this._errorText)], attrs: Some(HashMap<String, String>([
                ("class", "el-image__error")
            ]))))
        } else if (this._showPlaceholder) {
            // EP 加载中：img 仍在（加 is-loading → opacity:0，容器尺寸由它撑起），
            // 上面覆盖 wrapper > placeholder（fill-color-light 底色）
            parts.add(this.buildImg(true))
            parts.add(VNode("div", [
                VNode("div", [], attrs: Some(HashMap<String, String>([
                    ("class", "el-image__placeholder")
                ])))
            ], attrs: Some(HashMap<String, String>([("class", "el-image__wrapper")]))))
        } else {
            parts.add(this.buildImg(false))
        }

        if (this._viewerVisible.get()) {
            parts.add(this.buildViewer())
        }

        VNode("div", parts.toArray(), attrs: Some(HashMap<String, String>([
            ("class", "el-image")
        ])))
    }

    func buildImg(isLoading: Bool): IComponent {
        let hasPreview = this._previewSrcList.size > 0
        var cls = "el-image__inner"
        if (hasPreview) { cls = "${cls} el-image__preview" }
        // EP imageKls：isLoading 时加 is-loading（scss: opacity:0）
        if (isLoading) { cls = "${cls} is-loading" }
        let attrs = HashMap<String, String>([("class", cls)])
        if (this._alt != "") { attrs["alt"] = this._alt }
        match (this._fit) {
            case Some(f) => attrs["style"] = "object-fit:${f.asClass()}"
            case None => ()
        }
        if (this._lazy) { attrs["loading"] = "lazy" }
        attrs["src"] = this._src

        var img = VNode("img", [], attrs: Some(attrs))
        if (hasPreview) {
            img = img.onClick(this.openViewerAction())
        }
        img
    }

    // 点图打开预览：EP 的 imageIndex = initialIndex（越界回落 0）
    func openViewerAction(): ActionHandler {
        let vis = this._viewerVisible
        let cur = this._currentIndex
        let idx = this.clampIndex(this._initialIndex)
        let handler: ActionHandler = { ctx =>
            cur.set(idx)
            vis.set(true)
            PatchResult.ReRender
        }
        handler
    }

    // 简化版 ImageViewer（对齐 EP 的 DOM 层级：wrapper > mask + btn/close + canvas > img）
    func buildViewer(): IComponent {
        let closeH = this.closeViewerAction()
        let mask = VNode("div", [], attrs: Some(HashMap<String, String>([
            ("class", "el-image-viewer__mask")
        ])))
        let maskEl = if (this._hideOnClickModal) { mask.onClick(closeH) } else { mask }
        let closeBtn = VNode("span", [Icon("close")], attrs: Some(HashMap<String, String>([
            ("class", "el-image-viewer__btn el-image-viewer__close")
        ]))).onClick(closeH)

        let src = this.currentSrc()
        let imgAttrs = HashMap<String, String>([
            ("class", "el-image-viewer__img"),
            ("src", src),
            ("style", "max-width:90%;max-height:90%;object-fit:contain")
        ])
        let canvas = VNode("div", [
            VNode("img", [], attrs: Some(imgAttrs))
        ], attrs: Some(HashMap<String, String>([("class", "el-image-viewer__canvas")])))

        let wrapperAttrs = HashMap<String, String>([
            ("class", "el-image-viewer__wrapper"),
            ("style", "z-index:2002")
        ])
        VNode("div", [maskEl, closeBtn, canvas], attrs: Some(wrapperAttrs))
    }

    func closeViewerAction(): ActionHandler {
        let vis = this._viewerVisible
        let handler: ActionHandler = { ctx =>
            vis.set(false)
            PatchResult.ReRender
        }
        handler
    }

    // 预览当前显示的地址：列表为空时回落到自身 src
    func currentSrc(): String {
        if (this._previewSrcList.size == 0) { return this._src }
        let i = this.clampIndex(this._currentIndex.get())
        this._previewSrcList[i]
    }

    // EP imageIndex：initialIndex 越界（> length-1）时回落到 0
    func clampIndex(i: Int64): Int64 {
        if (i < 0) { return 0 }
        if (this._previewSrcList.size > 0 && i > this._previewSrcList.size - 1) { return 0 }
        i
    }
}
