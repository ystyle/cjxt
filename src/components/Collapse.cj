package cjxt.components

import cjxt.*
import cjxt.collapseToggleActive
import cjxt.collapseIsActive
import std.collection.{HashMap, ArrayList}

public class CollapseItem <: Component {
    var _title: String
    var _name: String
    var _children: Array<IComponent>
    var _disabled: Bool = false
    var _groupSignal: Option<Signal<ArrayList<String>>> = None
    var _accordion: Bool = false

    public init(children: Array<IComponent>, title: String, name: String) {
        this._children = children
        this._title = title
        this._name = name
    }
    public func disabled(v: Bool): CollapseItem { this._disabled = v; this }
    public func getChildren(): Array<IComponent> { this._children }
    func setGroupSignal(s: Signal<ArrayList<String>>, accordion: Bool): Unit {
        this._groupSignal = Some(s)
        this._accordion = accordion
    }

    public func render(): IComponent {
        let active = match (this._groupSignal) {
            case Some(s) => collapseIsActive(s.get(), this._name)
            case None => false
        }
        var cls = "el-collapse-item"
        if (active) { cls = "${cls} is-active" }
        if (this._disabled) { cls = "${cls} is-disabled" }
        let attrs = HashMap<String, String>([("class", cls)])

        // header：点击切换（disabled 无 action）；箭头 EP el-collapse-item__arrow rotate
        var headerCls = "el-collapse-item__header"
        if (active) { headerCls = "${headerCls} is-active" }
        let arrowIcon = Icon("arrow-down").size("14px").render()
        let arrowStyle = if (active) { "transform: rotate(180deg)" } else { "transform: none" }
        let arrow = VNode("span", [arrowIcon], attrs: Some(HashMap<String, String>([("class", "el-collapse-item__arrow"), ("style", arrowStyle)])))
        let header = VNode("div", [
            VNode("span", [text(this._title)], attrs: Some(HashMap<String, String>([("class", "el-collapse-item__header-text")]))),
            arrow,
        ], attrs: Some(HashMap<String, String>([("class", headerCls), ("role", "button"), ("aria-expanded", if (active) { "true" } else { "false" })])))

        let headerEl = if (this._disabled) { header } else {
            let n = this._name
            header.onClick({ ctx =>
                match (this._groupSignal) {
                    case Some(s) => s.set(collapseToggleActive(s.get(), n, this._accordion))
                    case None => ()
                }
                PatchResult.ReRender
            })
        }

        let childrenParts = ArrayList<IComponent>()
        childrenParts.add(headerEl)
        // 仅激活时渲染内容（EP v-show 语义；服务端条件渲染，收起不占 DOM）
        if (active) {
            childrenParts.add(VNode("div", [VNode("div", this._children, attrs: Some(HashMap<String, String>([("class", "el-collapse-item__content-box")])))], attrs: Some(HashMap<String, String>([("class", "el-collapse-item__content")]))))
        }
        VNode("div", childrenParts.toArray(), attrs: Some(attrs))
    }
}

public class Collapse <: Component {
    var _children: Array<IComponent>
    var _accordion: Bool = false
    var _activeSignal: Signal<ArrayList<String>>

    public init(children: Array<IComponent>) {
        this._children = children
        this._activeSignal = Signal<ArrayList<String>>(ArrayList<String>())
    }
    public func accordion(): Collapse { this._accordion = true; this }
    public func getChildren(): Array<IComponent> { this._children }

    public func render(): IComponent {
        let items = ArrayList<IComponent>()
        for (c in this._children) {
            match (c) {
                case item: CollapseItem =>
                    item.setGroupSignal(this._activeSignal, this._accordion)
                    items.add(item)
                case _ => items.add(c)
            }
        }
        VNode("div", items.toArray(), attrs: Some(HashMap<String, String>([("class", "el-collapse")])))
    }
}
