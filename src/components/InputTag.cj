package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// 标签化输入（EP input-tag.vue）。DOM 与 EP 一致：
//   div.el-input-tag(+.is-focused/.is-disabled/--large/--small)
//     > div.el-input-tag__inner                       ← scss 的 gap/flex-wrap 挂在这一层
//         > span.el-tag.el-tag--{type} × N            ← 已有标签（closable 时带 el-tag__close）
//         > div.el-input-tag__input-wrapper
//             > input.el-input-tag__input
//     > div.el-input-tag__suffix（clearable 且有值时）
//         > i.el-input-tag__icon.el-input-tag__clear
//
// 与 EP 的两处必要偏差（都源于「服务端驱动、组件实例不跨页渲染复用」）：
//   ① 草稿文本**不存内部信号**：组件重渲染会新建实例，内部状态随之丢失；
//      改为每次从 action 的 `value` 参数现取（前端 collectParams 会把 input 当前值带上）。
//   ② 没有通用 focus/blur 事件注入，`is-focused` 由调用方通过外置 Signal 驱动。
public class InputTag <: Component {
    var _signal: Option<Signal<ArrayList<String>>> = None
    var _placeholder: String = ""
    var _max: Int64 = -1
    var _disabled: Bool = false
    var _readonly: Bool = false
    var _clearable: Bool = false
    var _size: Option<ComponentSize> = None
    var _tagType: TagKind = TagKind.Info
    var _tagEffect: TagEffect = TagEffect.Light
    var _delimiter: String = ""
    var _saveOnBlur: Bool = false
    var _ariaLabel: String = ""
    var _maxlength: Int64 = -1
    var _focus: Option<Signal<Bool>> = None

    public init() {}
    public func bind(signal: Signal<ArrayList<String>>): InputTag { this._signal = Some(signal); this }
    public func placeholder(v: String): InputTag { this._placeholder = v; this }
    // 标签数量上限（EP max）：已达上限后不再接受新值
    public func max(v: Int64): InputTag { this._max = v; this }
    public func disabled(): InputTag { this._disabled = true; this }
    public func readonly(): InputTag { this._readonly = true; this }
    public func clearable(): InputTag { this._clearable = true; this }
    public func size(v: ComponentSize): InputTag { this._size = Some(v); this }
    public func tagType(v: TagKind): InputTag { this._tagType = v; this }
    public func tagEffect(v: TagEffect): InputTag { this._tagEffect = v; this }
    // 输入中遇到该字符串即成 tag（EP delimiter 的字符串形态）
    public func delimiter(v: String): InputTag { this._delimiter = v; this }
    // 失焦时把未提交的输入存成 tag（EP 默认 true；cjxt 无通用 blur 事件，故默认关闭，
    // 打开后走 input 的 blur 监听——若元素在补丁中被重建，blur 可能误触发，按需启用）
    public func saveOnBlur(): InputTag { this._saveOnBlur = true; this }
    public func ariaLabel(v: String): InputTag { this._ariaLabel = v; this }
    public func maxlength(v: Int64): InputTag { this._maxlength = v; this }
    // 外置焦点信号：驱动 is-focused 态（scss 的聚焦描边）
    public func focused(signal: Signal<Bool>): InputTag { this._focus = Some(signal); this }

