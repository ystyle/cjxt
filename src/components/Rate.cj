package cjxt.components

import cjxt.*
import cjxt.rateIsHalfItem
import cjxt.rateValueFromClick
import cjxt.rateLabelIndex
import cjxt.rateValueText
import std.collection.{HashMap, ArrayList}

public class Rate <: Component {
    var _signal: Option<Signal<Float64>> = None
    var _max: Int64 = 5
    var _allowHalf: Bool = false
    var _showText: Bool = false
    var _disabled: Bool = false
    var _texts: Array<String> = []

    public init() {}
    public func bind(signal: Signal<Float64>): Rate { this._signal = Some(signal); this }
    public func max(v: Int64): Rate { this._max = v; this }
    public func allowHalf(): Rate { this._allowHalf = true; this }
    public func showText(): Rate { this._showText = true; this }
    public func disabled(): Rate { this._disabled = true; this }
    public func texts(v: Array<String>): Rate { this._texts = v; this }

    public func render(): IComponent {
        let value = match (this._signal) { case Some(s) => s.get(); case None => 0.0 }
        var outerCls = "el-rate"
        if (this._disabled) { outerCls = "${outerCls} is-disabled" }
        let outerAttrs = HashMap<String, String>([
            ("class", outerCls),
            ("role", "slider"),
            ("aria-valuenow", rateValueText(value)),
            ("aria-valuemin", "0"),
            ("aria-valuemax", this._max.toString()),
            ("data-rate", "1"),
        ])
        let items = ArrayList<IComponent>()
        var idx: Int64 = 1
        while (idx <= this._max) {
            let halfCell = rateIsHalfItem(value, idx, this._allowHalf)
            let isActive = Float64(idx) <= value && !halfCell
            items.add(this.buildItem(idx, isActive, halfCell))
            idx = idx + 1
        }
        if (this._showText && this._texts.size > 0) {
            let labelIdx = rateLabelIndex(value, this._texts.size)
            items.add(VNode("span", [text(this._texts[Int64(labelIdx)])], attrs: Some(HashMap<String, String>([("class", "el-rate__text")]))))
        }
        VNode("div", items.toArray(), attrs: Some(outerAttrs))
    }

    // 每颗星：EP rate.vue 结构（active/void 图标；半星 = decimal-box 空星 + decimal 覆盖星 width:50%）
    // 点击走前端 attachRate：左半（half=1）→ idx-0.5，右半 → idx
    func buildItem(idx: Int64, isActive: Bool, halfCell: Bool): IComponent {
        var iconCls = "el-rate__icon"
        if (isActive || halfCell) { iconCls = "${iconCls} is-active" }

        let iconChildren = ArrayList<IComponent>()
        if (halfCell) {
            iconChildren.add(Icon("star").size("18px").render())
            iconChildren.add(VNode("span", [Icon("star").size("18px").render()], attrs: Some(HashMap<String, String>([("class", "el-rate__icon el-rate__decimal-box")]))))
            iconChildren.add(VNode("span", [Icon("star-filled").size("18px").render()], attrs: Some(HashMap<String, String>([("class", "el-rate__icon el-rate__decimal is-active"), ("style", "width:50%")]))))
        } else {
            if (isActive) {
                iconChildren.add(Icon("star-filled").size("18px").render())
            } else {
                iconChildren.add(Icon("star").size("18px").render())
            }
        }

        let iconColor = if (isActive || halfCell) { "#f7ba2a" } else { "#c6d1de" }
        let icon = VNode("span", iconChildren.toArray(), attrs: Some(HashMap<String, String>([("class", iconCls), ("style", "color:${iconColor}")])))
        let item = VNode("span", [icon], attrs: Some(HashMap<String, String>([("class", "el-rate__item"), ("style", "cursor:pointer")])))
        match (this._signal) {
            case Some(s) =>
                if (this._disabled) { item } else {
                    let captureIdx = idx
                    item.onClick({ ctx =>
                        let half = ctx.params.get("half") == Some("1")
                        s.set(rateValueFromClick(captureIdx, half))
                        PatchResult.ReRender
                    })
                }
            case None => item
        }
    }
}
