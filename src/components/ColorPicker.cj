package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// ============ ColorPicker 颜色选择器（对齐 Element Plus color-picker，简化实现） ============
//
// EP 结构（color-picker.vue + color-picker-panel）：
//   div.el-color-picker[.is-disabled][.el-color-picker--<size>]
//     └─ div.el-color-picker__trigger                    ← 点击开面板
//          └─ span.el-color-picker__color
//               └─ span.el-color-picker__color-inner[style=background-color:<color>]
//                    └─ i.el-color-picker__icon（有值时箭头 / i.el-color-picker__empty 无值时空态）
//   面板（EP 用 el-tooltip 挂到 body）：
//   div.el-color-picker__panel.el-popper > div.el-color-picker-panel > 色板 / 饱和度区 / 色相条 / alpha 条
//     > div.el-color-picker-panel__footer > button（清空 / 确定）
//
// **简化说明（如实记录）**：
// EP 的完整面板是「饱和度-明度二维拖拽区 + 色相条 + alpha 条 + 十六进制输入框」，
// 全部依赖 pointer 拖拽与实时色彩空间换算（hsv↔rgb↔hex）。服务端组件没有 pointer 事件，
// 因此面板改为**预设色板网格**：点击一个色块即写入绑定信号并关闭面板。
// 保留的结构与语义：触发器 DOM 完全对齐 EP（__trigger / __color / __color-inner /
// __icon / __empty）、面板容器类名（__panel + el-color-picker-panel）、footer 的清空/确定。
//
// **未实现**：`showAlpha`（透明度滑条）、自由取色（饱和度区拖拽）、十六进制手输。
// 这三项都需要客户端实时交互，不是服务端渲染能覆盖的。

// 默认预设色板：EP 的 picker 面板没有内置预设色板（它是自由取色 + 一个预定义色板区），
// 这里给一组 Element Plus 主题色系常用色，覆盖 primary/success/warning/danger/info 的深浅阶。
func defaultColorPresets(): ArrayList<String> {
    ArrayList<String>([
        "#409eff", "#79bbff", "#a0cfff", "#c6e2ff", "#d9ecff",
        "#67c23a", "#95d475", "#b3e19d", "#d1edc4", "#e1f3d8",
        "#e6a23c", "#eebe77", "#f3d19e", "#f8e3c5", "#faecd8",
        "#f56c6c", "#f89898", "#fab6b6", "#fcd3d3", "#fde2e2",
        "#909399", "#a6a9ad", "#b1b3b8", "#c0c4cc", "#dcdfe6",
        "#303133", "#606266", "#595959", "#000000", "#ffffff",
    ])
}

public class ColorPicker <: Component {
    var _valueSignal: Option<Signal<String>> = None
    var _fallbackValue: Signal<String> = Signal<String>("")
    // 面板开关：外置信号可跨渲染持久化（EP 的 showPicker）
    var _openSignal: Option<Signal<Bool>> = None
    var _fallbackOpen: Signal<Bool> = Signal<Bool>(false)
    var _presets: ArrayList<String> = defaultColorPresets()
    var _disabled: Bool = false
    var _clearable: Bool = true
    var _size: ComponentSize = ComponentSize.Default
    var _onChange: Option<ActionHandler> = None

    public init() {}

    public func bind(signal: Signal<String>): ColorPicker { this._valueSignal = Some(signal); this }
    public func bindOpen(signal: Signal<Bool>): ColorPicker { this._openSignal = Some(signal); this }
    // 自定义预设色板（替换默认那组）
    public func presets(colors: ArrayList<String>): ColorPicker { this._presets = colors; this }
    public func disabled(): ColorPicker { this._disabled = true; this }
    public func clearable(v: Bool): ColorPicker { this._clearable = v; this }
    public func size(v: ComponentSize): ColorPicker { this._size = v; this }
    public func onChange(h: ActionHandler): ColorPicker { this._onChange = Some(h); this }

    public func render(): IComponent {
        let value = this.valueSignal().get()
        let open = this.openSignal().get() && !this._disabled

        let parts = ArrayList<IComponent>()
        parts.add(this.buildTrigger(value))
        // 面板恒渲染 + 用 EmptyVNode 之外的方式控制可见性：EP 是 persistent（DOM 常在，display 切换）
        if (open) {
            parts.add(this.buildPanel(value))
        }

        var rootCls = "el-color-picker"
        if (this._disabled) { rootCls = "${rootCls} is-disabled" }
        match (this._size) {
            case Large => rootCls = "${rootCls} el-color-picker--large"
            case Small => rootCls = "${rootCls} el-color-picker--small"
            case Default => ()
        }
        VNode("div", parts.toArray(), attrs: Some(HashMap<String, String>([
            ("class", rootCls),
            ("role", "button"),
            ("tabindex", "0"),
        ])))
    }

    func valueSignal(): Signal<String> {
        match (this._valueSignal) {
            case Some(s) => s
            case None => this._fallbackValue
        }
    }

    func openSignal(): Signal<Bool> {
        match (this._openSignal) {
            case Some(s) => s
            case None => this._fallbackOpen
        }
    }

