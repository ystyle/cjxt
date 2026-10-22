package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ── AvatarGroup 头像组 ────────────────────────────────────────────────────────
//
// 对齐 element-plus avatar/src/avatar-group.tsx：
//
//   div.el-avatar-group
//     span.el-avatar.el-avatar--circle   （子头像；scss 给 .el-avatar 加 1px 边框）
//     …
//     span.el-avatar.el-avatar--circle   （溢出项，内容 "+ N"，可带 collapseClass）
//
// 叠放效果完全由 avatar-group.scss 提供（`display:inline-flex` +
// `.el-avatar:not(:first-child){ margin-left: var(--el-avatar-group-item-gap) }`，
// item-gap 默认 -8px → 相邻头像左移 8px 形成叠压），组件侧不需要写任何定位样式。
//
// 与 EP 的差异（服务端约束，写清而不是留 TODO）：
// - **组级 size / shape 的下发时机**：EP 用 provide/inject，子 Avatar 拿不到自身值时回落到
//   组的值。cjxt 没有 inject，改由本组件在 render 时**写回子 Avatar 的字段**（同包可见）。
//   size 没有歧义（空串即"未设"）；shape 有：`Avatar._shape` 是非 Option、默认 Circle，
//   服务端分不清"没设"和"显式设成 circle"，因此组级 square 会覆盖子头像的 circle 默认值。
//   要保留个别头像为圆形，请在该头像上显式 shape(Circle) 之外的写法——本仓目前无法表达，
//   如需混排请把该头像放到组外。这是有意的取舍，不是漏做。
// - **collapseAvatarsTooltip**：EP 在溢出项上挂 ElTooltip，悬浮展示被折叠的头像列表。
//   这里用原生 `title` 属性给出折叠数量（"还有 N 个头像"），不引入客户端组件。

public class AvatarGroup <: Component {
    var _children: Array<IComponent>
    var _size: String = ""                       // "" | small | large | 数字（px）
    var _shape: Option<AvatarShape> = Option<AvatarShape>.None
    var _collapse: Bool = false
    var _maxCollapse: Int64 = 1
    var _collapseTooltip: Bool = false
    var _collapseClass: String = ""
    var _collapseStyle: String = ""

    public init(children: Array<IComponent>) { this._children = children }

    // 组内头像的尺寸（未单独设置尺寸的头像生效）
    public func size(v: String): AvatarGroup { this._size = v; this }
    public func shape(v: AvatarShape): AvatarGroup { this._shape = Some(v); this }
    // 开启折叠：只显示前 maxCollapseAvatars 个，其余收成 "+N"
    public func collapseAvatars(): AvatarGroup { this._collapse = true; this }
    public func maxCollapseAvatars(n: Int64): AvatarGroup {
        this._collapse = true
        this._maxCollapse = if (n < 0) { 0 } else { n }
        this
    }
    public func collapseAvatarsTooltip(): AvatarGroup { this._collapseTooltip = true; this }
    public func collapseClass(v: String): AvatarGroup { this._collapseClass = v; this }
    public func collapseStyle(v: String): AvatarGroup { this._collapseStyle = v; this }

    public func render(): IComponent {
        let all = this._children
        let collapse = this._collapse && all.size > this._maxCollapse

        let shown = ArrayList<IComponent>()
        var visibleCount = all.size
        if (collapse) { visibleCount = this._maxCollapse }
        var i = 0
        while (i < visibleCount) {
            shown.add(this.applyGroupDefaults(all[i]))
            i += 1
        }
        if (collapse) {
            shown.add(this.buildCollapseAvatar(all.size - visibleCount))
        }

        VNode("div", shown.toArray(), attrs: Some(HashMap<String, String>([
            ("class", "el-avatar-group")
        ])))
    }

    // 组级 size/shape 下发：只补子头像自己没设的那一项
    func applyGroupDefaults(c: IComponent): IComponent {
        match (c) {
            case a: Avatar =>
                if (this._size != "" && a._size == "") { a._size = this._size }
                match (this._shape) {
                    case Some(s) => a._shape = s
                    case None => ()
                }
                a
            case _ => c
        }
    }

    // 溢出项：结构对齐 EP（ElAvatar + collapseClass/collapseStyle，内容 "+ N"）
    func buildCollapseAvatar(hidden: Int64): IComponent {
        let shape = match (this._shape) {
            case Some(s) => s
            case None => AvatarShape.Circle
        }
        var cls = "el-avatar el-avatar--${shape.asClass()}"
        if (this._collapseClass != "") { cls = "${cls} ${this._collapseClass}" }
        let attrs = HashMap<String, String>([("class", cls)])
        var style = ""
        // 尺寸与子头像一致：small/large 走修饰类，数字走 --el-avatar-size 变量
        if (this._size == "small" || this._size == "large") {
            cls = "${cls} el-avatar--${this._size}"
            attrs["class"] = cls
        } else if (this._size != "" && isAllDigits(this._size)) {
            style = "--el-avatar-size:${this._size}px"
        }
        if (this._collapseStyle != "") {
            style = if (style == "") { this._collapseStyle } else { "${style};${this._collapseStyle}" }
        }
        if (style != "") { attrs["style"] = style }
        if (this._collapseTooltip) { attrs["title"] = "还有 ${hidden} 个头像" }
        VNode("span", [text("+ ${hidden}")], attrs: Some(attrs))
    }
}

// 纯数字判定（Avatar.cj 里有同名的成员方法，但那是实例方法，包内不可复用）
func isAllDigits(s: String): Bool {
    if (s.size == 0) { return false }
    for (i in 0..s.size) {
        let c = s[i]
        if (c < 48 || c > 57) { return false }
    }
    true
}
