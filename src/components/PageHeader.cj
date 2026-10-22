package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ============ PageHeader 页头（对齐 Element Plus page-header） ============
//
// EP 的 DOM（page-header.vue）：
//   .el-page-header[.is-contentful][.--has-breadcrumb][.--has-extra]
//     > .el-page-header__breadcrumb?           ← breadcrumb 插槽
//     > .el-page-header__header
//         > .el-page-header__left
//             > .el-page-header__back[role=button][tabindex=0]
//                 > .el-page-header__icon          ← 返回图标
//                 > .el-page-header__title         ← title（默认 locale 文案「返回」/「Back」）
//             > .el-divider.el-divider--vertical   ← EP 用 ElDivider
//             > .el-page-header__content           ← content
//         > .el-page-header__extra?                ← extra 插槽（与 left 同一行、靠右）
//     > .el-page-header__main                  ← 默认插槽（is-contentful 时出现）
//
// 三处按 cjxt 实际情况的处理：
//   ① 图标固定用 arrow-left（EP 的 default icon 是 icons-vue 的 Back 图标，仓内图标表没有
//      「back」，arrow-left 是同一语义；PageHeader 的语义就是「返回」）。
//   ② 返回动作走 cjxt action（onClick → onBack handler），不是浏览器 history.back()：
//      服务端驱动的路由是 route.push，业务通常需要「回到列表页」而非「浏览器后退」。
//      默认（未给 handler）不挂 click，避免渲染出一个点了没反应的按钮。
//   ③ 键盘可达性照 EP：back 是 role=button + tabindex=0 + Enter/Space 触发。
//      （EP 模板只写了 click，键盘是 cjxt 补的；不补的话 tabindex=0 形同虚设。）

public class PageHeader <: Component {
    var _title: String = ""
    var _content: String = ""
    var _onBack: Option<ActionHandler> = None
    var _backIconName: String = "arrow-left"
    var _breadcrumb: Array<IComponent> = []
    var _extra: Array<IComponent> = []
    var _main: Array<IComponent> = []
    var _style: String = ""

    public init() {}
    // 便捷：title + content
    public init(title: String, content: String) {
        this._title = title
        this._content = content
    }

    public func title(v: String): PageHeader { this._title = v; this }
    public func content(v: String): PageHeader { this._content = v; this }
    // 返回动作（EP 的 back 事件）
    public func onBack(h: ActionHandler): PageHeader { this._onBack = Some(h); this }
    // 自定义返回图标名（Icon 组件接受的 name）
    public func backIcon(name: String): PageHeader { this._backIconName = name; this }
    // breadcrumb 插槽（EP 会在根上加 --has-breadcrumb）
    public func breadcrumb(children: Array<IComponent>): PageHeader { this._breadcrumb = children; this }
    // extra 插槽（EP 会在根上加 --has-extra）
    public func extra(children: Array<IComponent>): PageHeader { this._extra = children; this }
    // 默认插槽（EP 渲染成 __main 并给根加 is-contentful）。
    // 方法名不能叫 main：`main` 是仓颉的入口声明保留字（同 type/match/where/quote）
    public func mainContent(children: Array<IComponent>): PageHeader { this._main = children; this }
    public func style(v: String): PageHeader { this._style = v; this }

    public func render(): IComponent {
        let children = ArrayList<IComponent>()

        if (this._breadcrumb.size > 0) {
            children.add(VNode("div", this._breadcrumb, attrs: Some(HashMap<String, String>([("class", "el-page-header__breadcrumb")]))))
        }

        children.add(this.renderHeader())
        // EP: 默认插槽 → __main，且根节点带 is-contentful（scss 靠它给 __main 画上分隔线）
        if (this._main.size > 0) {
            children.add(VNode("div", this._main, attrs: Some(HashMap<String, String>([("class", "el-page-header__main")]))))
        }

        let attrs = HashMap<String, String>([("class", this.rootClass())])
        if (this._style != "") { attrs["style"] = this._style }
        VNode("div", children.toArray(), attrs: Some(attrs))
    }

    func rootClass(): String {
        var cls = "el-page-header"
        if (this._main.size > 0) { cls = "${cls} is-contentful" }
        if (this._breadcrumb.size > 0) { cls = "${cls} el-page-header--has-breadcrumb" }
        if (this._extra.size > 0) { cls = "${cls} el-page-header--has-extra" }
        cls
    }

    func renderHeader(): IComponent {
        let headerChildren = ArrayList<IComponent>()
        headerChildren.add(this.renderLeft())
        if (this._extra.size > 0) {
            headerChildren.add(VNode("div", this._extra, attrs: Some(HashMap<String, String>([("class", "el-page-header__extra")]))))
        }
        VNode("div", headerChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-page-header__header")])))
    }

    func renderLeft(): IComponent {
        let leftChildren = ArrayList<IComponent>()

        // __back：图标 + 标题（EP 把「返回图标 + 标题」一起放在可点击的 back 里）
        let backChildren = ArrayList<IComponent>()
        backChildren.add(VNode("div", [Icon(this._backIconName).render()], attrs: Some(HashMap<String, String>([("class", "el-page-header__icon")]))))
        // EP: title 缺省时取 locale 的 el.pageHeader.title（zh-cn 是「返回」）
        let titleText = if (this._title != "") { this._title } else { "返回" }
        backChildren.add(VNode("div", [text(titleText)], attrs: Some(HashMap<String, String>([("class", "el-page-header__title")]))))

        let backAttrs = HashMap<String, String>([
            ("class", "el-page-header__back"),
            ("role", "button"),
            ("tabindex", "0"),
            ("aria-label", titleText),
        ])
        var back = VNode("div", backChildren.toArray(), attrs: Some(backAttrs))
        // 未给 onBack 时不挂 click：渲染一个点了没反应的按钮比不渲染更糟
        match (this._onBack) {
            case Some(h) =>
                let keyH: ActionHandler = { ctx =>
                    if (isActivateKey(ctx.keyEvent)) { let _ = h(ctx) }
                    PatchResult.ReRender
                }
                back = back.on("click", h).on("keydown", keyH)
            case None => ()
        }
        leftChildren.add(back)

        // EP 在这里放 ElDivider(direction=vertical)；divider 的竖线样式靠 .el-divider--vertical
        leftChildren.add(Divider().direction(DividerDirection.Vertical))

        // __content
        leftChildren.add(VNode("div", [text(this._content)], attrs: Some(HashMap<String, String>([("class", "el-page-header__content")]))))

        VNode("div", leftChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-page-header__left")])))
    }
}

// 激活键：Enter / Space（role=button 的常规键盘语义）
func isActivateKey(ke: Option<KeyEvent>): Bool {
    match (ke) {
        case Some(k) => k.isEnter() || k.code == "Space" || k.key == " "
        case None => false
    }
}
