package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ── Timeline 时间线 ───────────────────────────────────────────────────────────
//
// 对齐 element-plus timeline/src/timeline.vue 与 timeline-item.vue：
//
//   ul.el-timeline.is-{mode}
//     li.el-timeline-item[.el-timeline-item__center].is-{mode}
//       div.el-timeline-item__tail
//       div.el-timeline-item__node.el-timeline-item__node--{size}--{type}[.is-hollow]
//         i.el-icon.el-timeline-item__icon > svg            （设了 icon 时）
//       div.el-timeline-item__dot > …                       （有 dot 内容时，替代 node）
//       div.el-timeline-item__wrapper
//         div.el-timeline-item__timestamp.is-top            （placement=top）
//         div.el-timeline-item__content
//         div.el-timeline-item__timestamp.is-bottom         （placement=bottom）
//
// 两个注意点：
// 1. `is-{mode}` 同时加在 ul 与 li 上（EP 的 TimelineItem 从父级 inject 取 mode），
//    横排布局（alternate 系列）的左右分配全靠 li 上这个类，缺了就只有单侧。
// 2. `__node--{type}` 只在设了 type 时才出现：EP 用 `ns.em('node', props.type || '')`，
//    modifier 为空串时 em() 返回空串，不会留下 `__node--` 这种残类。

public class Timeline <: Component {
    var _children: Array<IComponent>
    var _mode: String = "start"
    var _reverse: Bool = false

    public init(children: Array<IComponent>) { this._children = children }

    // start | alternate | alternate-reverse | end（EP 的 values 口径）
    public func mode(v: String): Timeline { this._mode = v; this }
    public func reverse(): Timeline { this._reverse = true; this }

    public func render(): IComponent {
        let items = ArrayList<IComponent>()
        for (c in this._children) {
            // 把 mode 下发给直接子节点里的 TimelineItem —— EP 靠 provide/inject 传递，
            // cjxt 没有 inject，改为构造期写入（与 Steps 扫子组件同思路）。
            match (c) {
                case item: TimelineItem =>
                    item.setTimelineMode(this._mode)
                    items.add(item)
                case _ => items.add(c)
            }
        }
        let ordered = if (this._reverse) { reversedOf(items) } else { items }
        VNode("ul", ordered.toArray(), attrs: Some(HashMap<String, String>([
            ("class", "el-timeline is-${this._mode}")
        ])))
    }
}

// 逆序（不依赖 ArrayList.reverse 的可用性，手工倒着取）
func reversedOf(items: ArrayList<IComponent>): ArrayList<IComponent> {
    let out = ArrayList<IComponent>()
    var i = items.size - 1
    while (i >= 0) {
        out.add(items[i])
        i -= 1
    }
    out
}

public class TimelineItem <: Component {
    var _children: Array<IComponent>
    var _timestamp: String = ""
    var _hideTimestamp: Bool = false
    var _center: Bool = false
    var _placement: TimelineItemPlacement = TimelineItemPlacement.Bottom
    var _type: Option<TimelineItemType> = None
    var _color: String = ""
    var _size: TimelineItemSize = TimelineItemSize.Normal
    var _icon: String = ""
    var _hollow: Bool = false
    var _dot: Array<IComponent> = []
    // 父级 Timeline 的 mode（EP 的 inject，由 Timeline.render 写入；独立使用时取默认 start）
    var _timelineMode: String = "start"

    public init(children: Array<IComponent>) { this._children = children }

    public func timestamp(v: String): TimelineItem { this._timestamp = v; this }
    public func hideTimestamp(): TimelineItem { this._hideTimestamp = true; this }
    // 时间线节点与内容垂直居中（EP 的 center）
    public func center(): TimelineItem { this._center = true; this }
    public func placement(v: TimelineItemPlacement): TimelineItem { this._placement = v; this }
    public func itemType(v: TimelineItemType): TimelineItem { this._type = Some(v); this }
    public func color(v: String): TimelineItem { this._color = v; this }
    public func size(v: TimelineItemSize): TimelineItem { this._size = v; this }
    // 节点内图标（Icon.cj 的图标名，如 "check" / "clock"）
    public func icon(v: String): TimelineItem { this._icon = v; this }
    public func hollow(): TimelineItem { this._hollow = true; this }
    // 自定义节点内容（EP 的 dot 插槽）：给了 dot 就不再渲染默认 node
    public func dot(v: Array<IComponent>): TimelineItem { this._dot = v; this }

    func setTimelineMode(mode: String): Unit { this._timelineMode = mode }

    public func render(): IComponent {
        let parts = ArrayList<IComponent>()
        // tail：竖线（scss 用 li:last-child 隐藏最后一条）
        parts.add(VNode("div", [], attrs: Some(HashMap<String, String>([
            ("class", "el-timeline-item__tail")
        ]))))
        if (this._dot.size > 0) {
            parts.add(VNode("div", this._dot, attrs: Some(HashMap<String, String>([
                ("class", "el-timeline-item__dot")
            ]))))
        } else {
            parts.add(this.buildNode())
        }
        parts.add(this.buildWrapper())

        var itemCls = "el-timeline-item"
        if (this._center) { itemCls = "${itemCls} el-timeline-item__center" }
        itemCls = "${itemCls} is-${this._timelineMode}"
        VNode("li", parts.toArray(), attrs: Some(HashMap<String, String>([("class", itemCls)])))
    }

    func buildNode(): IComponent {
        var nodeCls = "el-timeline-item__node el-timeline-item__node--${this._size.asClass()}"
        match (this._type) {
            case Some(t) => nodeCls = "${nodeCls} el-timeline-item__node--${t.asClass()}"
            case None => ()
        }
        if (this._hollow) { nodeCls = "${nodeCls} is-hollow" }
        let attrs = HashMap<String, String>([("class", nodeCls)])
        // EP 内联 backgroundColor（scss 的 --el-timeline-node-color 是默认色），hollow 时同样内联
        if (this._color != "") { attrs["style"] = "background-color:${this._color}" }
        let inner = ArrayList<IComponent>()
        if (this._icon != "") {
            inner.add(Icon(this._icon).cls("el-timeline-item__icon"))
        }
        VNode("div", inner.toArray(), attrs: Some(attrs))
    }

    func buildWrapper(): IComponent {
        let parts = ArrayList<IComponent>()
        let placementCls = this._placement.asClass()
        if (!this._hideTimestamp && placementCls == "top") {
            parts.add(this.buildTimestamp("top"))
        }
        parts.add(VNode("div", this._children, attrs: Some(HashMap<String, String>([
            ("class", "el-timeline-item__content")
        ]))))
        if (!this._hideTimestamp && placementCls == "bottom") {
            parts.add(this.buildTimestamp("bottom"))
        }
        VNode("div", parts.toArray(), attrs: Some(HashMap<String, String>([
            ("class", "el-timeline-item__wrapper")
        ])))
    }

    func buildTimestamp(pos: String): IComponent {
        VNode("div", [text(this._timestamp)], attrs: Some(HashMap<String, String>([
            ("class", "el-timeline-item__timestamp is-${pos}")
        ])))
    }
}
