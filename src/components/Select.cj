package cjxt.components

import cjxt.*
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

    func renderItem(currentValue: String, signal: Signal<String>, openSignal: Signal<Bool>): IComponent {
        let selected = this._value == currentValue
        var cls = "el-select-dropdown__item"
        if (selected) { cls = "${cls} is-selected" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let attrs = HashMap<String, String>([("class", cls)])
        let v = this._value
        let s = signal
        let o = openSignal
        let item = VNode("li", this._children, attrs: Some(attrs))
        if (this._disabled) { item } else {
            item.onClick({ ctx => s.set(v); o.set(false); PatchResult.ReRender })
        }
    }

    func renderItemMulti(selectedValues: ArrayList<String>, multiSignal: Signal<ArrayList<String>>, openSignal: Signal<Bool>): IComponent {
        let selected = isSelected(selectedValues, this._value)
        var cls = "el-select-dropdown__item"
        if (selected) { cls = "${cls} is-selected" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let attrs = HashMap<String, String>([("class", cls)])
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

    public init(children: Array<IComponent>) {
        this._children = children
        this._open = Signal<Bool>(false)
        this._filterText = Signal<String>("")
    }
    public func bind(signal: Signal<String>): Select { this._signal = Some(signal); this }
    public func bindMulti(signal: Signal<ArrayList<String>>): Select { this._multiSignal = Some(signal); this }
    public func placeholder(v: String): Select { this._placeholder = v; this }
    public func disabled(): Select { this._disabled = true; this }
    public func multiple(): Select { this._multiple = true; this }
    public func clearable(): Select { this._clearable = true; this }
    public func filterable(): Select { this._filterable = true; this }

    public func render(): IComponent {
        var cls = "el-select"
        if (this._disabled) { cls = "${cls} el-select--disabled" }
        let isOpen = this._open.get()

        // selection content
        let selectionChildren = ArrayList<IComponent>()
        if (this._multiple) {
            let selected = match (this._multiSignal) { case Some(s) => s.get(); case None => ArrayList<String>() }
            let tags = this.buildTags(selected)
            if (tags.size > 0) {
                for (t in tags) { selectionChildren.add(t) }
            } else {
                selectionChildren.add(span([text(this._placeholder)], attrs: Some(HashMap<String, String>([("class", "el-select__placeholder is-transparent")]))))
            }
        } else {
            let currentValue = match (this._signal) { case Some(s) => s.get(); case None => "" }
            let label = this.findLabel(currentValue)
            let displayValue = if (label != "") { label } else { this._placeholder }
            let placeholderCls = if (label == "") { "el-select__placeholder is-transparent" } else { "el-select__selected-item" }
            selectionChildren.add(span([text(displayValue)], attrs: Some(HashMap<String, String>([("class", placeholderCls)]))))
        }
        let selectionAttrs = HashMap<String, String>([("class", "el-select__selection")])
        let selection = VNode("div", selectionChildren.toArray(), attrs: Some(selectionAttrs))

        // suffix area
        let suffixChildren = ArrayList<IComponent>()
        let hasValue = this.hasValue()
        if (this._clearable && hasValue) {
            let clearIcon = Icon("circle-close").render()
            let s = this._signal
            let ms = this._multiSignal
            let clearEl = VNode("div", [clearIcon], attrs: Some(HashMap<String, String>([("class", "el-select__clear")])))
            suffixChildren.add(clearEl.onClick({ ctx =>
                match (s) { case Some(sig) => sig.set(""); case None => () }
                match (ms) { case Some(sig) => sig.set(ArrayList<String>()); case None => () }
                PatchResult.ReRender
            }))
        }
        let arrowIcon = Icon("arrow-down").size("14px").render()
        suffixChildren.add(VNode("div", [arrowIcon], attrs: Some(HashMap<String, String>([("class", "el-select__caret")]))))
        let suffix = VNode("div", suffixChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-select__suffix")])))

        let wrapperCls = if (isOpen) { "el-select__wrapper is-focused" } else { "el-select__wrapper" }
        let wrapperAttrs = HashMap<String, String>([("class", wrapperCls)])
        var wrapper = VNode("div", [selection, suffix], attrs: Some(wrapperAttrs))

        let multiValue = match (this._multiSignal) { case Some(s) => s.get(); case None => ArrayList<String>() }
        let dropdown: Option<IComponent> = if (isOpen) { Some(this.buildDropdown(if (this._multiple) { if (multiValue.size > 0) { multiValue[0] } else { "" } } else { match (this._signal) { case Some(s) => s.get(); case None => "" } })) } else { None }

        let children = ArrayList<IComponent>()
        children.add(wrapper)
        match (dropdown) {
            case Some(d) => children.add(d)
            case None => ()
        }

        if (this._disabled) {
            VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls), ("style", "position:relative")])))
        } else {
            let o = this._open
            wrapper = wrapper.onClick({ ctx => o.set(!o.get()); PatchResult.ReRender })
            children.clear()
            children.add(wrapper)
            match (dropdown) {
                case Some(d) => children.add(d)
                case None => ()
            }
            VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls), ("style", "position:relative")])))
        }
    }

    func buildTags(selected: ArrayList<String>): Array<IComponent> {
        let items = ArrayList<IComponent>()
        if (!this._multiple) { return items.toArray() }
        for (val in selected) {
            let label = this.findLabel(val)
            let content = VNode("span", [text(label)], attrs: Some(HashMap<String, String>([("class", "el-tag__content")])))
            let closeBtn = VNode("button", [text("×")], attrs: Some(HashMap<String, String>([("class", "el-tag__close"), ("type", "button")])))
            let v = val
            let ms = this._multiSignal
            let closeEl = closeBtn.onClick({ ctx =>
                match (ms) {
                    case Some(sig) =>
                        let list = sig.get()
                        let idx = findIndex(list, v)
                        if (idx >= 0) { list.remove(idx..idx + 1) }
                        sig.set(list)
                    case None => ()
                }
                PatchResult.ReRender
            })
            let tag = VNode("span", [content, closeEl], attrs: Some(HashMap<String, String>([("class", "el-tag el-tag--info")])))
            items.add(tag)
        }
        items.toArray()
    }

    func hasValue(): Bool {
        if (this._multiple) {
            match (this._multiSignal) { case Some(s) => s.get().size > 0; case None => false }
        } else {
            match (this._signal) { case Some(s) => s.get() != ""; case None => false }
        }
    }

    func buildDropdown(currentValue: String): IComponent {
        let items = ArrayList<IComponent>()

        // filter input
        if (this._filterable) {
            let filterInput = Input().placeholder("搜索").bind(this._filterText)
            items.add(VNode("div", [filterInput.render()], attrs: Some(HashMap<String, String>([("class", "el-select-dropdown__header")]))))
        }

        let filterStr = if (this._filterable) { this._filterText.get().toAsciiLower() } else { "" }
        let o = this._open

        if (this._multiple) {
            let ms = match (this._multiSignal) { case Some(sig) => sig; case None => Signal<ArrayList<String>>(ArrayList<String>()) }
            let currentSelected = ms.get()
            this.buildDropdownItems(items, filterStr, o, currentSelected, ms)
        } else {
            let s = match (this._signal) { case Some(sig) => sig; case None => Signal<String>("") }
            this.buildDropdownItemsSingle(items, filterStr, o, currentValue, s)
        }

        let list = VNode("ul", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-select-dropdown__list")])))
        let wrap = VNode("div", [list], attrs: Some(HashMap<String, String>([("class", "el-select-dropdown__wrap")])))
        VNode("div", [wrap], attrs: Some(HashMap<String, String>([("class", "el-select__popper el-select-dropdown el-popper"), ("style", "position:absolute;top:100%;left:0;right:0;z-index:100")])))
    }

    func buildDropdownItems(items: ArrayList<IComponent>, filterStr: String, o: Signal<Bool>, currentSelected: ArrayList<String>, ms: Signal<ArrayList<String>>): Unit {
        for (c in this._children) {
            match (c) {
                case opt: SelectOption => this.addOptionIfFilter(items, opt, filterStr, ms, o, currentSelected)
                case g: SelectOptionGroup => this.addOptionGroup(items, g, filterStr, ms, o, currentSelected)
                case _ => items.add(c)
            }
        }
    }

    func addOptionIfFilter(items: ArrayList<IComponent>, opt: SelectOption, filterStr: String, ms: Signal<ArrayList<String>>, o: Signal<Bool>, selected: ArrayList<String>): Unit {
        if (filterStr == "" || this.extractLabel(opt).toAsciiLower().contains(filterStr)) {
            items.add(opt.renderItemMulti(selected, ms, o))
        }
    }

    func addMultiOptionGroup(items: ArrayList<IComponent>, g: SelectOptionGroup, filterStr: String, ms: Signal<ArrayList<String>>, o: Signal<Bool>, selected: ArrayList<String>): Unit {
        let groupItems = ArrayList<IComponent>()
        for (gc in g.getChildren()) {
            match (gc) {
                case opt: SelectOption => this.filterAddMultiOpt(groupItems, opt, filterStr, selected, ms, o)
                case _ => ()
            }
        }
        if (groupItems.size > 0) {
            let title = VNode("li", [text(g._label)], attrs: Some(HashMap<String, String>([("class", "el-select-group__title")])))
            let allItems = ArrayList<IComponent>()
            allItems.add(title)
            for (it in groupItems) { allItems.add(it) }
            let wrap = VNode("ul", allItems.toArray(), attrs: Some(HashMap<String, String>([("class", "el-select-group__wrap")])))
            items.add(VNode("li", [wrap], attrs: Some(HashMap<String, String>([("class", "el-select-group")]))))
        }
    }

    func addOptionGroup(items: ArrayList<IComponent>, g: SelectOptionGroup, filterStr: String, signal: Signal<ArrayList<String>>, o: Signal<Bool>, selected: ArrayList<String>): Unit {
        let groupItems = ArrayList<IComponent>()
        for (gc in g.getChildren()) {
            match (gc) {
                case opt: SelectOption => this.filterAddMultiOpt(groupItems, opt, filterStr, selected, signal, o)
                case _ => ()
            }
        }
        if (groupItems.size > 0) {
            let title = VNode("li", [text(g._label)], attrs: Some(HashMap<String, String>([("class", "el-select-group__title")])))
            let allItems = ArrayList<IComponent>()
            allItems.add(title)
            for (it in groupItems) { allItems.add(it) }
            let wrap = VNode("ul", allItems.toArray(), attrs: Some(HashMap<String, String>([("class", "el-select-group__wrap")])))
            items.add(VNode("li", [wrap], attrs: Some(HashMap<String, String>([("class", "el-select-group")]))))
        }
    }

    func filterAddMultiOpt(groupItems: ArrayList<IComponent>, opt: SelectOption, filterStr: String, selected: ArrayList<String>, ms: Signal<ArrayList<String>>, o: Signal<Bool>): Unit {
        if (filterStr == "" || this.extractLabel(opt).toAsciiLower().contains(filterStr)) {
            groupItems.add(opt.renderItemMulti(selected, ms, o))
        }
    }

    func buildDropdownItemsSingle(items: ArrayList<IComponent>, filterStr: String, o: Signal<Bool>, currentValue: String, s: Signal<String>): Unit {
        for (c in this._children) {
            match (c) {
                case opt: SelectOption => this.addOptionIfFilterSingle(items, opt, filterStr, currentValue, s, o)
                case g: SelectOptionGroup => this.addSingleOptionGroup(items, g, filterStr, currentValue, s, o)
                case _ => items.add(c)
            }
        }
    }

    func addOptionIfFilterSingle(items: ArrayList<IComponent>, opt: SelectOption, filterStr: String, currentValue: String, s: Signal<String>, o: Signal<Bool>): Unit {
        if (filterStr == "" || this.extractLabel(opt).toAsciiLower().contains(filterStr)) {
            items.add(opt.renderItem(currentValue, s, o))
        }
    }

    func addSingleOptionGroup(items: ArrayList<IComponent>, g: SelectOptionGroup, filterStr: String, currentValue: String, s: Signal<String>, o: Signal<Bool>): Unit {
        let groupItems = ArrayList<IComponent>()
        for (gc in g.getChildren()) {
            match (gc) {
                case opt: SelectOption => this.filterAddSingleOpt(groupItems, opt, filterStr, currentValue, s, o)
                case _ => ()
            }
        }
        if (groupItems.size > 0) {
            let title = VNode("li", [text(g._label)], attrs: Some(HashMap<String, String>([("class", "el-select-group__title")])))
            let allItems = ArrayList<IComponent>()
            allItems.add(title)
            for (it in groupItems) { allItems.add(it) }
            let wrap = VNode("ul", allItems.toArray(), attrs: Some(HashMap<String, String>([("class", "el-select-group__wrap")])))
            items.add(VNode("li", [wrap], attrs: Some(HashMap<String, String>([("class", "el-select-group")]))))
        }
    }

    func filterAddSingleOpt(groupItems: ArrayList<IComponent>, opt: SelectOption, filterStr: String, currentValue: String, s: Signal<String>, o: Signal<Bool>): Unit {
        if (filterStr == "" || this.extractLabel(opt).toAsciiLower().contains(filterStr)) {
            groupItems.add(opt.renderItem(currentValue, s, o))
        }
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
