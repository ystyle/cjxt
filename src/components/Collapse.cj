package cjxt.components

import cjxt.*
import cjxt.collapseToggleActive
import cjxt.collapseIsActive
import std.collection.{HashMap, ArrayList}

// EP 结构（collapse-item.vue）：
//   div.el-collapse-item [is-active] [is-disabled]
//     div.el-collapse-item__header [is-active] [role=button] [aria-expanded] [aria-disabled] [tabindex]
//       span.el-collapse-item__title
//       span.el-collapse-item__arrow [is-active] > i.el-icon > svg(ArrowRight)
//     div.el-collapse-item__wrap [role=region] [aria-hidden]   ← 仅激活时渲染（服务端 v-show）
//       div.el-collapse-item__content
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

        // header
        var headerCls = "el-collapse-item__header"
        if (active) { headerCls = "${headerCls} is-active" }
        let headerAttrs = HashMap<String, String>([
            ("class", headerCls),
            ("role", "button"),
            ("aria-expanded", if (active) { "true" } else { "false" }),
            ("aria-disabled", if (this._disabled) { "true" } else { "false" }),
        ])
        if (!this._disabled) { headerAttrs["tabindex"] = "0" }

        // 箭头：EP 用 ArrowRight；展开时 CSS .is-active { transform: rotate(90deg) }
        let arrowIcon = Icon("arrow-right").size("14px").render()
        var arrowCls = "el-collapse-item__arrow"
        if (active) { arrowCls = "${arrowCls} is-active" }
        let arrow = VNode("span", [arrowIcon], attrs: Some(HashMap<String, String>([("class", arrowCls)])))
        let header = VNode("div", [
            VNode("span", [text(this._title)], attrs: Some(HashMap<String, String>([("class", "el-collapse-item__title")]))),
            arrow,
        ], attrs: Some(headerAttrs))

        // 点击 / 回车 / 空格切换（disabled 无交互）
        let headerEl = if (this._disabled) { header } else {
            let n = this._name
            let clickH: ActionHandler = { ctx =>
                match (this._groupSignal) {
                    case Some(s) => s.set(collapseToggleActive(s.get(), n, this._accordion))
                    case None => ()
                }
                PatchResult.ReRender
            }
            let keyH: ActionHandler = { ctx =>
                if (isToggleKey(ctx.keyEvent)) {
                    match (this._groupSignal) {
                        case Some(s) => s.set(collapseToggleActive(s.get(), n, this._accordion))
                        case None => ()
                    }
                }
                PatchResult.ReRender
            }
            header.on("click", clickH).on("keydown", keyH)
        }

        let childrenParts = ArrayList<IComponent>()
        childrenParts.add(headerEl)
        // 仅激活时渲染 wrap>content（EP v-show 语义；服务端条件渲染，收起不占 DOM）
        if (active) {
            let wrap = VNode("div", [
                VNode("div", this._children, attrs: Some(HashMap<String, String>([("class", "el-collapse-item__content")]))),
            ], attrs: Some(HashMap<String, String>([
                ("class", "el-collapse-item__wrap"),
                ("role", "region"),
                ("aria-hidden", "false"),
            ])))
            childrenParts.add(wrap)
        }
        VNode("div", childrenParts.toArray(), attrs: Some(attrs))
    }
}

// 折叠面板触发键：Enter / Space（EP collapse-item 的 keydown.space.enter）
func isToggleKey(ke: Option<KeyEvent>): Bool {
    match (ke) {
        case Some(k) => k.isEnter() || k.code == "Space" || k.key == " "
        case None => false
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
