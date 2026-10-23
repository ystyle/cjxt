package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// ============ Splitter 分割面板（对齐 Element Plus splitter） ============
//
// EP 结构（splitter.vue + split-panel.vue + split-bar.vue）：
//   div.el-splitter.el-splitter__<layout>
//     ├─ div.el-splitter-panel[style=flex-basis:Npx]   ← 每个 SplitterPanel 一个
//     ├─ div.el-splitter-bar[style=width:0|height:0]   ← 面板之间的拖拽条
//     │    ├─ div.el-splitter-bar__collapse-icon.el-splitter-bar__<layout>-collapse-icon-start
//     │    ├─ div.el-splitter-bar__dragger.el-splitter-bar__dragger-<layout>
//     │    └─ div.el-splitter-bar__collapse-icon.el-splitter-bar__<layout>-collapse-icon-end
//     └─ div.el-splitter__mask.el-splitter__mask-<layout>   ← 仅拖拽期间（服务端无拖拽态，不渲染）
//
// 与 EP 的**必要偏差（尺寸换算）**：EP 的 useSize 把每个面板的 size 折算成
// 「占容器的百分比」，需要容器像素尺寸（ResizeObserver 测出来的），服务端拿不到。
// 所以这里改用 flex 的等效表达，**不依赖容器尺寸**：
//   - 显式 size（"50%" / "120px" / 裸数字 120）→ `flex-basis:<size>; flex-grow:0`
//   - 未给 size                                → `flex-basis:0; flex-grow:1`（平分剩余空间）
// 这在视觉上与 EP 的「指定尺寸保持、其余平分」一致：指定项按 basis 固定，
// 未指定项按 grow 均分剩下的部分。裸数字按 px 处理（EP 的 `Number(itemSize)` 同样当 px）。
//
// 折叠（EP 的 collapsible）：EP 靠 useResize.onCollapse 把尺寸在相邻面板间搬移；
// 这里用「折叠面板 basis=0 + grow=0，被吸收的邻居 grow=1」表达同一结果，
// 同样不需要容器尺寸。吸收方向与 EP 一致：点 start 图标 → 当前面板塌陷、空间给下一个；
// 点 end 图标 → 下一个面板塌陷、空间给当前。
//
// 拖拽改尺寸（2026-10-23 接入）：照 Slider 的既有模式，**不新增协议消息**——
//   dragger 挂 `data-bind-id`，前端 `attachSplitter` 在 pointermove 时按容器比例算新尺寸，
//   经标准 `bind` 消息回传（rAF 节流），服务端写份数信号后重渲染。
// 尺寸状态：`sizes(Signal<ArrayList<String>>)`，存每个面板的尺寸字符串（"40%" / "240px"）。
//   外置信号可跨渲染持久化；未给则用内部信号兜底（同 collapsedSignal 的模式）。
// 取舍（纯 bind 往返，不做前端乐观更新）：拖拽跟手但有一帧往返延迟（本地几 ms）。
//   要做到 EP 那种零延迟，需前端本地先改宽度、松手才上报——那会让前端持有临时状态，
//   与「状态都在服务端」的模型冲突，故未采用（见 docs 的能力边界章节）。

public class SplitterPanel <: Component {
    var _children: Array<IComponent>
    var _size: String = ""
    var _min: String = ""
    var _max: String = ""
    var _collapsible: Bool = false
    var _resizable: Bool = true

    public init(children: Array<IComponent>) { this._children = children }

    // size: "50%" | "240px" | "240"（裸数字按 px）。不设则该面板平分剩余空间。
    public func size(v: String): SplitterPanel { this._size = v; this }
    public func min(v: String): SplitterPanel { this._min = v; this }
    public func max(v: String): SplitterPanel { this._max = v; this }
    public func collapsible(): SplitterPanel { this._collapsible = true; this }
    public func resizable(v: Bool): SplitterPanel { this._resizable = v; this }

    // 面板自身不单独成树（由 Splitter 统一布局）；返回空容器保持槽位稳定
    public func render(): IComponent { div([]) }
}

