package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}
import std.convert.*

// 简单 trim（避免依赖未确认的 String API）：去掉首尾空白（空格/Tab）
func trimKey(s: String): String {
    var start: Int64 = 0
    var end = s.size
    while (start < end && isLayoutSpace(s[start])) { start += 1 }
    while (end > start && isLayoutSpace(s[end - 1])) { end -= 1 }
    s[start..end]
}

func isLayoutSpace(b: UInt8): Bool {
    b == 32u8 || b == 9u8
}

/**
 * 分页组件，对齐 Element Plus Pagination。
 *
 * 状态（currentPage / pageSize）通过外部 Signal 持久化（跨重渲染保留，对齐 Table 实践）；
 * 未提供信号时仅作展示（不可翻页）。
 * layout 支持：prev, pager, next, total, sizes, jumper（逗号分隔，顺序即显示顺序）。
 */
public class Pagination <: Component {
    var _total: Int64 = 0
    var _pageCount: Int64 = 0          // 0 = 由 total/pageSize 推导
    var _pagerCount: Int64 = 7
    var _layout: String = "prev, pager, next, jumper, total"
    var _pageSizes = [10, 20, 30, 40, 50, 100]
    var _small: Bool = false
    var _background: Bool = false
    var _disabled: Bool = false
    var _hideOnSinglePage: Bool = false
    var _prevText: String = ""
    var _nextText: String = ""
    var _currentPageSignal: Option<Signal<Int64>> = None
    var _pageSizeSignal: Option<Signal<Int64>> = None
    var _currentChangeHandler: Option<ActionHandler> = None
    var _sizeChangeHandler: Option<ActionHandler> = None
    var _changeHandler: Option<ActionHandler> = None

    public init() {}

    // ── 属性 ──
    public func total(v: Int64): Pagination { this._total = v; this }
    public func pageCount(v: Int64): Pagination { this._pageCount = v; this }
    public func pagerCount(v: Int64): Pagination { this._pagerCount = v; this }
    public func layout(v: String): Pagination { this._layout = v; this }
    public func pageSizes(v: Array<Int64>): Pagination { this._pageSizes = v; this }
    public func small(): Pagination { this._small = true; this }
    public func background(): Pagination { this._background = true; this }
    public func disabled(): Pagination { this._disabled = true; this }
    public func hideOnSinglePage(): Pagination { this._hideOnSinglePage = true; this }
    public func prevText(v: String): Pagination { this._prevText = v; this }
    public func nextText(v: String): Pagination { this._nextText = v; this }
    public func currentPage(signal: Signal<Int64>): Pagination { this._currentPageSignal = Some(signal); this }
    public func pageSize(signal: Signal<Int64>): Pagination { this._pageSizeSignal = Some(signal); this }

    // ── 事件 ──
    public func onCurrentChange(h: ActionHandler): Pagination { this._currentChangeHandler = Some(h); this }
    public func onSizeChange(h: ActionHandler): Pagination { this._sizeChangeHandler = Some(h); this }
    public func onChange(h: ActionHandler): Pagination { this._changeHandler = Some(h); this }

    // ── 状态 ──
    private func currentPage(): Int64 {
        match (this._currentPageSignal) { case Some(s) => s.get(); case None => 1 }
    }

    private func pageSize(): Int64 {
        match (this._pageSizeSignal) { case Some(s) => s.get(); case None => 10 }
    }

    private func setCurrentPage(v: Int64): Unit {
        match (this._currentPageSignal) { case Some(s) => s.set(v); case None => () }
    }

    private func setPageSize(v: Int64): Unit {
        match (this._pageSizeSignal) { case Some(s) => s.set(v); case None => () }
    }

    private func pageCount(): Int64 {
        if (this._pageCount > 0) { this._pageCount } else { computePageCount(this._total, this.pageSize()) }
    }