    public func render(): IComponent {
        let values = this.currentValues()
        var cls = "el-input-tag"
        let sc = match (this._size) { case Some(s) => s.asClass(); case None => "" }
        if (sc != "") { cls = "${cls} el-input-tag--${sc}" }
        if (this.isFocused()) { cls = "${cls} is-focused" }
        if (this._disabled) { cls = "${cls} is-disabled" }

        let rootAttrs = HashMap<String, String>([("class", cls), ("data-input-tag", "1")])
        if (this._ariaLabel != "") { rootAttrs["aria-label"] = this._ariaLabel }

        let innerChildren = ArrayList<IComponent>()
        for (v in values) { innerChildren.add(this.buildTag(v)) }
        innerChildren.add(this.buildInputWrapper(values.size))
        let inner = VNode("div", innerChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-input-tag__inner")])))

        let children = ArrayList<IComponent>()
        children.add(inner)
        if (this._clearable && values.size > 0 && !this._disabled) { children.add(this.buildClear()) }
        VNode("div", children.toArray(), attrs: Some(rootAttrs))
    }

    func isFocused(): Bool {
        match (this._focus) {
            case Some(s) => s.get()
            case None => false
        }
    }

    func currentValues(): ArrayList<String> {
        match (this._signal) {
            case Some(s) => s.get()
            case None => ArrayList<String>()
        }
    }

    // 已达上限后不再接受新值（EP inputLimit）
    func atLimit(count: Int64): Bool {
        this._max >= 0 && count >= this._max
    }

    func buildTag(value: String): IComponent {
        var cls = "el-tag"
        let tc = this._tagType.asClass()
        if (tc != "") { cls = "${cls} el-tag--${tc}" }
        let sc = match (this._size) { case Some(s) => s.asClass(); case None => "" }
        if (sc != "") { cls = "${cls} el-tag--${sc}" }
        cls = "${cls} el-tag--${this._tagEffect.asClass()}"
        let closable = !this._disabled && !this._readonly
        if (closable) { cls = "${cls} is-closable" }

        let content = ArrayList<IComponent>()
        content.add(span([text(value)], attrs: Some(HashMap<String, String>([("class", "el-tag__content")]))))
        if (closable) {
            let closeEl = VNode("button", [Icon("close").render()], attrs: Some(HashMap<String, String>([("class", "el-tag__close"), ("type", "button"), ("aria-label", "close")])))
            let v = value
            content.add(closeEl.onClick({ ctx =>
                this.removeValue(v)
                PatchResult.ReRender
            }))
        }
        VNode("span", content.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
    }

    func buildInputWrapper(count: Int64): IComponent {
        let inputAttrs = HashMap<String, String>()
        inputAttrs["class"] = "el-input-tag__input"
        inputAttrs["type"] = "text"
        inputAttrs["autocomplete"] = "off"
        // EP：已有 tag 时 placeholder 让位（只有空列表才显示）
        if (this._placeholder != "" && count == 0) { inputAttrs["placeholder"] = this._placeholder }
        if (this._disabled) { inputAttrs["disabled"] = "disabled" }
        if (this._readonly) { inputAttrs["readonly"] = "readonly" }
        if (this._maxlength > 0) { inputAttrs["maxlength"] = this._maxlength.toString() }

        let inputEl = if (this._disabled || this._readonly) {
            VNode("input", [], attrs: Some(inputAttrs))
        } else {
            this.buildLiveInput(inputAttrs)
        }
        VNode("div", [inputEl], attrs: Some(HashMap<String, String>([("class", "el-input-tag__input-wrapper")])))
    }

    // 可交互输入框：bind（草稿回传）+ keydown（回车成 tag / 空输入退格删末位）共用一张 handlers 表。
    // 必须**一次构造**挂好——on()/onClick() 都会重建 VNode，后挂会把先前挂的 handlers 吞掉
    // （见 AGENTS「VNode.onClick 重建节点丢弃已有 handlers」）。
    func buildLiveInput(baseAttrs: HashMap<String, String>): VNode {
        let attrs = HashMap<String, String>()
        for ((k, v) in baseAttrs) { attrs[k] = v }

        let handlers = HashMap<String, ActionHandler>()
        let actions = HashMap<String, String>()

        // 输入（含分隔符即时切分）：前端 attachBind 会把 input 当前值放在 params.value
        let bid = nextBid()
        attrs["data-bind-id"] = bid
        handlers[bid] = { ctx =>
            let raw = this.paramValue(ctx)
            if (this.handleInput(raw)) { PatchResult.ReRender } else { PatchResult.Patch([]) }
        }

        // 键盘：Enter 提交；空输入时 Backspace 删末位标签（EP handleKeydown）
        let hid = nextHid()
        actions["keydown"] = hid
        handlers[hid] = { ctx =>
            if (this.handleKeydown(ctx)) { PatchResult.ReRender } else { PatchResult.Patch([]) }
        }

        if (this._saveOnBlur) {
            let blurHid = nextHid()
            actions["blur"] = blurHid
            handlers[blurHid] = { ctx =>
                let raw = this.paramValue(ctx)
                if (this.appendValue(raw)) { PatchResult.ReRender } else { PatchResult.Patch([]) }
            }
        }

        VNode("input", [], attrs: Some(attrs), actions: Some(actions), handlers: Some(handlers))
    }

    func buildClear(): IComponent {
        let clearEl = span([], attrs: Some(HashMap<String, String>([("class", "el-input-tag__icon el-input-tag__clear")])))
        VNode("div", [
            clearEl.onClick({ ctx =>
                match (this._signal) {
                    case Some(s) => s.set(ArrayList<String>())
                    case None => ()
                }
                PatchResult.ReRender
            })
        ], attrs: Some(HashMap<String, String>([("class", "el-input-tag__suffix")])))
    }

    func paramValue(ctx: ActionContext): String {
        match (ctx.params.get("value")) {
            case Some(v) => v
            case None => ""
        }
    }

    // 输入变化：命中分隔符就切分追加（EP delimiter），返回是否有值被写入
    func handleInput(raw: String): Bool {
        if (raw == "") { return false }
        if (this.atLimit(this.currentValues().size)) { return false }
        if (this._delimiter == "" || !raw.contains(this._delimiter)) { return false }
        var changed = false
        for (p in this.splitBy(raw, this._delimiter)) {
            if (this.appendValue(p)) { changed = true }
        }
        changed
    }

    // 键盘：Enter 提交当前输入；空输入时 Backspace 删末位（EP handleKeydown）
    func handleKeydown(ctx: ActionContext): Bool {
        match (ctx.keyEvent) {
            case None => false
            case Some(ev) =>
                if (ev.isEnter()) {
                    return this.appendValue(this.paramValue(ctx))
                }
                if (ev.key == "Backspace" && this.paramValue(ctx) == "") {
                    let values = this.currentValues()
                    if (values.size > 0) {
                        this.removeValue(values[values.size - 1])
                        return true
                    }
                }
                false
        }
    }

    // 追加一个标签（去空白、去重、受 max 限制）；返回是否真的写入
    func appendValue(raw: String): Bool {
        let v = raw.trimAscii()
        if (v == "") { return false }
        let values = this.currentValues()
        if (this.atLimit(values.size)) { return false }
        if (this.listContains(values, v)) { return false }
        match (this._signal) {
            case Some(s) =>
                let next = ArrayList<String>(values)
                next.add(v)
                s.set(next)
                true
            case None => false
        }
    }

    func removeValue(v: String): Unit {
        match (this._signal) {
            case Some(s) =>
                let next = ArrayList<String>()
                for (x in this.currentValues()) {
                    if (x != v) { next.add(x) }
                }
                s.set(next)
            case None => ()
        }
    }

    func listContains(list: ArrayList<String>, v: String): Bool {
        for (x in list) { if (x == v) { return true } }
        false
    }

    // 按分隔符切分（String 没有 split 的分隔符重载语义保证，手写 indexOf 循环）
    func splitBy(raw: String, delim: String): ArrayList<String> {
        let out = ArrayList<String>()
        if (delim == "") {
            if (raw != "") { out.add(raw) }
            return out
        }
        var rest = raw
        var searching = true
        while (searching) {
            match (rest.indexOf(delim)) {
                case Some(idx) =>
                    let head = rest[0..idx]
                    if (head.trimAscii() != "") { out.add(head) }
                    rest = rest[idx + delim.size..]
                case None =>
                    if (rest.trimAscii() != "") { out.add(rest) }
                    searching = false
            }
        }
        out
    }
}