public class Splitter <: Component {
    var _children: Array<IComponent>
    var _layout: SplitterLayout = SplitterLayout.Horizontal
    var _lazy: Bool = false
    // 折叠状态：面板下标的字符串形式（"0"/"2"…）。外置信号可跨渲染持久化；
    // 未给则用内部信号（同一页面内的 ReRender 有效，与 Collapse 内部状态同模式）。
    var _collapsedSignal: Option<Signal<ArrayList<String>>> = None
    var _fallbackCollapsed: Signal<ArrayList<String>> = Signal<ArrayList<String>>(ArrayList<String>())
    // 拖拽后的面板尺寸（与 SplitterPanel.size 同格式；为空则该面板用其 size 或平分）
    var _sizesSignal: Option<Signal<ArrayList<String>>> = None
    var _fallbackSizes: Signal<ArrayList<String>> = Signal<ArrayList<String>>(ArrayList<String>())

    public init(children: Array<IComponent>) { this._children = children }

    public func layout(v: SplitterLayout): Splitter { this._layout = v; this }
    // lazy：拖拽时只动偏移量、松开才落尺寸（EP 的 lazy）。服务端渲染体现为 dragger 的 is-lazy 类。
    public func lazy(): Splitter { this._lazy = true; this }
    public func bind(signal: Signal<ArrayList<String>>): Splitter { this._collapsedSignal = Some(signal); this }
    // 拖拽尺寸信号（每面板一个字符串，"40%" / "240px"）。外置可跨渲染持久化。
    public func sizes(signal: Signal<ArrayList<String>>): Splitter { this._sizesSignal = Some(signal); this }

    public func render(): IComponent {
        let panels = this.collectPanels()
        let collapsed = this.collapsedSet()
        let layoutCls = this._layout.asClass()
        let isHorizontal = layoutMatchesHorizontal(this._layout)
        let growFlags = this.computeGrowFlags(panels, collapsed)

        let children = ArrayList<IComponent>()
        var i = 0
        for (p in panels) {
            children.add(this.buildPanel(p, i, collapsed, growFlags, isHorizontal))
            if (i < panels.size - 1) {
                children.add(this.buildBar(panels, i, isHorizontal))
            }
            i = i + 1
        }

        let attrs = HashMap<String, String>([
            ("class", "el-splitter el-splitter__${layoutCls}"),
            ("data-splitter", layoutCls),
        ])
        VNode("div", children.toArray(), attrs: Some(attrs))
    }

    func collectPanels(): ArrayList<SplitterPanel> {
        let out = ArrayList<SplitterPanel>()
        for (c in this._children) {
            match (c) {
                case p: SplitterPanel => out.add(p)
                case _ => ()
            }
        }
        out
    }

    func collapsedSignal(): Signal<ArrayList<String>> {
        match (this._collapsedSignal) {
            case Some(s) => s
            case None => this._fallbackCollapsed
        }
    }

    func sizesSignal(): Signal<ArrayList<String>> {
        match (this._sizesSignal) {
            case Some(s) => s
            case None => this._fallbackSizes
        }
    }

    // 第 index 个面板的生效尺寸：拖拽尺寸优先，其次组件自带的 size
    func effectiveSize(p: SplitterPanel, index: Int64): String {
        let list = this.sizesSignal().get()
        if (index < list.size) {
            let v = list[index]
            if (v != "") { return v }
        }
        p._size
    }

    func collapsedSet(): HashMap<String, Bool> {
        let m = HashMap<String, Bool>()
        for (k in this.collapsedSignal().get()) { m[k] = true }
        m
    }

    // 哪些面板该「吸收」被折叠的空间（flex-grow:1）：
    //   未给 size 的面板天然 grow（平分剩余）；
    //   给定 size 的面板默认 grow=0，只有折叠发生时、作为其相邻吸收方的那一块才 grow=1。
    func computeGrowFlags(panels: ArrayList<SplitterPanel>, collapsed: HashMap<String, Bool>): ArrayList<Bool> {
        let flags = ArrayList<Bool>()
        var gi = 0
        for (p in panels) { flags.add(this.effectiveSize(p, gi) == ""); gi = gi + 1 }
        var i = 0
        while (i < panels.size - 1) {
            let hereCollapsed = collapsedContains(collapsed, "${i}")
            let nextCollapsed = collapsedContains(collapsed, "${i + 1}")
            // start 图标在上一条 bar 上：当前面板塌陷 → 空间给下一个
            if (hereCollapsed) { flags[i + 1] = true }
            // end 图标：下一个面板塌陷 → 空间给当前
            if (nextCollapsed) { flags[i] = true }
            i = i + 1
        }
        flags
    }

