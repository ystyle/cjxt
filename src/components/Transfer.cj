package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// ============ Transfer 穿梭框（对齐 Element Plus transfer） ============
//
// EP 结构（transfer.vue / transfer-panel.vue）：
//   div.el-transfer
//     ├─ div.el-transfer-panel                            ← 左（源）
//     │    ├─ p.el-transfer-panel__header
//     │    │    └─ label.el-checkbox[.is-indeterminate] > span.el-checkbox__input > span.el-checkbox__inner
//     │    │         + span.el-checkbox__label > span.el-transfer-panel__header-title + __header-count
//     │    └─ div.el-transfer-panel__body[.is-with-footer]
//     │         └─ div.el-transfer-panel__list[.is-filterable]
//     │              └─ label.el-checkbox.el-transfer-panel__item[.is-checked][.is-disabled]
//     ├─ div.el-transfer__buttons
//     │    └─ button.el-button.el-button--primary.el-transfer__button × 2（左箭头 / 右箭头）
//     └─ div.el-transfer-panel                            ← 右（已选）
//
// 绑定语义：`bind(Signal<ArrayList<String>>)` 绑定的是**右侧（已选）的 key 列表**，
// 与 EP 的 `v-model` 一致（EP 的 modelValue 是可穿梭到右边的项）。
// 左面板显示 options 中**不在**该列表里的项，右面板显示其中的项。
//
// 交互（与 EP 的差异）：EP 是「两侧各自勾选 → 点箭头才移动」两步操作（需要面板内的
// checked 中间态，且「全选」需要 indeterminate 三态）。服务端模型下把这两步压成一步：
// **直接点某一项的复选框即移动**（左侧勾上 = 移到右边，右侧取消 = 移回左边），
// 箭头按钮做成「整面板全移」。这样绑定信号只有一个真实来源（就是 v-model 本身），
// 不会出现「勾选态与已选态两份状态互相打架」。这是刻意的简化，已在文件头说明。
//
// **未实现**：`filterable`（面板内搜索框）与 `virtualScroll`。前者需要输入框实时过滤，
// 后者需要虚拟列表；两者都依赖前端交互态，而本组件的列表由绑定信号单一驱动。

// 数据项：EP 的 TransferDataItem（{ key, label, disabled }）
public struct TransferOption {
    public let key: String
    public let label: String
    public let disabled: Bool

    public init(key: String, label: String, disabled!: Bool = false) {
        this.key = key
        this.label = label
        this.disabled = disabled
    }
}

public class Transfer <: Component {
    var _options: ArrayList<TransferOption> = ArrayList<TransferOption>()
    var _valueSignal: Option<Signal<ArrayList<String>>> = None
    var _fallbackValue: Signal<ArrayList<String>> = Signal<ArrayList<String>>(ArrayList<String>())
    var _titles: (String, String) = ("列表 1", "列表 2")
    var _buttonTexts: (String, String) = ("", "")
    var _disabled: Bool = false
    var _onChange: Option<ActionHandler> = None

    public init(options: ArrayList<TransferOption>) { this._options = options }

    public func bind(signal: Signal<ArrayList<String>>): Transfer { this._valueSignal = Some(signal); this }
    // 左右面板标题（EP 的 titles: [left, right]）
    public func titles(left: String, right: String): Transfer { this._titles = (left, right); this }
    // 按钮文案（EP 的 buttonTexts）；留空则只显示箭头图标
    public func buttonTexts(left: String, right: String): Transfer { this._buttonTexts = (left, right); this }
    public func disabled(): Transfer { this._disabled = true; this }
    public func onChange(h: ActionHandler): Transfer { this._onChange = Some(h); this }

    public func render(): IComponent {
        let selected = this.selectedKeys()
        let leftItems = this.partitionItems(selected, false)
        let rightItems = this.partitionItems(selected, true)

        let leftPanel = this.buildPanel(leftItems, selected, this._titles[0], false)
        let buttons = this.buildButtons(leftItems, rightItems, selected)
        let rightPanel = this.buildPanel(rightItems, selected, this._titles[1], true)

        VNode("div", [leftPanel, buttons, rightPanel], attrs: Some(HashMap<String, String>([("class", "el-transfer")])))
    }

    func valueSignal(): Signal<ArrayList<String>> {
        match (this._valueSignal) {
            case Some(s) => s
            case None => this._fallbackValue
        }
    }

    func selectedKeys(): ArrayList<String> {
        this.valueSignal().get()
    }

    // 按「是否已在右侧」把 options 分成两组，保持 options 原顺序（EP 的 targetOrder='original'）
    func partitionItems(selected: ArrayList<String>, wantSelected: Bool): ArrayList<TransferOption> {
        let out = ArrayList<TransferOption>()
        for (o in this._options) {
            let inRight = containsString(selected, o.key)
            if (inRight == wantSelected) { out.add(o) }
        }
        out
    }

