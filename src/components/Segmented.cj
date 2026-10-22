package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ── Segmented 分段控制器 ──────────────────────────────────────────────────────
//
// 对齐 element-plus segmented/src/segmented.vue：
//
//   div.el-segmented[.el-segmented--{size}][.is-block][role=radiogroup]
//     div.el-segmented__group.el-segmented--{direction}
//       div.el-segmented__item-selected[.is-disabled]      ← 选中态滑块（absolute，随选中项移动）
//       label.el-segmented__item[.is-selected][.is-disabled]
//         input.el-segmented__item-input[type=radio][name][checked][disabled]
//         div.el-segmented__item-label
//
// 与 EP 的一处必要差异（滑块的定位方式）：
// EP 用 ResizeObserver 量选中项 offsetWidth/offsetLeft，再写 `width/transform`。
// 服务端没有布局信息，而 `.el-segmented__item { flex: 1 }` 让各项**等宽**，
// 所以位置可以纯计算：横向 `width: calc(100% / n)` + `translateX(calc(100% * i))`，
// 纵向换成 height/translateY。结果与 EP 在等宽项下逐像素一致，且不需要前端 JS。
// 若某项被内容撑开（EP 的 min-width:auto）会略有偏差——scss 的 `__item-label` 是 ellipsis，
// 实践中各项基本等宽；这一取舍写在组件里，不藏着。
//
// 选中值 `bind(Signal<String>)` 驱动；option 的 value 即绑定值（EP 的 modelValue 口径）。

// 分段项。EP 的 options 接受 Record | string | number，这里收敛成显式类型：
// 纯文本项用 Segmented.textOptions(...) 便捷构造，需要禁用/自定义 value 时用本类。
public class SegmentedOption {
    let _label: String
    let _value: String
    var _disabled: Bool = false

    public init(label: String, value: String) {
        this._label = label
        this._value = value
    }
    // 值与显示文本相同
    public init(label: String) {
        this._label = label
        this._value = label
    }

    public func disabled(): SegmentedOption { this._disabled = true; this }
}

public class Segmented <: Component {
    var _options: ArrayList<SegmentedOption> = ArrayList<SegmentedOption>()
    var _signal: Option<Signal<String>> = Option<Signal<String>>.None
    var _direction: String = "horizontal"   // horizontal | vertical（EP values）
    var _block: Bool = false
    var _size: Option<ComponentSize> = Option<ComponentSize>.None
    var _disabled: Bool = false
    var _name: String = ""
    var _ariaLabel: String = ""

    public init(options: Array<SegmentedOption>) {
        for (o in options) { this._options.add(o) }
    }
    // 纯文本项
    public static func textOptions(labels: Array<String>): Array<SegmentedOption> {
        let out = ArrayList<SegmentedOption>()
        for (l in labels) { out.add(SegmentedOption(l)) }
        out.toArray()
    }

    public func bind(s: Signal<String>): Segmented { this._signal = Some(s); this }
    public func direction(v: String): Segmented { this._direction = v; this }
    public func block(): Segmented { this._block = true; this }
    public func size(v: ComponentSize): Segmented { this._size = Some(v); this }
    public func disabled(): Segmented { this._disabled = true; this }
    public func name(v: String): Segmented { this._name = v; this }
    public func ariaLabel(v: String): Segmented { this._ariaLabel = v; this }

