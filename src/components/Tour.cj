package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// ============ Tour 漫游引导（对齐 Element Plus tour） ============
//
// EP 结构（tour.vue / content.vue / step.vue / mask.vue）：
//   div.el-tour[.el-tour--primary]                 ← teleport 到 body
//     ├─ div.el-tour__mask / .el-tour__hollow      ← 遮罩（含镂空高亮区）
//     └─ div.el-tour__content[data-side=<placement>]
//          ├─ div.el-tour__arrow
//          ├─ button.el-tour__closebtn > i.el-tour__close
//          ├─ header.el-tour__header[.show-close] > span.el-tour__title
//          ├─ div.el-tour__body
//          └─ footer.el-tour__footer
//               ├─ div.el-tour-indicators > span.el-tour-indicator[.is-active] × total
//               └─ div.el-tour-buttons > button.el-button--small × (上一页/下一页|完成)
//
// **定位：做不到，内容居中显示（重要偏差，如实说明）**
// EP 用 `useTarget` + FloatingUI 在**客户端**测量目标元素 rect，再算 content 的 top/left。
// 服务端渲染拿不到目标元素的像素位置（DOM 还不存在），因此本实现**不定位到 target**：
// 内容以 `position:fixed` 居中显示。`target` 参数仍然接收并落到 `data-tour-target` 属性上，
// 供后续前端接线使用（接线时需要一条「按 selector 量 rect」的 JS，与 Tooltip 的
// FloatingUI 是同一类机制，见 `public/js/components/tooltip.js`）。
// 遮罩同理：EP 的镂空按目标 rect 挖洞，这里退化成整屏半透明遮罩（结构对齐、无镂空）。
//
// 交互：上一页 / 下一页 / 完成 / 关闭 全部是服务端 action，当前步由 `bind(Signal<Int64>)` 驱动，
// 到达最后一步时「下一页」改为「完成」并关闭（EP step.vue 的 onNext → onFinish 语义）。
//
// **未实现**：ESC 关闭（需客户端 keydown 监听）、键盘左右键切换、`scrollIntoView`。

public class TourStep <: Component {
    var _title: String = ""
    var _description: String = ""
    var _target: String = ""
    var _placement: TourPlacement = TourPlacement.Bottom

    public init(title: String, description: String) {
        this._title = title
        this._description = description
    }

    // 目标元素选择器（EP 的 target）。服务端不定位，仅落到 data 属性（见文件头）
    public func target(v: String): TourStep { this._target = v; this }
    public func placement(v: TourPlacement): TourStep { this._placement = v; this }

    // 自身不单独成树（由 Tour 统一渲染）
    public func render(): IComponent { div([]) }
}

public class Tour <: Component {
    var _steps: Array<IComponent>
    var _currentSignal: Option<Signal<Int64>> = None
    var _fallbackCurrent: Signal<Int64> = Signal<Int64>(0)
    var _visibleSignal: Option<Signal<Bool>> = None
    var _fallbackVisible: Signal<Bool> = Signal<Bool>(false)
    var _showClose: Bool = true
    var _showArrow: Bool = true
    var _mask: Bool = true
    var _primary: Bool = false
    var _prevText: String = "上一步"
    var _nextText: String = "下一步"
    var _finishText: String = "完成"
    var _onFinish: Option<ActionHandler> = None
    var _onClose: Option<ActionHandler> = None

    public init(steps: Array<IComponent>) { this._steps = steps }

    public func bindCurrent(signal: Signal<Int64>): Tour { this._currentSignal = Some(signal); this }
    public func bindVisible(signal: Signal<Bool>): Tour { this._visibleSignal = Some(signal); this }
    public func showClose(v: Bool): Tour { this._showClose = v; this }
    public func showArrow(v: Bool): Tour { this._showArrow = v; this }
    public func mask(v: Bool): Tour { this._mask = v; this }
    public func primary(): Tour { this._primary = true; this }
    public func buttonTexts(prev: String, next: String, finish: String): Tour {
        this._prevText = prev
        this._nextText = next
        this._finishText = finish
        this
    }
    public func onFinish(h: ActionHandler): Tour { this._onFinish = Some(h); this }
    public func onClose(h: ActionHandler): Tour { this._onClose = Some(h); this }

    public func render(): IComponent {
        if (!this.visibleSignal().get()) { return EmptyVNode() }

        let steps = this.collectSteps()
        let total = steps.size
        let current = this.effectiveCurrent(total)

        let parts = ArrayList<IComponent>()
        // 遮罩：EP 是两段（mask + hollow）。服务端无目标 rect，退化为整屏遮罩（见文件头）
        if (this._mask) {
            parts.add(VNode("div", [], attrs: Some(HashMap<String, String>([
                ("class", "el-tour__mask"),
                ("style", "position:fixed;inset:0;background:rgba(0,0,0,.5);z-index:2000"),
            ]))))
        }
        if (current >= 0 && current < total) {
            parts.add(this.buildContent(steps[current], current, total))
        }

        var rootCls = "el-tour"
        if (this._primary) { rootCls = "${rootCls} el-tour--primary" }
        VNode("div", parts.toArray(), attrs: Some(HashMap<String, String>([("class", rootCls)])))
    }

    func collectSteps(): ArrayList<TourStep> {
        let out = ArrayList<TourStep>()
        for (c in this._steps) {
            match (c) {
                case s: TourStep => out.add(s)
                case _ => ()
            }
        }
        out
    }