    // ── 面板 ──
    func buildPanel(items: ArrayList<TransferOption>, selected: ArrayList<String>, title: String, isRight: Bool): IComponent {
        // 头部：全选复选 + 标题 + 计数（EP 的 header 是一个 el-checkbox）
        let allChecked = items.size > 0 && this.allItemsInRight(items, selected) == isRight
        let anyChecked = if (isRight) { items.size > 0 } else { this.anyInRight(items, selected) }
        let indeterminate = if (isRight) { false } else { anyChecked && !allChecked }

        var headerBoxCls = "el-checkbox"
        if (allChecked) { headerBoxCls = "${headerBoxCls} is-checked" }
        if (indeterminate && !allChecked) { headerBoxCls = "${headerBoxCls} is-indeterminate" }

        let titleSpan = VNode("span", [text(title)], attrs: Some(HashMap<String, String>([("class", "el-transfer-panel__header-title")])))
        let countSpan = VNode("span", [text("${items.size} / ${this._options.size}")], attrs: Some(HashMap<String, String>([("class", "el-transfer-panel__header-count")])))
        let labelSpan = VNode("span", [titleSpan, countSpan], attrs: Some(HashMap<String, String>([("class", "el-checkbox__label")])))
        let headerLabel = this.buildCheckboxBody(headerBoxCls, allChecked, labelSpan)
        var headerLabelEl: VNode = headerLabel
        if (items.size > 0) {
            headerLabelEl = headerLabel.onClick({ ctx => this.moveAll(items, isRight, ctx) })
        }
        let header = VNode("p", [headerLabelEl], attrs: Some(HashMap<String, String>([("class", "el-transfer-panel__header")])))

        // 主体：列表（每项一个 el-checkbox，勾选即移动）
        let listItems = ArrayList<IComponent>()
        for (o in items) {
            listItems.add(this.buildItem(o, selected, isRight))
        }
        var listCls = "el-transfer-panel__list"
        let list = VNode("div", listItems.toArray(), attrs: Some(HashMap<String, String>([
            ("class", listCls),
            ("role", "group"),
        ])))
        let body = VNode("div", [list], attrs: Some(HashMap<String, String>([("class", "el-transfer-panel__body")])))

        VNode("div", [header, body], attrs: Some(HashMap<String, String>([("class", "el-transfer-panel")])))
    }

    // 复选框的「外壳」：label + 隐藏 input + inner 方块 + label 文案（与 Checkbox.cj 的 DOM 一致）
    func buildCheckboxBody(boxCls: String, checked: Bool, labelContent: IComponent): VNode {
        let inputAttrs = HashMap<String, String>([("class", "el-checkbox__original"), ("type", "checkbox")])
        if (checked) { inputAttrs["checked"] = "checked" }
        let inputEl = VNode("input", [], attrs: Some(inputAttrs))
        let innerSpan = VNode("span", [], attrs: Some(HashMap<String, String>([("class", "el-checkbox__inner")])))
        var inputCls = "el-checkbox__input"
        if (checked) { inputCls = "${inputCls} is-checked" }
        let inputSpan = VNode("span", [inputEl, innerSpan], attrs: Some(HashMap<String, String>([("class", inputCls)])))
        VNode("label", [inputSpan, labelContent], attrs: Some(HashMap<String, String>([("class", boxCls)])))
    }

    func buildItem(o: TransferOption, selected: ArrayList<String>, isRight: Bool): IComponent {
        let inRight = containsString(selected, o.key)
        let isChecked = if (isRight) { inRight } else { false }
        let isDisabled = this._disabled || o.disabled
        var cls = "el-checkbox el-transfer-panel__item"
        if (isChecked) { cls = "${cls} is-checked" }
        if (isDisabled) { cls = "${cls} is-disabled" }

        let labelSpan = VNode("span", [text(o.label)], attrs: Some(HashMap<String, String>([("class", "el-checkbox__label")])))
        let box = this.buildCheckboxBody(cls, isChecked, labelSpan)
        // 勾选/取消即移动（详见文件头「交互」说明）
        if (!isDisabled) {
            let key = o.key
            box.onClick({ ctx => this.toggle(key, ctx) })
        } else {
            box
        }
    }

    // ── 中间按钮 ──
    func buildButtons(leftItems: ArrayList<TransferOption>, rightItems: ArrayList<TransferOption>, selected: ArrayList<String>): IComponent {
        let hasLeft = leftItems.size > 0
        let hasRight = rightItems.size > 0
        let leftBtn = this.buildButton("left", hasLeft)
        let rightBtn = this.buildButton("right", hasRight)
        VNode("div", [leftBtn, rightBtn], attrs: Some(HashMap<String, String>([("class", "el-transfer__buttons")])))
    }

