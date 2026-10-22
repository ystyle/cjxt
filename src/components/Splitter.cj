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
// **未实现**：拖拽改尺寸（EP 的 mouse/touch 拖动）。它需要前端按 pointer 事件实时测量
// 容器与相邻面板的像素宽度，属于 `public/js/cangjie-ui.js` 的机制（对照已有
// `data-slider` 的实现），不在本组件可控范围内；本组件已把 DOM 与 `data-splitter-*`
// 标记按 EP 结构备好，接线时无需改结构。

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

    public init(children: Array<IComponent>) { this._children = children }

    public func layout(v: SplitterLayout): Splitter { this._layout = v; this }
    // lazy：拖拽时只动偏移量、松开才落尺寸（EP 的 lazy）。服务端渲染体现为 dragger 的 is-lazy 类。
    public func lazy(): Splitter { this._lazy = true; this }
    public func bind(signal: Signal<ArrayList<String>>): Splitter { this._collapsedSignal = Some(signal); this }

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
        for (p in panels) { flags.add(p._size == "") }
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
            styles.add("flex-basis:${if (p._size != "") { normalizePanelSize(p._size) } else { "0" }}")
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
        parts.add(VNode("div", [], attrs: Some(draggerAttrs)))

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