    // ── 触发器（DOM 对齐 EP） ──
    func buildTrigger(value: String): IComponent {
        let hasValue = value != ""
        let innerStyle = if (hasValue) { "background-color:${value}" } else { "" }
        let innerParts = ArrayList<IComponent>()
        if (hasValue) {
            innerParts.add(VNode("i", [], attrs: Some(HashMap<String, String>([
                ("class", "el-color-picker__icon is-icon-arrow-down"),
            ]))))
        } else {
            innerParts.add(VNode("i", [], attrs: Some(HashMap<String, String>([
                ("class", "el-color-picker__empty is-icon-close"),
            ]))))
        }
        let innerAttrs = HashMap<String, String>([("class", "el-color-picker__color-inner")])
        if (innerStyle != "") { innerAttrs["style"] = innerStyle }
        let color = VNode("span", [
            VNode("span", innerParts.toArray(), attrs: Some(innerAttrs)),
        ], attrs: Some(HashMap<String, String>([("class", "el-color-picker__color")])))

        var trigger = VNode("div", [color], attrs: Some(HashMap<String, String>([
            ("class", "el-color-picker__trigger"),
        ])))
        if (!this._disabled) {
            trigger = trigger.onClick({ ctx => this.togglePanel(ctx) })
        }
        trigger
    }

    // ── 面板：预设色板网格 + footer ──
    func buildPanel(value: String): IComponent {
        let swatches = ArrayList<IComponent>()
        for (c in this._presets) {
            var cellCls = "el-color-picker__swatch"
            if (c == value) { cellCls = "${cellCls} is-selected" }
            let cellAttrs = HashMap<String, String>([
                ("class", cellCls),
                ("style", "background-color:${c};width:24px;height:24px;cursor:pointer;border-radius:2px;box-sizing:border-box"),
                ("title", c),
                ("data-color", c),
            ])
            var cell = VNode("div", [], attrs: Some(cellAttrs))
            let picked = c
            cell = cell.onClick({ ctx => this.pick(picked, ctx) })
            swatches.add(cell)
        }
        // 网格容器：30 色按 6 列排（EP 的色板是 flex-wrap 布局）
        let grid = VNode("div", swatches.toArray(), attrs: Some(HashMap<String, String>([
            ("class", "el-color-picker-panel__swatches"),
            ("style", "display:flex;flex-wrap:wrap;gap:6px;max-width:180px"),
        ])))

        // footer：清空 / 确定（对齐 EP 的 footer 两个按钮）
        let footerParts = ArrayList<IComponent>()
        if (this._clearable) {
            let clearBtn = VNode("button", [text("清空")], attrs: Some(HashMap<String, String>([
                ("class", "el-button el-button--small is-text el-color-picker-panel__link-btn"),
                ("type", "button"),
            ])))
            footerParts.add(clearBtn.onClick({ ctx => this.clear(ctx) }))
        }
        let confirmBtn = VNode("button", [text("确定")], attrs: Some(HashMap<String, String>([
            ("class", "el-button el-button--small is-plain el-color-picker-panel__btn"),
            ("type", "button"),
        ])))
        footerParts.add(confirmBtn.onClick({ ctx => this.confirm(ctx) }))
        let footer = VNode("div", footerParts.toArray(), attrs: Some(HashMap<String, String>([
            ("class", "el-color-picker-panel__footer"),
            ("style", "display:flex;justify-content:flex-end;gap:8px;margin-top:12px"),
        ])))

        let panelInner = VNode("div", [grid, footer], attrs: Some(HashMap<String, String>([
            ("class", "el-color-picker-panel"),
            ("style", "padding:12px;box-sizing:content-box"),
        ])))
        // 面板定位：EP 用 tooltip 挂载；这里贴着触发器下方绝对定位（父级 .el-color-picker 是 relative）
        VNode("div", [panelInner], attrs: Some(HashMap<String, String>([
            ("class", "el-color-picker__panel el-popper"),
            ("style", "position:absolute;top:100%;left:0;margin-top:8px;z-index:2000"),
        ])))
    }

    // ── 交互 ──
    func togglePanel(ctx: ActionContext): PatchResult {
        let s = this.openSignal()
        s.set(!s.get())
        PatchResult.ReRender
    }

    // 点色块：写入值 + 关闭面板 + 回调
    func pick(color: String, ctx: ActionContext): PatchResult {
        this.valueSignal().set(color)
        this.openSignal().set(false)
        match (this._onChange) {
            case Some(fn) => runCb(fn, ctx)
            case None => ()
        }
        PatchResult.ReRender
    }

    func clear(ctx: ActionContext): PatchResult {
        this.valueSignal().set("")
        this.openSignal().set(false)
        match (this._onChange) {
            case Some(fn) => runCb(fn, ctx)
            case None => ()
        }
        PatchResult.ReRender
    }

    // 确定：保留当前值、只关面板（EP 的 confirmValue）
    func confirm(ctx: ActionContext): PatchResult {
        this.openSignal().set(false)
        PatchResult.ReRender
    }
}