    func buildButton(side: String, enabled: Bool): IComponent {
        let isLeft = side == "left"
        var cls = "el-button el-button--primary el-transfer__button"
        if (!enabled || this._disabled) { cls = "${cls} is-disabled" }
        let iconName = if (isLeft) { "arrow-left" } else { "arrow-right" }
        let parts = ArrayList<IComponent>()
        let textLabel = if (isLeft) { this._buttonTexts[0] } else { this._buttonTexts[1] }
        if (!isLeft && textLabel != "") { parts.add(text(textLabel)) }
        parts.add(Icon(iconName))
        if (isLeft && textLabel != "") { parts.add(text(textLabel)) }
        // EP 语义：**有按钮文案**时才加 is-with-texts（该修饰类给按钮加宽、留出文字空间）。
        // 原实现写反了（无文案时加），导致纯图标按钮被撑成带文字的宽度。
        if (textLabel != "") { cls = "${cls} is-with-texts" }

        let attrs = HashMap<String, String>([("class", cls), ("type", "button")])
        if (!enabled || this._disabled) { attrs["disabled"] = "disabled" }
        let btn = VNode("button", parts.toArray(), attrs: Some(attrs))
        if (enabled && !this._disabled) {
            // 方向修正（2026-10-23）：moveMany 的参数是 **toRight**，而这里原来直接传了 isLeft ——
            // 语义正好相反（左按钮 isLeft=true 被当成"移向右侧"），导致两个按钮方向全反。
            // 左按钮（arrow-left）应把右侧的项移回左侧 → toRight = !isLeft。
            let toRight = !isLeft
            btn.onClick({ ctx => this.moveMany(toRight, ctx) })
        } else {
            btn
        }
    }

    // ── 状态变更 ──
    //
    // 统一做法：维护一个「选中集合的判决表」，然后**按 options 原始顺序重建列表**。
    // 这就是 EP 的 targetOrder='original' 语义（右侧列表顺序不随点击次序漂移），
    // 也避开了 ArrayList 没有 insert 方法的问题。

    // 单项切换：左侧勾上→移到右侧；右侧取消→移回左侧
    func toggle(key: String, ctx: ActionContext): PatchResult {
        let s = this.valueSignal()
        let next = this.rebuildSelection(s.get(), key, !containsString(s.get(), key))
        s.set(next)
        this.invokeChange(ctx)
        PatchResult.ReRender
    }

    // 整面板移动（头部全选 / 箭头按钮）
    func moveAll(items: ArrayList<TransferOption>, fromRight: Bool, ctx: ActionContext): PatchResult {
        let s = this.valueSignal()
        var next = s.get()
        for (o in items) {
            if (o.disabled) { continue }
            next = this.rebuildSelection(next, o.key, !fromRight)
        }
        s.set(next)
        this.invokeChange(ctx)
        PatchResult.ReRender
    }

    // 箭头按钮：把**对应那一侧**的全部项移走。
    //
    // 修复前遍历 `this._options`（**所有**选项），于是点右箭头会把右侧的项也"移入右侧"
    // ——在单步模型下表现为"点一下，所有选项都跑到右边"，方向完全失控。
    // 正确语义（对齐 EP 的 "全移" 但限定在源面板）：
    //   右箭头 → 只把「左侧面板上的项」移入右侧
    //   左箭头 → 只把「右侧面板上的项」移回左侧
    func moveMany(toRight: Bool, ctx: ActionContext): PatchResult {
        let s = this.valueSignal()
        let selected = s.get()
        // partitionItems(selected, wantSelected)：true = 右侧(已选中)，false = 左侧(未选中)。
        // toRight=true（右箭头）→ 源是左面板 → wantSelected = false = !toRight。
        let source = this.partitionItems(selected, !toRight)
        var next = selected
        for (o in source) {
            if (o.disabled) { continue }
            next = this.rebuildSelection(next, o.key, toRight)
        }
        s.set(next)
        this.invokeChange(ctx)
        PatchResult.ReRender
    }

    // 返回「把 key 置为 selected 之后」的选中列表，且严格按 options 原始顺序
    func rebuildSelection(cur: ArrayList<String>, key: String, selected: Bool): ArrayList<String> {
        let wanted = HashMap<String, Bool>()
        for (k in cur) { wanted[k] = true }
        if (selected) { wanted[key] = true } else { wanted.remove(key) }
        let out = ArrayList<String>()
        for (o in this._options) {
            if (wantedContains(wanted, o.key)) { out.add(o.key) }
        }
        out
    }

    func allItemsInRight(items: ArrayList<TransferOption>, selected: ArrayList<String>): Bool {
        for (o in items) { if (!containsString(selected, o.key)) { return false } }
        items.size > 0
    }

    func anyInRight(items: ArrayList<TransferOption>, selected: ArrayList<String>): Bool {
        for (o in items) { if (containsString(selected, o.key)) { return true } }
        false
    }

    func invokeChange(ctx: ActionContext): Unit {
        match (this._onChange) {
            case Some(fn) => runCb(fn, ctx)
            case None => ()
        }
    }
}

func wantedContains(m: HashMap<String, Bool>, key: String): Bool {
    match (m.get(key)) {
        case Some(v) => v
        case None => false
    }
}

func containsString(list: ArrayList<String>, key: String): Bool {
    for (v in list) { if (v == key) { return true } }
    false
}