    // 面板内联样式只写 EP 没写进 CSS 的那部分（flex-basis/flex-grow 与 min/max 约束）。
    // `flex-grow:0` / `overflow:auto` / `box-sizing:border-box` 已在 splitter-panel.scss 里，
    // 不重复写（重复会让样式来源变两处，改 CSS 时对不上）。
    func buildPanel(p: SplitterPanel, index: Int64, collapsed: HashMap<String, Bool>, growFlags: ArrayList<Bool>, isHorizontal: Bool): IComponent {
        let isCollapsed = collapsedContains(collapsed, "${index}")
        let styles = ArrayList<String>()
        if (isCollapsed) {
            // 折叠：基数为 0 且不参与伸展（EP 把尺寸搬到邻居，这里等价表达）
            styles.add("flex-basis:0")
            styles.add("flex-grow:0")
            styles.add("flex-shrink:0")
        } else {
            // 显式 size 按 basis 固定；未给 size 则 basis=0 + grow=1 平分剩余
            let eff = this.effectiveSize(p, index)
            styles.add("flex-basis:${if (eff != "") { normalizePanelSize(eff) } else { "0" }}")
            styles.add("flex-grow:${if (growFlags[index]) { "1" } else { "0" }}")
            // 上下限落在 CSS 的 min/max 尺寸上（EP 的 min/max 只在拖拽时 clamp，
            // 但同样的约束用 CSS 表达对静态布局也成立，且不依赖容器尺寸）
            if (p._min != "") {
                let axis = if (isHorizontal) { "min-width" } else { "min-height" }
                styles.add("${axis}:${normalizePanelSize(p._min)}")
            }
            if (p._max != "") {
                let axis = if (isHorizontal) { "max-width" } else { "max-height" }
                styles.add("${axis}:${normalizePanelSize(p._max)}")
            }
        }
        let attrs = HashMap<String, String>([
            ("class", "el-splitter-panel"),
            ("style", joinStyleParts(styles)),
            ("data-splitter-panel", "${index}"),
        ])
        VNode("div", p._children, attrs: Some(attrs))
    }

    func buildBar(panels: ArrayList<SplitterPanel>, index: Int64, isHorizontal: Bool): IComponent {
        let layoutCls = this._layout.asClass()
        // EP split-bar.vue：horizontal 时条宽 0、竖向撑满；vertical 反之
        let barStyle = if (isHorizontal) { "width:0;height:100%" } else { "width:100%;height:0" }
        let parts = ArrayList<IComponent>()

        // start 折叠图标：当前面板可折叠（EP 的 startCollapsible）
        if (panels[index]._collapsible) {
            parts.add(this.buildCollapseIcon(index, true, layoutCls, isHorizontal))
        }

        // dragger：EP 的内联尺寸 + 光标（拖拽接线时按 pointer 事件测量）
        let thisPanel = panels[index]
        let nextPanel = panels[index + 1]
        let canResize = thisPanel._resizable && nextPanel._resizable
        let draggerStyles = ArrayList<String>()
        if (isHorizontal) {
            draggerStyles.add("width:16px")
            draggerStyles.add("height:100%")
        } else {
            draggerStyles.add("width:100%")
            draggerStyles.add("height:16px")
        }
        draggerStyles.add("touch-action:none")
        if (!canResize) {
            draggerStyles.add("cursor:auto")
        } else if (isHorizontal) {
            draggerStyles.add("cursor:ew-resize")
        } else {
            draggerStyles.add("cursor:ns-resize")
        }
        var draggerCls = "el-splitter-bar__dragger el-splitter-bar__dragger-${layoutCls}"
        if (!canResize) { draggerCls = "${draggerCls} is-disabled" }
        if (canResize && this._lazy) { draggerCls = "${draggerCls} is-lazy" }
        let draggerAttrs = HashMap<String, String>([
            ("class", draggerCls),
            ("style", joinStyleParts(draggerStyles)),
            ("data-splitter-bar", "${index}"),
        ])

        // 拖拽接线（照 Slider 的模式，不新增协议消息）：
        //   data-splitter-drag 让前端 attachSplitter 挂 pointer 监听；
        //   data-bind-id + handlers 让 pointermove 的尺寸变化经标准 bind 消息回传。
        // 回传值形如 "313px"（本次拖拽后左侧面板的新尺寸），由 handler 写进 sizes 信号。
        var hmap: Option<HashMap<String, ActionHandler>> = None
        if (canResize) {
            let bid = nextBid()
            draggerAttrs["data-splitter-drag"] = "1"
            draggerAttrs["data-bind-id"] = bid
            draggerAttrs["data-splitter-index"] = "${index}"
            if (isHorizontal) {
                draggerAttrs["data-splitter-axis"] = "horizontal"
            } else {
                draggerAttrs["data-splitter-axis"] = "vertical"
            }
            // 面板上下限透传给前端做 clamp（避免每次拖拽都往返问服务端）
            draggerAttrs["data-splitter-min"] = normalizePanelSize(if (thisPanel._min != "") { thisPanel._min } else { "0" })
            draggerAttrs["data-splitter-max"] = if (thisPanel._max != "") { normalizePanelSize(thisPanel._max) } else { "" }

            let m = HashMap<String, ActionHandler>()
            let idx = index
            m[bid] = { ctx =>
                let raw = match (ctx.params.get("value")) { case Some(x) => x case None => "" }
                if (raw != "") { this.applyDragSize(idx, raw) }
                PatchResult.ReRender
            }
            hmap = Some(m)
        }
        parts.add(VNode("div", [], attrs: Some(draggerAttrs), handlers: hmap))

        // end 折叠图标：下一个面板可折叠（EP 的 endCollapsible）
        if (nextPanel._collapsible) {
            parts.add(this.buildCollapseIcon(index + 1, false, layoutCls, isHorizontal))
        }

        let barAttrs = HashMap<String, String>([
            ("class", "el-splitter-bar"),
            ("style", barStyle),
        ])
        VNode("div", parts.toArray(), attrs: Some(barAttrs))
    }