    func currentSignal(): Signal<Int64> {
        match (this._currentSignal) {
            case Some(s) => s
            case None => this._fallbackCurrent
        }
    }

    func visibleSignal(): Signal<Bool> {
        match (this._visibleSignal) {
            case Some(s) => s
            case None => this._fallbackVisible
        }
    }

    func effectiveCurrent(total: Int64): Int64 {
        if (total <= 0) { return -1 }
        let raw = this.currentSignal().get()
        if (raw < 0) { return 0 }
        if (raw >= total) { return total - 1 }
        raw
    }

    func buildContent(step: TourStep, current: Int64, total: Int64): IComponent {
        let inner = ArrayList<IComponent>()

        // 箭头（EP 靠 [data-side] 决定 border 哪边透明）
        if (this._showArrow) {
            inner.add(VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-tour__arrow")]))))
        }

        // 关闭按钮
        if (this._showClose) {
            let closeIcon = VNode("i", [], attrs: Some(HashMap<String, String>([("class", "el-tour__close")])))
            var closeBtn = VNode("button", [closeIcon], attrs: Some(HashMap<String, String>([
                ("class", "el-tour__closebtn"),
                ("type", "button"),
                ("aria-label", "关闭"),
            ])))
            closeBtn = closeBtn.onClick({ ctx => this.close(ctx) })
            inner.add(closeBtn)
        }

        // header
        var headerCls = "el-tour__header"
        if (this._showClose) { headerCls = "${headerCls} show-close" }
        inner.add(VNode("header", [
            VNode("span", [text(step._title)], attrs: Some(HashMap<String, String>([("class", "el-tour__title")]))),
        ], attrs: Some(HashMap<String, String>([
            ("class", headerCls),
            ("role", "heading"),
        ]))))

        // body
        inner.add(VNode("div", [text(step._description)], attrs: Some(HashMap<String, String>([("class", "el-tour__body")]))))

        // footer：指示点 + 按钮
        inner.add(this.buildFooter(current, total))

        // 定位：服务端拿不到目标 rect，内容居中（见文件头）
        var contentStyle = "position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);z-index:2001"
        let attrs = HashMap<String, String>([
            ("class", "el-tour__content"),
            ("style", contentStyle),
            ("data-side", step._placement.asClass()),
            ("role", "dialog"),
            ("tabindex", "-1"),
        ])
        if (step._target != "") { attrs["data-tour-target"] = step._target }
        VNode("div", inner.toArray(), attrs: Some(attrs))
    }

    func buildFooter(current: Int64, total: Int64): IComponent {
        // 指示点
        let dots = ArrayList<IComponent>()
        var i = 0
        while (i < total) {
            var dotCls = "el-tour-indicator"
            if (i == current) { dotCls = "${dotCls} is-active" }
            dots.add(VNode("span", [], attrs: Some(HashMap<String, String>([("class", dotCls)]))))
            i = i + 1
        }
        let indicators = VNode("div", dots.toArray(), attrs: Some(HashMap<String, String>([("class", "el-tour-indicators")])))

        // 按钮：上一步（current>0 才显示）、下一步/完成
        let buttons = ArrayList<IComponent>()
        if (current > 0) {
            var prevCls = "el-button el-button--default el-button--small"
            if (this._primary) { prevCls = "el-button el-button--default el-button--small" }
            let label = text(this._prevText)
            var prevBtn = VNode("button", [label], attrs: Some(HashMap<String, String>([
                ("class", prevCls),
                ("type", "button"),
            ])))
            prevBtn = prevBtn.onClick({ ctx => this.goTo(current - 1, ctx) })
            buttons.add(prevBtn)
        }

        let isLast = current >= total - 1
        var nextCls = "el-button el-button--primary el-button--small"
        if (this._primary) { nextCls = "el-button el-button--default el-button--small" }
        let nextLabel = text(if (isLast) { this._finishText } else { this._nextText })
        var nextBtn = VNode("button", [nextLabel], attrs: Some(HashMap<String, String>([
            ("class", nextCls),
            ("type", "button"),
        ])))
        nextBtn = if (isLast) {
            nextBtn.onClick({ ctx => this.finish(ctx) })
        } else {
            nextBtn.onClick({ ctx => this.goTo(current + 1, ctx) })
        }
        buttons.add(nextBtn)

        let buttonBox = VNode("div", buttons.toArray(), attrs: Some(HashMap<String, String>([("class", "el-tour-buttons")])))
        VNode("footer", [indicators, buttonBox], attrs: Some(HashMap<String, String>([("class", "el-tour__footer")])))
    }

    func goTo(index: Int64, ctx: ActionContext): PatchResult {
        this.currentSignal().set(index)
        PatchResult.ReRender
    }

    // EP step.vue 的 onNext→onFinish：关闭 + 触发 finish 回调
    func finish(ctx: ActionContext): PatchResult {
        this.visibleSignal().set(false)
        match (this._onFinish) {
            case Some(fn) => runCb(fn, ctx)
            case None => ()
        }
        PatchResult.ReRender
    }

    func close(ctx: ActionContext): PatchResult {
        this.visibleSignal().set(false)
        match (this._onClose) {
            case Some(fn) => runCb(fn, ctx)
            case None => ()
        }
        PatchResult.ReRender
    }
}
