package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ============ Steps 步骤条（对齐 Element Plus） ============

// 步骤状态（EP 的 currentStatus：success/process/wait/error）
public class StepItem <: Component {
    var _title: String = ""
    var _description: String = ""
    var _status: String = ""  // 可选强制状态（finish/process/wait/error）

    public func title(v: String): StepItem { this._title = v; this }
    public func description(v: String): StepItem { this._description = v; this }
    public func status(v: String): StepItem { this._status = v; this }

    public func render(): IComponent {
        div([]) // 数据载体
    }
}

public class Steps <: Component {
    var _children: Array<IComponent>
    var _active: Signal<Int64>           // 当前步骤（1 起，EP 语义）
    var _direction: String = "horizontal"
    var _processStatus: String = "process"
    var _finishStatus: String = "finish"
    var _space: String = ""              // 步骤均分宽度（如 "33%" / "100px"；空 = EP 默认内容自适应）

    public init(children: Array<IComponent>, active: Signal<Int64>) {
        this._children = children
        this._active = active
    }

    public func direction(v: String): Steps { this._direction = v; this }
    public func processStatus(v: String): Steps { this._processStatus = v; this }
    public func finishStatus(v: String): Steps { this._finishStatus = v; this }
    public func space(v: String): Steps { this._space = v; this }

    public func render(): IComponent {
        let items = this.collectItems()
        let active = this._active.get()
        let total = items.size
        let children = ArrayList<IComponent>()
        var i = 0
        for (item in items) {
            let status = this.stepStatus(item, i, active)
            children.add(this.buildStep(item, i, status, total, i == total - 1))
            i += 1
        }
        let cls = "el-steps el-steps--${this._direction}"
        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
    }

    func collectItems(): ArrayList<StepItem> {
        let result = ArrayList<StepItem>()
        for (c in this._children) {
            match (c) {
                case item: StepItem => result.add(item)
                case _ => ()
            }
        }
        result
    }

    // 推导状态（纯逻辑在 cjxt 包，可单测）
    func stepStatus(item: StepItem, idx: Int64, active: Int64): String {
        stepsStatus(item._status, idx, active, this._processStatus, this._finishStatus)
    }

    func buildStep(item: StepItem, idx: Int64, status: String, total: Int64, isLast: Bool): IComponent {
        let isVertical = this._direction == "vertical"
        let rootAttrs = HashMap<String, String>()
        var stepCls = "el-step is-${status}"
        if (isVertical) { stepCls = "${stepCls} is-vertical" }
        // 末步：EP 用 is-flex 让 flex-basis 回退为内容自适应（不伸展）——仅无 space 时
        if (isLast && this._space == "") { stepCls = "${stepCls} is-flex" }
        rootAttrs["class"] = stepCls
        let style = stepFlexStyle(total, isLast, isVertical, this._space)
        if (style != "") { rootAttrs["style"] = style }
        // head
        let headAttrs = HashMap<String, String>()
        headAttrs["class"] = "el-step__head is-${status}"
        let lineInner = VNode("i", [], attrs: Some(HashMap<String, String>([("class", "el-step__line-inner"), ("style", "")])))
        let line = VNode("div", [lineInner], attrs: Some(HashMap<String, String>([("class", "el-step__line")])))
        let iconInner = VNode("div", [text((idx + 1).toString())], attrs: Some(HashMap<String, String>([("class", "el-step__icon-inner")])))
        let icon = VNode("div", [iconInner], attrs: Some(HashMap<String, String>([("class", "el-step__icon is-text")])))
        let head = VNode("div", [line, icon], attrs: Some(headAttrs))
        // main
        let titleAttrs = HashMap<String, String>()
        titleAttrs["class"] = "el-step__title is-${status}"
        let title = VNode("div", [text(item._title)], attrs: Some(titleAttrs))
        let mainChildren = ArrayList<IComponent>()
        mainChildren.add(title)
        if (item._description != "") {
            let descAttrs = HashMap<String, String>()
            descAttrs["class"] = "el-step__description is-${status}"
            mainChildren.add(VNode("div", [text(item._description)], attrs: Some(descAttrs)))
        }
        let mainEl = VNode("div", mainChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-step__main")])))
        VNode("div", [head, mainEl], attrs: Some(rootAttrs))
    }
}
