package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}
import std.convert.*

// EP TimePicker（panel-time-pick.vue + basic-time-spinner.vue）：
//   el-date-editor.el-input（时钟前缀 + readonly 输入框,点击开合）
//   popper: div.el-picker__popper.el-popper
//     div.el-time-panel
//       div.el-time-panel__content.has-seconds
//         div.el-time-spinner.has-seconds
//           div.el-time-spinner__wrapper × 3（时/分/秒,max-height 192 滚动）
//             ul.el-time-spinner__list > li.el-time-spinner__item[.is-active] × N（文本 pad2）
//       div.el-time-panel__footer > button.el-time-panel__btn.cancel/.confirm
// 值 "HH:mm:ss"（Signal<String> 绑定）；点 li 即时写值；确认/取消关闭面板
public class TimePicker <: Component {
    var _valueS: Option<Signal<String>> = None
    var _placeholder: String = "HH:mm:ss"
    var _disabled: Bool = false
    var _clearable: Bool = false
    var _open: Signal<Bool>

    public init() {
        this._open = Signal<Bool>(false)
    }
    public func bind(s: Signal<String>): TimePicker { this._valueS = Some(s); this }
    public func placeholder(v: String): TimePicker { this._placeholder = v; this }
    public func disabled(): TimePicker { this._disabled = true; this }
    public func clearable(): TimePicker { this._clearable = true; this }

    func value(): String {
        match (this._valueS) {
            case Some(s) => s.get()
            case None => ""
        }
    }
    func setValue(v: String): Unit {
        match (this._valueS) {
            case Some(s) => s.set(v)
            case None => ()
        }
    }

    // "HH:mm:ss" → 三元组；非法回退 00:00:00
    func parts(): (Int64, Int64, Int64) {
        let v = this.value()
        if (v.size != 8 || v[2] != 58u8 || v[5] != 58u8) { return (0, 0, 0) }
        (parsePart(v[0..2]), parsePart(v[3..5]), parsePart(v[6..8]))
    }

    private func toggleOpen(ctx: ActionContext): PatchResult {
        this._open.set(!this._open.get())
        PatchResult.ReRender
    }

    // 点击 li：替换对应部件并写回信号
    func setPartAction(part: Int64, val: Int64): ActionHandler {
        let base = this
        let handler: ActionHandler = { ctx =>
            let (h, m, s) = base.parts()
            let nh = if (part == 0) { val } else { h }
            let nm = if (part == 1) { val } else { m }
            let ns = if (part == 2) { val } else { s }
            base.setValue("${pad2(nh)}:${pad2(nm)}:${pad2(ns)}")
            PatchResult.ReRender
        }
        handler
    }

    func closeAction(): ActionHandler {
        let base = this
        let handler: ActionHandler = { ctx =>
            base._open.set(false)
            PatchResult.ReRender
        }
        handler
    }

    func clearAction(): ActionHandler {
        let base = this
        let handler: ActionHandler = { ctx =>
            base.setValue("")
            PatchResult.ReRender
        }
        handler
    }

    public func render(): IComponent {
        let isOpen = this._open.get()
        let current = this.value()
        let children = ArrayList<IComponent>()
        children.add(this.buildInput(current, isOpen))
        if (this._clearable && current != "" && !this._disabled) {
            children.add(VNode("span", [Icon("circle-close").render()], attrs: Some(HashMap<String, String>([
                ("class", "el-input__suffix el-input__suffix-inner"),
                ("style", "position:absolute;right:8px;top:50%;transform:translateY(-50%);cursor:pointer;z-index:2"),
            ]))).onClick(this.clearAction()))
        }
        // 面板恒渲染（EP persistent 语义），未打开时 display:none —— 结构稳定且可测试
        children.add(this.buildPanel(current, isOpen))
        var cls = "el-date-editor el-input el-input--prefix"
        if (isOpen) { cls = "${cls} is-focused is-focus" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls), ("style", "position:relative;display:inline-block")])))
    }

    func buildInput(current: String, isOpen: Bool): IComponent {
        let prefixInner = VNode("span", [Icon("clock").render()], attrs: Some(HashMap<String, String>([("class", "el-input__prefix-inner")])))
        let prefix = VNode("span", [prefixInner], attrs: Some(HashMap<String, String>([("class", "el-input__prefix")])))
        let inputAttrs = HashMap<String, String>([("class", "el-input__inner"), ("readonly", "true"), ("placeholder", this._placeholder)])
        if (current != "") { inputAttrs["value"] = current }
        let inputEl = VNode("input", [], attrs: Some(inputAttrs))
        var wrapper = VNode("div", [prefix, inputEl], attrs: Some(HashMap<String, String>([("class", "el-input__wrapper")])))
        if (!this._disabled) {
            wrapper = wrapper.onClick({ ctx => this.toggleOpen(ctx) })
        }
        wrapper
    }

    func buildPanel(current: String, isOpen: Bool): IComponent {
        let (hval, mval, sval) = this.parts()
        let spinnerChildren = ArrayList<IComponent>()
        spinnerChildren.add(buildSpinnerColumn(0, hval, 0, 24))
        spinnerChildren.add(buildSpinnerColumn(1, mval, 0, 60))
        spinnerChildren.add(buildSpinnerColumn(2, sval, 0, 60))
        let spinner = VNode("div", spinnerChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-time-spinner has-seconds")])))
        let content = VNode("div", [spinner], attrs: Some(HashMap<String, String>([("class", "el-time-panel__content has-seconds")])))

        let cancelAttrs = HashMap<String, String>([("class", "el-time-panel__btn cancel"), ("type", "button")])
        var cancelBtn = VNode("button", [text("取消")], attrs: Some(cancelAttrs))
        cancelBtn = cancelBtn.onClick(this.closeAction())
        let confirmAttrs = HashMap<String, String>([("class", "el-time-panel__btn confirm"), ("type", "button")])
        var confirmBtn = VNode("button", [text("确定")], attrs: Some(confirmAttrs))
        confirmBtn = confirmBtn.onClick(this.closeAction())
        let footer = VNode("div", [cancelBtn, confirmBtn], attrs: Some(HashMap<String, String>([("class", "el-time-panel__footer")])))

        let panel = VNode("div", [content, footer], attrs: Some(HashMap<String, String>([("class", "el-time-panel")])))
        let visible = if (isOpen) { "position:absolute;top:100%;left:0;z-index:1000;margin-top:4px" } else { "position:absolute;top:100%;left:0;z-index:1000;margin-top:4px;display:none" }
        VNode("div", [panel], attrs: Some(HashMap<String, String>([
            ("class", "el-picker__popper el-popper"),
            ("style", visible),
        ])))
    }

    func buildSpinnerColumn(part: Int64, active: Int64, from: Int64, to: Int64): IComponent {
        let items = ArrayList<IComponent>()
        for (i in from..to) {
            var cls = "el-time-spinner__item"
            if (i == active) { cls = "${cls} is-active" }
            let attrs = HashMap<String, String>([("class", cls)])
            var li = VNode("li", [text(pad2(i))], attrs: Some(attrs))
            li = li.onClick(this.setPartAction(part, i))
            items.add(li)
        }
        let list = VNode("ul", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-time-spinner__list")])))
        // data-scroll-active：patch 后自动滚到 .is-active（打开/点选时选中项居中）
        VNode("div", [list], attrs: Some(HashMap<String, String>([
            ("class", "el-time-spinner__wrapper"),
            ("data-scroll-active", "true"),
        ])))
    }
}

func parsePart(s: String): Int64 {
    try {
        Int64.parse(s)
    } catch (e: Exception) {
        0
    }
}