    // 拖拽回传：把「第 index 个面板的新尺寸」写进 sizes 信号。
    // 只改被拖的那一块——其余面板由 flex 的 grow 规则自然吸收（与静态布局同一套规则），
    // 所以不必像 EP 那样同时改写相邻面板的尺寸。
    func applyDragSize(index: Int64, rawSize: String): Unit {
        let s = this.sizesSignal()
        let cur = s.get()
        let panels = this.collectPanels()
        let next = ArrayList<String>()
        var i = 0
        for (p in panels) {
            if (i == index) {
                next.add(rawSize)
            } else if (i < cur.size && cur[i] != "") {
                next.add(cur[i])
            } else {
                // 未拖过的面板沿用组件自带 size（空则继续平分）
                next.add(p._size)
            }
            i = i + 1
        }
        s.set(next)
    }

    // 折叠图标：horizontal 时 start=ArrowLeft / end=ArrowRight，vertical 时 start=ArrowUp / end=ArrowDown
    func buildCollapseIcon(panelIndex: Int64, isStart: Bool, layoutCls: String, isHorizontal: Bool): IComponent {
        let side = if (isStart) { "start" } else { "end" }
        let cls = "el-splitter-bar__collapse-icon el-splitter-bar__${layoutCls}-collapse-icon-${side}"
        let iconName = if (isHorizontal) { if (isStart) { "arrow-left" } else { "arrow-right" } }
            else { if (isStart) { "arrow-up" } else { "arrow-down" } }
        let icon = Icon(iconName).size("12px")
        let attrs = HashMap<String, String>([("class", cls)])
        let el = VNode("div", [icon], attrs: Some(attrs))
        el.onClick({ ctx => this.toggleCollapse(panelIndex) })
    }

    func toggleCollapse(panelIndex: Int64): PatchResult {
        let s = this.collapsedSignal()
        let key = "${panelIndex}"
        let next = ArrayList<String>()
        var found = false
        for (k in s.get()) {
            if (k == key) { found = true } else { next.add(k) }
        }
        if (!found) { next.add(key) }
        s.set(next)
        PatchResult.ReRender
    }
}

func collapsedContains(m: HashMap<String, Bool>, key: String): Bool {
    match (m.get(key)) {
        case Some(v) => v
        case None => false
    }
}

// 面板尺寸归一：带 % 或 px 的原样用；裸数字按 px（与 EP 的 Number(itemSize) 一致）
func normalizePanelSize(raw: String): String {
    let v = raw.trimAscii()
    if (v.endsWith("%") || v.endsWith("px")) { return v }
    "${v}px"
}

func layoutMatchesHorizontal(l: SplitterLayout): Bool {
    match (l) {
        case Horizontal => true
        case Vertical => false
    }
}
