package cjxt.components

import cjxt.*
import cjxt.selectMoveHighlight
import cjxt.selectHighlightValid
import std.collection.{HashMap, ArrayList}

public class SelectOption <: Component {
    var _children: Array<IComponent>
    var _value: String
    var _disabled: Bool = false

    public init(children: Array<IComponent>, value: String) {
        this._children = children
        this._value = value
    }
    public func disabled(): SelectOption { this._disabled = true; this }

    public func render(): IComponent { VNode("li", this._children, attrs: Some(HashMap<String, String>([("class", "el-select-dropdown__item")]))) }

    func optionAttrs(selected: Bool, disabled: Bool, highlighted: Bool): HashMap<String, String> {
        var cls = "el-select-dropdown__item"
        if (selected) { cls = "${cls} is-selected" }
        if (disabled) { cls = "${cls} is-disabled" }
        if (highlighted) { cls = "${cls} is-hovering" }
        let a = HashMap<String, String>([("class", cls), ("role", "option"), ("aria-selected", if (selected) { "true" } else { "false" })])
        if (disabled) { a["aria-disabled"] = "true" }
        a
    }

    func renderItem(currentValue: String, signal: Signal<String>, openSignal: Signal<Bool>, onChange: Option<ActionHandler>, highlighted: Bool): IComponent {
        let selected = this._value == currentValue
        let attrs = this.optionAttrs(selected, this._disabled, highlighted)
        let v = this._value
        let s = signal
        let o = openSignal
        let cb = onChange
        let item = VNode("li", this._children, attrs: Some(attrs))
        if (this._disabled) { item } else {
            item.onClick({ ctx =>
                s.set(v)
                o.set(false)
                let r = match (cb) {
                    case Some(fn) => fn(ctx)
                    case None => ()
                }
                let _ = r
                PatchResult.ReRender
            })
        }
    }

    func renderItemMulti(selectedValues: ArrayList<String>, multiSignal: Signal<ArrayList<String>>, openSignal: Signal<Bool>, highlighted: Bool): IComponent {
        let selected = isSelected(selectedValues, this._value)
        let attrs = this.optionAttrs(selected, this._disabled, highlighted)
        let v = this._value
        let ms = multiSignal
        let item = VNode("li", this._children, attrs: Some(attrs))
        if (this._disabled) { item } else {
            item.onClick({ ctx =>
                let list = ms.get()
                if (isSelected(list, v)) {
                    let idx = findIndex(list, v)
                    if (idx >= 0) { list.remove(idx..idx + 1) }
                } else {
                    list.add(v)
                }
                ms.set(list)
                PatchResult.ReRender
            })
        }
    }
}

public class Select <: Component {
    var _signal: Option<Signal<String>> = None
    var _multiSignal: Option<Signal<ArrayList<String>>> = None
    var _children: Array<IComponent>
    var _placeholder: String = ""
    var _disabled: Bool = false
    var _multiple: Bool = false
    var _clearable: Bool = false
    var _filterable: Bool = false
    var _open: Signal<Bool>
    var _filterText: Signal<String>
    var _highlight: Signal<Int64>
    var _onChange: Option<ActionHandler> = None

    public init(children: Array<IComponent>) {
        this._children = children
        this._open = Signal<Bool>(false)
        this._filterText = Signal<String>("")
        this._highlight = Signal<Int64>(-1)
    }
    public func bind(signal: Signal<String>): Select { this._signal = Some(signal); this }
    public func bindMulti(signal: Signal<ArrayList<String>>): Select { this._multiSignal = Some(signal); this }
    public func placeholder(v: String): Select { this._placeholder = v; this }
    public func disabled(): Select { this._disabled = true; this }
    public func multiple(): Select { this._multiple = true; this }
    public func clearable(): Select { this._clearable = true; this }
    public func filterable(): Select { this._filterable = true; this }
    // 单选选项选中后回调（值已写入信号）
    public func onChange(h: ActionHandler): Select { this._onChange = Some(h); this }