    public func render(): IComponent {
        // EP：options 为空时整个组件不渲染（v-if="options.length"）
        if (this._options.size == 0) { return EmptyVNode() }

        let selected = this.selectedValue()
        let total = this._options.size
        let selIdx = this.indexOfValue(selected)

        let items = ArrayList<IComponent>()
        // 滑块先于各项渲染（absolute 定位，DOM 顺序与 EP 一致）
        items.add(this.buildSelectedBar(selIdx, total))
        var i = 0
        for (o in this._options) {
            items.add(this.buildItem(o, i, i == selIdx))
            i += 1
        }

        let groupCls = "el-segmented__group el-segmented--${this._direction}"
        let group = VNode("div", items.toArray(), attrs: Some(HashMap<String, String>([
            ("class", groupCls)
        ])))

        var rootCls = "el-segmented"
        match (this._size) {
            case Some(s) =>
                let c = s.asClass()
                // ComponentSize.Default 的 asClass() 是空串，此时不加 size 类（EP 默认档无修饰类）
                if (c != "") { rootCls = "${rootCls} el-segmented--${c}" }
            case None => ()
        }
        if (this._block) { rootCls = "${rootCls} is-block" }

        let attrs = HashMap<String, String>([
            ("class", rootCls),
            ("role", "radiogroup")
        ])
        if (this._ariaLabel != "") { attrs["aria-label"] = this._ariaLabel }
        VNode("div", [group], attrs: Some(attrs))
    }

    func selectedValue(): String {
        match (this._signal) {
            case Some(s) => s.get()
            case None => ""
        }
    }

    func indexOfValue(v: String): Int64 {
        var i = 0
        for (o in this._options) {
            if (o._value == v) { return i }
            i += 1
        }
        -1
    }

    // 选中态滑块：等分几何由服务端算（见文件头说明）
    func buildSelectedBar(selIdx: Int64, total: Int64): IComponent {
        var cls = "el-segmented__item-selected"
        // EP：选中项被禁用时滑块也带 is-disabled（scss 换成禁用底色）
        if (this.itemDisabled(this.indexOfValue(this.selectedValue()))) { cls = "${cls} is-disabled" }
        let vertical = this._direction == "vertical"
        var style = ""
        if (selIdx < 0) {
            // 无选中：EP 的 isInit=false → display:none
            style = "display:none"
        } else if (vertical) {
            style = "width:100%;height:calc(100% / ${total});transform:translateY(calc(100% * ${selIdx}))"
        } else {
            style = "width:calc(100% / ${total});height:100%;transform:translateX(calc(100% * ${selIdx}))"
        }
        VNode("div", [], attrs: Some(HashMap<String, String>([
            ("class", cls),
            ("style", style)
        ])))
    }

    func itemDisabled(idx: Int64): Bool {
        if (this._disabled) { return true }
        if (idx < 0 || idx >= this._options.size) { return false }
        this._options[idx]._disabled
    }

    func buildItem(o: SegmentedOption, idx: Int64, isSelected: Bool): IComponent {
        let dis = this.itemDisabled(idx)
        var labelCls = "el-segmented__item"
        if (isSelected) { labelCls = "${labelCls} is-selected" }
        if (dis) { labelCls = "${labelCls} is-disabled" }

        let inputAttrs = HashMap<String, String>([
            ("class", "el-segmented__item-input"),
            ("type", "radio")
        ])
        if (this._name != "") { inputAttrs["name"] = this._name }
        if (isSelected) { inputAttrs["checked"] = "checked" }
        if (dis) { inputAttrs["disabled"] = "disabled" }
        let inputEl = VNode("input", [], attrs: Some(inputAttrs))
        let labelEl = VNode("div", [text(o._label)], attrs: Some(HashMap<String, String>([
            ("class", "el-segmented__item-label")
        ])))

        let label = VNode("label", [inputEl, labelEl], attrs: Some(HashMap<String, String>([
            ("class", labelCls)
        ])))
        match (this._signal) {
            case Some(s) => if (dis) { label } else { label.onClick(segmentSelectAction(s, o._value)) }
            case None => label
        }
    }
}

// 选中动作：写信号 → ReRender。独立函数便于单测直接调用（不经 DOM）
func segmentSelectAction(s: Signal<String>, v: String): ActionHandler {
    let handler: ActionHandler = { ctx =>
        s.set(v)
        PatchResult.ReRender
    }
    handler
}
