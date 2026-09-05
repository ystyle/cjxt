package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}
import std.convert.*

public class InputNumber <: Component {
    var _signal: Option<Signal<Int64>> = None
    var _min: Int64 = -9223372036854775808
    var _max: Int64 = 9223372036854775807
    var _step: Int64 = 1
    var _size: Option<ComponentSize> = None
    var _disabled: Bool = false
    var _controls: Bool = true

    public init() {}
    public func min(v: Int64): InputNumber { this._min = v; this }
    public func max(v: Int64): InputNumber { this._max = v; this }
    public func step(v: Int64): InputNumber { this._step = v; this }
    public func size(v: ComponentSize): InputNumber { this._size = Some(v); this }
    public func disabled(): InputNumber { this._disabled = true; this }
    public func noControls(): InputNumber { this._controls = false; this }
    public func bind(signal: Signal<Int64>): InputNumber { this._signal = Some(signal); this }

    public func render(): IComponent {
        var cls = "el-input-number"
        match (this._size) {
            case Some(s) => cls = "${cls} el-input-number--${s.asClass()}"
            case None => ()
        }
        if (this._disabled) { cls = "${cls} is-disabled" }
        // EP 类名：is-without-controls（input-number.vue:7），旧代码 el-input-number--no-controls 在 SCSS 中不存在
        if (!this._controls) { cls = "${cls} is-without-controls" }

        let inputEl = this.buildInput()

        let children = ArrayList<IComponent>()
        if (this._controls) {
            let step = this._step
            let decDisabled = this.atMinBound()
            children.add(this.buildControl("decrease", "minus", decDisabled, { ctx => this.doStep(-step); PatchResult.ReRender }))
            children.add(inputEl)
            let incDisabled = this.atMaxBound()
            children.add(this.buildControl("increase", "plus", incDisabled, { ctx => this.doStep(step); PatchResult.ReRender }))
            VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
        } else {
            VNode("div", [inputEl], attrs: Some(HashMap<String, String>([("class", cls)])))
        }
    }

    // EP：decrease/increase 是 span.el-input-number__{decrease,increase}[is-disabled]，role=button，
    // 图标为 el-icon（minus/plus）。边界时 EP 置 is-disabled 且点击无效
    func buildControl(name: String, iconName: String, atBound: Bool, h: ActionHandler): IComponent {
        var btnCls = "el-input-number__${name}"
        if (atBound) { btnCls = "${btnCls} is-disabled" }
        let icon = Icon(iconName).render()
        var btn = VNode("span", [icon], attrs: Some(HashMap<String, String>([("class", btnCls), ("role", "button"), ("aria-label", name)])))
        // disabled 守卫：禁用态或已到边界时不挂 onClick（EP 由 disabled 输入 + min/max guard 拦截）
        if (!this._disabled && !atBound) { btn = btn.onClick(h) }
        btn
    }

    // EP：内部是完整 el-input（.el-input > .el-input__wrapper > input.el-input__inner），
    // 边框/圆角/背景来自 el-input__wrapper（el-input__inner 本身 border:none）——
    // 旧代码 div.el-input-number__input > input 导致输入框无边框
    func buildInput(): IComponent {
        let pa = HashMap<String, String>([("class", "el-input__inner"), ("type", "text")])
        match (this._signal) {
            case Some(s) => pa["value"] = s.get().toString()
            case None => ()
        }
        if (this._disabled) { pa["disabled"] = "disabled" }

        let inner = match (this._signal) {
            case Some(s) => this.buildBoundInput(pa, s)
            case None => VNode("input", [], attrs: Some(pa))
        }
        let wrapper = VNode("div", [inner], attrs: Some(HashMap<String, String>([("class", "el-input__wrapper")])))
        VNode("div", [wrapper], attrs: Some(HashMap<String, String>([("class", "el-input")])))
    }

    func buildBoundInput(attrs: HashMap<String, String>, s: Signal<Int64>): VNode {
        let bid = nextBid()
        attrs["data-bind-id"] = bid
        let hmap = HashMap<String, ActionHandler>()
        hmap[bid] = { ctx =>
            let raw = match (ctx.params.get("value")) { case Some(x) => x case None => "" }
            // 中间态输入（"-"、"3a" 等）不抛异常：解析失败保持原值
            match (doParseInt(raw)) {
                case Some(v) => s.set(v)
                case None => ()
            }
            PatchResult.ReRender
        }
        VNode("input", [], attrs: Some(attrs), handlers: Some(hmap))
    }

    func doStep(dir: Int64): Unit {
        match (this._signal) {
            case Some(s) => this.adjustValue(s, dir)
            case None => ()
        }
    }

    func adjustValue(s: Signal<Int64>, dir: Int64): Unit {
        let v = s.get() + dir
        if (v >= this._min && v <= this._max) { s.set(v) }
    }

    func atMinBound(): Bool {
        match (this._signal) {
            case Some(s) => s.get() <= this._min
            case None => false
        }
    }

    func atMaxBound(): Bool {
        match (this._signal) {
            case Some(s) => s.get() >= this._max
            case None => false
        }
    }
}

func doParseInt(raw: String): Option<Int64> {
    try {
        Some(Int64.parse(raw, radix: 10))
    } catch (e: Error) {
        None
    }
}