    public func render(): IComponent {
        let isOpen = this._open.get() && !this._disabled
        let rootCls = this.rootClass()
        let rootAttrs = HashMap<String, String>([("class", rootCls), ("style", "position:relative"), ("data-select", "1")])

        // 面板关闭动作 id（前端点击外部时按名派发）
        let closeBid = nextBid()
        rootAttrs["data-select-close"] = closeBid

        let children = ArrayList<IComponent>()
        children.add(this.buildWrapper(isOpen))
        if (isOpen && !this._disabled) {
            children.add(this.buildDropdown())
        }

        let hmap = HashMap<String, ActionHandler>()
        hmap[closeBid] = { ctx =>
            this._open.set(false)
            this._highlight.set(-1)
            PatchResult.ReRender
        }
        VNode("div", children.toArray(), attrs: Some(rootAttrs), handlers: Some(hmap))
    }

    func rootClass(): String {
        var cls = "el-select"
        if (this._disabled) { cls = "${cls} is-disabled" }
        cls
    }

    // ============ wrapper（含 selection + suffix） ============
    func buildWrapper(isOpen: Bool): IComponent {
        var wrapperCls = "el-select__wrapper"
        if (isOpen) { wrapperCls = "${wrapperCls} is-focused" }
        if (this._filterable) { wrapperCls = "${wrapperCls} is-filterable" }
        if (this._disabled) { wrapperCls = "${wrapperCls} is-disabled" }

        let selectionChildren = ArrayList<IComponent>()
        if (this._multiple) {
            let selected = match (this._multiSignal) { case Some(s) => s.get(); case None => ArrayList<String>() }
            for (t in this.buildTagsOrPlaceholder(selected)) { selectionChildren.add(t) }
        } else {
            let currentValue = match (this._signal) { case Some(s) => s.get(); case None => "" }
            let label = this.findLabel(currentValue)
            let displayValue = if (label != "") { label } else { this._placeholder }
            let placeholderCls = if (label == "") { "el-select__selected-item el-select__placeholder is-transparent" } else { "el-select__selected-item" }
            selectionChildren.add(VNode("span", [text(displayValue)], attrs: Some(HashMap<String, String>([("class", placeholderCls)]))))
        }
        // 搜索输入（EP 恒渲染，非 filterable 时 input-wrapper 带 is-hidden 出流外；
        // 本实现 filterable 才渲染输入，非 filterable 由 wrapper 点击/键盘保持交互）
        if (this._filterable) {
            selectionChildren.add(this.buildFilterInput())
        }
        let selection = VNode("div", selectionChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-select__selection")])))

        let suffixChildren = ArrayList<IComponent>()
        suffixChildren.add(this.buildSuffixIcon(isOpen))
        let suffix = VNode("div", suffixChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-select__suffix")])))

        let wrapper = VNode("div", [selection, suffix], attrs: Some(HashMap<String, String>([("class", wrapperCls)])))
        if (this._disabled) { wrapper } else {
            let o = this._open
            let h = this._highlight
            wrapper.onClick({ ctx =>
                o.set(!o.get())
                h.set(-1)
                PatchResult.ReRender
            })
        }
    }

    // filterable 搜索输入：组合框语义 + bind 回传 _filterText + 键盘导航 action
    func buildFilterInput(): IComponent {
        var wrapperCls = "el-select__selected-item el-select__input-wrapper"
        let pa = HashMap<String, String>()
        pa["class"] = "el-select__input"
        pa["type"] = "text"
        pa["role"] = "combobox"
        pa["aria-expanded"] = if (this._open.get()) { "true" } else { "false" }
        pa["aria-autocomplete"] = "none"
        pa["aria-haspopup"] = "listbox"
        pa["spellcheck"] = "false"
        pa["autocomplete"] = "off"

        // 搜索值 bind（自定义 handler，value=raw 字符串）
        let bid = nextBid()
        pa["data-bind-id"] = bid
        let hmap = HashMap<String, ActionHandler>()
        hmap[bid] = { ctx =>
            let raw = match (ctx.params.get("value")) { case Some(x) => x case None => "" }
            this._filterText.set(raw)
            PatchResult.ReRender
        }

        // 键盘导航（KeyEvent 服务端处理）；on() 合并式注册（onClick 会重建节点丢掉已有 handlers → bid 绑定失效）
        let keyHandler: ActionHandler = { ctx =>
            if (this.handleKeyEvent(ctx)) { PatchResult.ReRender } else { PatchResult.Patch([]) }
        }
        let input = VNode("input", [], attrs: Some(pa), handlers: Some(hmap))
            .on("click", { ctx =>
                if (!this._open.get()) {
                    this._open.set(true)
                    this._highlight.set(-1)
                    PatchResult.ReRender
                } else {
                    PatchResult.Patch([])
                }
            })
            .onKeydown(keyHandler)
        let calculator = VNode("span", [], attrs: Some(HashMap<String, String>([("class", "el-select__input-calculator"), ("aria-hidden", "true")])))
        VNode("div", [input, calculator], attrs: Some(HashMap<String, String>([("class", wrapperCls)])))
    }

    // 键盘：ArrowDown/Up 移动高亮，Enter 选中高亮项（多选保持打开），Escape 关闭
    func handleKeyEvent(ctx: ActionContext): Bool {
        match (ctx.keyEvent) {
            case None => false
            case Some(ev) =>
                let count = this.visibleOptions().size
                let h = this._highlight.get()
                if (ev.isEnter()) {
                    if (!this._open.get()) {
                        this._open.set(true)
                        this._highlight.set(-1)
                        return true
                    }
                    if (selectHighlightValid(h, count)) {
                        let opt = this.visibleOptions()[h]
                        if (this._multiple) {
                            this.toggleMultiOption(opt._value)
                        } else {
                            match (this._signal) {
                                case Some(s) => s.set(opt._value)
                                case None => ()
                            }
                            this._open.set(false)
                        }
                        this._highlight.set(-1)
                        return true
                    }
                    return false
                }
                if (ev.isEscape()) {
                    this._open.set(false)
                    this._highlight.set(-1)
                    return true
                }
                if (ev.key == "ArrowDown") {
                    this._open.set(true)
                    this._highlight.set(selectMoveHighlight(h, count, 1))
                    return true
                }
                if (ev.key == "ArrowUp") {
                    this._open.set(true)
                    this._highlight.set(selectMoveHighlight(h, count, -1))
                    return true
                }
                false
        }
    }

    func toggleMultiOption(value: String): Unit {
        match (this._multiSignal) {
            case Some(ms) =>
                let list = ms.get()
                if (isSelected(list, value)) {
                    let idx = findIndex(list, value)
                    if (idx >= 0) { list.remove(idx..idx + 1) }
                } else {
                    list.add(value)
                }
                ms.set(list)
            case None => ()
        }
    }

    // suffix：clearable+有值 → 清除图标；否则 caret（打开时反转，多选不反转 —— EP iconReverse）
    func buildSuffixIcon(isOpen: Bool): IComponent {
        let hasValue = this.hasValue()
        if (this._clearable && hasValue) {
            let clearIcon = Icon("circle-close").render()
            let s = this._signal
            let ms = this._multiSignal
            let clearEl = VNode("span", [clearIcon], attrs: Some(HashMap<String, String>([("class", "el-select__caret el-select__icon el-select__clear")])))
            clearEl.onClick({ ctx =>
                match (s) { case Some(sig) => sig.set(""); case None => () }
                match (ms) { case Some(sig) => sig.set(ArrayList<String>()); case None => () }
                PatchResult.ReRender
            })
        } else {
            var caretCls = "el-select__caret el-select__icon"
            if (isOpen && !this._multiple) { caretCls = "${caretCls} is-reverse" }
            let arrowIcon = Icon("arrow-down").size("14px").render()
            VNode("span", [arrowIcon], attrs: Some(HashMap<String, String>([("class", caretCls)])))
        }
    }

    func buildTagsOrPlaceholder(selected: ArrayList<String>): Array<IComponent> {
        let items = ArrayList<IComponent>()
        for (val in selected) {
            let label = this.findLabel(val)
            let textWrap = VNode("span", [text(label)], attrs: Some(HashMap<String, String>([("class", "el-select__tags-text")])))
            let closeBtn = this.buildTagClose(val)
            let tag = VNode("span", [textWrap, closeBtn], attrs: Some(HashMap<String, String>([("class", "el-tag el-tag--info")])))
            items.add(VNode("div", [tag], attrs: Some(HashMap<String, String>([("class", "el-select__selected-item")]))))
        }
        if (selected.size == 0) {
            items.add(VNode("span", [text(this._placeholder)], attrs: Some(HashMap<String, String>([("class", "el-select__placeholder is-transparent")]))))
        }
        items.toArray()
    }

    func buildTagClose(value: String): IComponent {
        let closeBtn = VNode("button", [Icon("close").render()], attrs: Some(HashMap<String, String>([("class", "el-tag__close"), ("type", "button"), ("aria-label", "close")])))
        let v = value
        closeBtn.onClick({ ctx =>
            this.toggleMultiOption(v)
            PatchResult.ReRender
        })
    }

    func hasValue(): Bool {
        if (this._multiple) {
            match (this._multiSignal) { case Some(s) => s.get().size > 0; case None => false }
        } else {
            match (this._signal) { case Some(s) => s.get() != ""; case None => false }
        }
    }

    // ============ dropdown ============
    func buildDropdown(): IComponent {
        var popperCls = "el-select__popper el-select-dropdown el-popper"
        if (this._multiple) { popperCls = "${popperCls} is-multiple" }
        let visible = this.visibleOptions()
        let highlight = this._highlight.get()

        if (visible.size == 0) {
            let empty = VNode("div", [text("无数据")], attrs: Some(HashMap<String, String>([("class", "el-select-dropdown__empty")])))
            return VNode("div", [empty], attrs: Some(HashMap<String, String>([("class", popperCls), ("style", "position:absolute;top:100%;left:0;right:0;z-index:100")])))
        }

        let items = ArrayList<IComponent>()
        let visibleIdx = this.buildDropdownItems(items, visible, highlight)
        let list = VNode("ul", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-select-dropdown__list"), ("role", "listbox"), ("aria-orientation", "vertical")])))
        let wrap = VNode("div", [list], attrs: Some(HashMap<String, String>([("class", "el-select-dropdown__wrap")])))
        VNode("div", [wrap], attrs: Some(HashMap<String, String>([("class", popperCls), ("style", "position:absolute;top:100%;left:0;right:0;z-index:100")])))
    }

    // 按 children 顺序（含分组展开/过滤）生成选项 DOM；返回可见项数（高亮用）
    func buildDropdownItems(items: ArrayList<IComponent>, visible: ArrayList<SelectOption>, highlight: Int64): Int64 {
        var idx = 0
        let filterStr = this.filterString()
        for (c in this._children) {
            match (c) {
                case opt: SelectOption =>
                    if (this.matchesFilter(opt, filterStr)) {
                        let highlighted = idx == highlight
                        this.emitOption(items, opt, highlighted)
                        idx = idx + 1
                    }
                case g: SelectOptionGroup => idx = this.emitGroup(items, g, filterStr, highlight, idx)
                case _ => ()
            }
        }
        idx
    }

    func emitOption(items: ArrayList<IComponent>, opt: SelectOption, highlighted: Bool): Unit {
        if (this._multiple) {
            let ms = this.multiSignal()
            items.add(opt.renderItemMulti(ms.get(), ms, this._open, highlighted))
        } else {
            let s = this.singleSignal()
            items.add(opt.renderItem(s.get(), s, this._open, this._onChange, highlighted))
        }
    }

    func emitGroup(items: ArrayList<IComponent>, g: SelectOptionGroup, filterStr: String, highlight: Int64, startIdx: Int64): Int64 {
        var idx = startIdx
        let groupItems = ArrayList<IComponent>()
        for (gc in g.getChildren()) {
            match (gc) {
                case opt: SelectOption =>
                    if (this.matchesFilter(opt, filterStr)) {
                        let highlighted = idx == highlight
                        this.emitOption(groupItems, opt, highlighted)
                        idx = idx + 1
                    }
                case _ => ()
            }
        }
        if (groupItems.size > 0) {
            // EP nesting：ul.el-select-group__wrap > li.el-select-group__title + li > ul.el-select-group > li.el-select-dropdown__item
            let title = VNode("li", [text(g._label)], attrs: Some(HashMap<String, String>([("class", "el-select-group__title")])))
            let innerList = VNode("ul", groupItems.toArray(), attrs: Some(HashMap<String, String>([("class", "el-select-group")])))
            let li = VNode("li", [innerList], attrs: Some(HashMap<String, String>()))
            items.add(VNode("ul", [title, li], attrs: Some(HashMap<String, String>([("class", "el-select-group__wrap")]))))
        }
        idx
    }

    func filterString(): String {
        if (this._filterable) { this._filterText.get().toAsciiLower() } else { "" }
    }

    func singleSignal(): Signal<String> {
        match (this._signal) {
            case Some(sig) => sig
            case None => Signal<String>("")
        }
    }

    func multiSignal(): Signal<ArrayList<String>> {
        match (this._multiSignal) {
            case Some(sig) => sig
            case None => Signal<ArrayList<String>>(ArrayList<String>())
        }
    }

    // 可见选项（过滤后，含分组内选项，DOM 顺序）
    func visibleOptions(): ArrayList<SelectOption> {
        let res = ArrayList<SelectOption>()
        let filterStr = this.filterString()
        for (c in this._children) {
            match (c) {
                case opt: SelectOption => if (this.matchesFilter(opt, filterStr)) { res.add(opt) }
                case g: SelectOptionGroup =>
                    for (gc in g.getChildren()) {
                        match (gc) {
                            case o: SelectOption => if (this.matchesFilter(o, filterStr)) { res.add(o) }
                            case _ => ()
                        }
                    }
                case _ => ()
            }
        }
        res
    }

    func matchesFilter(opt: SelectOption, filterStr: String): Bool {
        filterStr == "" || this.extractLabel(opt).toAsciiLower().contains(filterStr)
    }

    func findLabel(value: String): String {
        for (c in this._children) {
            match (c) {
                case o: SelectOption => if (o._value == value) { return this.extractLabel(o) }
                case g: SelectOptionGroup => return this.labelInGroup(g, value)
                case _ => ()
            }
        }
        ""
    }

    func labelInGroup(g: SelectOptionGroup, value: String): String {
        for (gc in g.getChildren()) {
            match (gc) {
                case o: SelectOption => if (o._value == value) { return this.extractLabel(o) }
                case _ => ()
            }
        }
        ""
    }

    func extractLabel(o: SelectOption): String {
        if (o._children.size > 0) {
            match (o._children[0]) {
                case t: TextNode => t._text
                case _ => ""
            }
        } else { "" }
    }
}

func findIndex(list: ArrayList<String>, value: String): Int64 {
    var i = 0
    for (v in list) { if (v == value) { return i }; i = i + 1 }
    -1
}

func isSelected(list: ArrayList<String>, value: String): Bool {
    for (v in list) { if (v == value) { return true } }
    false
}

public class SelectOptionGroup <: Component {
    var _label: String
    var _children: Array<IComponent>

    public init(children: Array<IComponent>, label: String) {
        this._children = children
        this._label = label
    }

    public func render(): IComponent {
        let title = VNode("li", [text(this._label)], attrs: Some(HashMap<String, String>([("class", "el-select-group__title")])))
        let allItems = ArrayList<IComponent>()
        allItems.add(title)
        for (c in this._children) { allItems.add(c) }
        let wrap = VNode("ul", allItems.toArray(), attrs: Some(HashMap<String, String>([("class", "el-select-group__wrap")])))
        VNode("li", [wrap], attrs: Some(HashMap<String, String>([("class", "el-select-group")])))
    }

    func getChildren(): Array<IComponent> { this._children }
}