    public func render(): IComponent {
        let pc = this.pageCount()
        let cp = clampPage(this.currentPage(), pc)
        if (this._hideOnSinglePage && pc <= 1) { return EmptyVNode() }
        var cls = "el-pagination"
        if (this._background) { cls = "${cls} is-background" }
        if (this._small) { cls = "${cls} el-pagination--small" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let attrs = HashMap<String, String>([("class", cls)])
        let children = this.buildLayout(cp, pc)
        VNode("div", children.toArray(), attrs: Some(attrs))
    }

    // ── layout ──
    private func buildLayout(cp: Int64, pc: Int64): ArrayList<IComponent> {
        let children = ArrayList<IComponent>()
        for (p in this._layout.split(",")) {
            let key = trimKey(p)
            match (key) {
                case "prev" => children.add(this.buildPrev(cp))
                case "next" => children.add(this.buildNext(cp, pc))
                case "pager" => children.add(this.buildPager(cp, pc))
                case "total" => children.add(this.buildTotal())
                case "sizes" => children.add(this.buildSizes())
                case "jumper" => children.add(this.buildJumper(cp, pc))
                case _ => ()
            }
        }
        children
    }

    // ── prev / next ──
    private func buildPrev(cp: Int64): IComponent {
        let disabled = this._disabled || cp <= 1
        let attrs = HashMap<String, String>([("class", "btn-prev"), ("type", "button"), ("aria-label", "上一页")])
        if (disabled) { attrs["disabled"] = "true" }
        var btn = VNode("button", [Icon("arrow-left").render()], attrs: Some(attrs))
        if (!disabled) {
            let target = cp - 1
            btn = btn.onClick({ ctx => this.onNav(ctx, target) })
        }
        btn
    }

    private func buildNext(cp: Int64, pc: Int64): IComponent {
        let disabled = this._disabled || cp >= pc
        let attrs = HashMap<String, String>([("class", "btn-next"), ("type", "button"), ("aria-label", "下一页")])
        if (disabled) { attrs["disabled"] = "true" }
        var btn = VNode("button", [Icon("arrow-right").render()], attrs: Some(attrs))
        if (!disabled) {
            let target = cp + 1
            btn = btn.onClick({ ctx => this.onNav(ctx, target) })
        }
        btn
    }

    // ── pager ──
    private func buildPager(cp: Int64, pc: Int64): IComponent {
        let info = computePager(cp, pc, this._pagerCount)
        let items = ArrayList<IComponent>()
        items.add(this.buildPagerNumber(1, cp))
        if (info.showPrevMore) { items.add(this.buildMore("btn-quickprev", cp)) }
        for (p in info.pages) {
            let page = p
            items.add(this.buildPagerNumber(page, cp))
        }
        if (info.showNextMore) { items.add(this.buildMore("btn-quicknext", cp)) }
        if (pc > 1) { items.add(this.buildPagerNumber(pc, cp)) }
        VNode("ul", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-pager")])))
    }

    private func buildPagerNumber(page: Int64, cp: Int64): IComponent {
        let active = page == cp
        var cls = "number"
        if (active) { cls = "${cls} is-active" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let attrs = HashMap<String, String>([("class", cls), ("aria-current", if (active) { "true" } else { "false" })])
        var li = VNode("li", [text(page.toString())], attrs: Some(attrs))
        if (!this._disabled && !active) {
            let p = page
            li = li.onClick({ ctx => this.onNav(ctx, p) })
        }
        li
    }

    private func buildMore(kind: String, cp: Int64): IComponent {
        let attrs = HashMap<String, String>([("class", "more ${kind} el-icon")])
        var li = VNode("li", [Icon("more").render()], attrs: Some(attrs))
        if (!this._disabled) {
            let offset = this._pagerCount - 2
            let target = if (kind == "btn-quickprev") { cp - offset } else { cp + offset }
            li = li.onClick({ ctx => this.onNav(ctx, target) })
        }
        li
    }

    // ── total ──
    private func buildTotal(): IComponent {
        VNode("span", [text("共 ${this._total} 条")], attrs: Some(HashMap<String, String>([("class", "el-pagination__total")])))
    }

    // ── sizes（复用 Select + onChange；Select 必须作为组件子节点而非 .render() 内联，
    //    否则 _open 订阅到父组件、重渲染会 new 出新 Select 导致下拉无法展开）──
    private func buildSizes(): IComponent {
        let sizeDisplay = Signal<String>(this.pageSize().toString())
        let opts = ArrayList<IComponent>()
        for (s in this._pageSizes) {
            let sv = s
            opts.add(SelectOption([text(sv.toString())], sv.toString()))
        }
        let sds = sizeDisplay
        let sizeHandler: ActionHandler = { ctx =>
            let raw = sds.get()
            let newSize = try { Int64.parse(raw) } catch (_) { this.pageSize() }
            this.onSizeChanged(ctx, newSize)
        }
        let sel: IComponent = Select(opts.toArray()).bind(sizeDisplay).onChange(sizeHandler)
        VNode("span", [sel], attrs: Some(HashMap<String, String>([("class", "el-pagination__sizes")])))
    }

    // ── jumper（回车跳页，值通过 action params.value 携带）──
    // 对齐 EP 结构（jumper.vue）：.el-pagination__jump
    //   > __goto（前往）+ el-input.el-pagination__editor.is-in-pagination（56px，同一元素双 class
    //     才能命中 .el-pagination__editor.el-input 规则）+ __classifier（页）
    // 之前裸 input（无 editor 包装）→ 无 56px 约束 → 输入框撑爆整行
    private func buildJumper(cp: Int64, pc: Int64): IComponent {
        let inputAttrs = HashMap<String, String>([("class", "el-input__inner"), ("type", "text"), ("value", cp.toString())])
        let inner = VNode("input", [], attrs: Some(inputAttrs)).onKeydown({ ctx => this.onJumperEnter(ctx) })
        let wrapper = VNode("div", [inner], attrs: Some(HashMap<String, String>([("class", "el-input__wrapper")])))
        let editor = VNode("div", [wrapper], attrs: Some(HashMap<String, String>([("class", "el-input el-pagination__editor is-in-pagination")])))
        let goto = VNode("span", [text("前往")], attrs: Some(HashMap<String, String>([("class", "el-pagination__goto")])))
        let classifier = VNode("span", [text("页")], attrs: Some(HashMap<String, String>([("class", "el-pagination__classifier")])))
        VNode("span", [goto, editor, classifier], attrs: Some(HashMap<String, String>([("class", "el-pagination__jump")])))
    }

    private func onJumperEnter(ctx: ActionContext): PatchResult {
        match (ctx.keyEvent) {
            case Some(ke) =>
                if (ke.isEnter()) {
                    let raw = match (ctx.params.get("value")) { case Some(v) => v; case None => "" }
                    let page = try { Int64.parse(raw) } catch (_) { -1 }
                    if (page >= 1) { return this.onNav(ctx, page) }
                }
            case None => ()
        }
        PatchResult.ReRender
    }

    // ── 导航 / 尺寸变更核心 ──
    private func onNav(ctx: ActionContext, page: Int64): PatchResult {
        if (this._disabled) { return PatchResult.ReRender }
        let pc = this.pageCount()
        let target = clampPage(page, pc)
        let cur = this.currentPage()
        if (target != cur) {
            this.setCurrentPage(target)
            this.invokeHandler(this._currentChangeHandler, ctx)
            this.invokeHandler(this._changeHandler, ctx)
        }
        PatchResult.ReRender
    }

    private func onSizeChanged(ctx: ActionContext, newSize: Int64): PatchResult {
        if (newSize <= 0) { return PatchResult.ReRender }
        let oldSize = this.pageSize()
        if (newSize != oldSize) {
            this.setPageSize(newSize)
            // 每页条数变化后，把页码夹取到新总页数范围内
            let pc = this.pageCount()
            let clamped = clampPage(this.currentPage(), pc)
            this.setCurrentPage(clamped)
            this.invokeHandler(this._sizeChangeHandler, ctx)
            this.invokeHandler(this._changeHandler, ctx)
        }
        PatchResult.ReRender
    }

    private func invokeHandler(h: Option<ActionHandler>, ctx: ActionContext): Unit {
        match (h) {
            case Some(fn) => runCb(fn, ctx)
            case None => ()
        }
    }
}

func runCb(fn: ActionHandler, ctx: ActionContext): Unit {
    let _ = fn(ctx)
    ()
}
