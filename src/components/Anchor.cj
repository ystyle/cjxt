package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ============ Anchor 锚点导航（对齐 Element Plus anchor / anchor-link） ============
//
// EP 的 DOM：`.el-anchor[--vertical|--horizontal][--underline]` > `.el-anchor__marker`?
//   + `.el-anchor__list` > `.el-anchor__item` > `a.el-anchor__link`
// 结构、类名、marker 元素全部照搬（marker 是 scss 里 `__marker` 的定位载体）。
//
// 交互分两层，都不需要前端 JS：
//   ① 点击跳转 → `a.el-anchor__link` 的 href 就是 `#id`，**浏览器原生锚点跳转**。
//      EP 用 JS 做平滑滚动 + offset 补偿（scrollToAnchor: distance - offset）。
//      原生跳转没有 offset 补偿，所以这里用 `scroll-margin-top` 把目标元素的吸附边
//      让开 offset 距离——CSS 的对应能力，滚动行为交给浏览器。
//      注意 scroll-margin 生效在**跳转目标元素**上（#id 那个元素），不是锚点自己身上，
//      故 Anchor / AnchorLink 的 scrollOffsetStyle(offset) 供业务拼到目标元素 style 上。
//   ② 当前选中项高亮（EP 的 currentAnchor/is-active）→ 需要滚动位置，服务端读不到。
//      若外部给了绑定信号（bindAnchorCurrent），则按它渲染 is-active；
//      没给就只渲染静态导航（高亮留给将来接滚动监听）。这与本仓 VirtualList
//      「滚动位置是客户端状态、必须走 Signal 外置」的既有结论一致。
//
// 未实现（诚实列出）：marker 的跟随定位（EP 在 watch currentAnchor 后用 rect 差值写
// top/left/width，纯客户端测量）、selectScrollTop、container 指定滚动容器。
// marker 元素本身照常渲染，但没有定位数据时不会显示（scss 默认 opacity: 0）。
//
// AnchorDirection（vertical / horizontal）定义在 Types.cj：它是跨组件的布局方向枚举，
// 与 SplitterLayout / CarouselDirection 同类，统一收在类型表里。

// AnchorLink —— 单个锚点项。数据载体 + 可独立渲染（EP 里它也是独立组件）。
public class AnchorLink <: Component {
    var _title: String = ""
    var _href: String = ""
    var _offset: Int64 = 0
    var _active: Bool = false
    var _children: Array<IComponent> = []
    var _subLinks: Array<AnchorLink> = []
    var _onClick: Option<ActionHandler> = None

    public init(title: String, href: String) {
        this._title = title
        this._href = href
        this._children = [text(title)]
    }
    public init(children: Array<IComponent>, href: String) {
        this._children = children
        this._href = href
    }

    // 点开时让出的距离（px）：落到目标元素的内联 scroll-margin-top 上
    public func offset(v: Int64): AnchorLink { this._offset = v; this }
    public func active(v: Bool): AnchorLink { this._active = v; this }
    // 子锚点（EP 的 sub-link 插槽，仅纵向渲染）
    public func subLinks(links: Array<AnchorLink>): AnchorLink { this._subLinks = links; this }
    // 额外回调（EP 的 click 事件）：不负责滚动，滚动由原生锚点完成
    public func onClick(h: ActionHandler): AnchorLink { this._onClick = Some(h); this }

    // 独立使用时的默认渲染（无父 Anchor 时）。纵向、不激活。
    public func render(): IComponent {
        renderLink(this._title, this._href, this._children, this._offset, this._active, this._subLinks, this._onClick, AnchorDirection.Vertical)
    }
}

// Anchor —— 容器。子节点既可以是 AnchorLink 实例，也可以是普通组件（原样渲染）。
public class Anchor <: Component {
    var _children: Array<IComponent>
    var _direction: AnchorDirection = AnchorDirection.Vertical
    var _offset: Int64 = 0
    var _underline: Bool = false
    var _marker: Bool = true
    var _currentHref: String = ""
    var _currentSignal: Option<Signal<String>> = None
    var _style: String = ""

    // 唯一构造器：接收任意组件数组（AnchorLink 本身就是 IComponent，直接混进去即可）。
    //
    // 不能同时提供 `init(links: Array<AnchorLink>)` 重载：`Anchor([AnchorLink(...)])` 对
    // 两个签名都成立（AnchorLink <: IComponent，且仓颉不会"选更具体的那个"）→
    // "ambiguous match for constructor call 'Anchor'"，整个测试包都编译不了。
    // 只收链接的写法走下面的静态工厂 ofLinks（显式、无歧义）。
    public init(children: Array<IComponent>) { this._children = children }

    // 便捷：只给链接时用 `Anchor.ofLinks([...])`（替代会歧义的构造器重载）
    public static func ofLinks(links: Array<AnchorLink>): Anchor {
        let arr = ArrayList<IComponent>()
        for (l in links) { arr.add(l) }
        Anchor(arr.toArray())
    }

    public func direction(v: AnchorDirection): Anchor { this._direction = v; this }
    // 所有链接的默认 offset（单个链接上的 offset 覆盖它）
    public func offset(v: Int64): Anchor { this._offset = v; this }
    // EP type="underline" 的视觉变体
    public func underline(): Anchor { this._underline = true; this }
    public func marker(v: Bool): Anchor { this._marker = v; this }
    // 当前激活项（等价 EP 的 currentAnchor）。也可用 bindAnchorCurrent 走信号。
    public func current(href: String): Anchor { this._currentHref = href; this }
    public func bindAnchorCurrent(s: Signal<String>): Anchor { this._currentSignal = Some(s); this }
    public func style(v: String): Anchor { this._style = v; this }

    public func render(): IComponent {
        let current = this.resolveCurrent()
        let attrs = HashMap<String, String>([
            ("class", this.rootClass()),
            ("role", "navigation"),
            ("aria-label", "Anchor"),
            // 前端据此挂「按 location.hash 高亮」（data-anchor-active="hash"）。
            // 高亮不需要滚动高度或服务端往返：点击后 hash 已变，前端直接比对 href 即可，
            // 这样还天然支持前进/后退与直接带 hash 打开页面。
            ("data-anchor-active", "hash"),
        ])
        if (this._style != "") { attrs["style"] = this._style }

        let parts = ArrayList<IComponent>()
        // EP: marker 在 list 之前，作为同一容器内的绝对定位子节点
        if (this._marker) {
            parts.add(VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-anchor__marker")]))))
        }

        let linkChildren = ArrayList<IComponent>()
        for (c in this._children) {
            match (c) {
                case l: AnchorLink =>
                    let off = if (l._offset > 0) { l._offset } else { this._offset }
                    let active = current != "" && l._href == current
                    linkChildren.add(renderLink(l._title, l._href, l._children, off, active, l._subLinks, l._onClick, this._direction))
                case _ => linkChildren.add(c)
            }
        }
        parts.add(VNode("div", linkChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-anchor__list")]))))
        VNode("div", parts.toArray(), attrs: Some(attrs))
    }

    func rootClass(): String {
        // EP: ns.b() + type==underline ? ns.m('underline') : '' + ns.m(direction)
        // direction 映射到 Types.cj 的 AnchorDirection.asClass()
        var cls = "el-anchor el-anchor--${this._direction.asClass()}"
        if (this._underline) { cls = "${cls} el-anchor--underline" }
        cls
    }

    // 信号优先（客户端滚动位置），否则用静态 current()
    func resolveCurrent(): String {
        match (this._currentSignal) {
            case Some(s) => s.get()
            case None => this._currentHref
        }
    }
}

// ---- 内部：渲染一条 a.el-anchor__link（Anchor 与 AnchorLink 共用，保证两处结构一致） ----
func renderLink(title: String, href: String, children: Array<IComponent>, offset: Int64, active: Bool,
                subLinks: Array<AnchorLink>, onClick: Option<ActionHandler>, direction: AnchorDirection): IComponent {
    var linkCls = "el-anchor__link"
    if (active) { linkCls = "${linkCls} is-active" }

    let linkAttrs = HashMap<String, String>([
        ("class", linkCls),
        ("href", href),
    ])
    // offset 打在锚点上是**标记**，真正生效要落到跳转目标元素（见 scrollOffsetStyle）
    if (offset > 0) { linkAttrs["data-anchor-offset"] = "${offset}" }
    // aria-current 必须并进同一个 attrs 表：VNode.attr() 是**整表替换**
    // （vnode.cj: `let m = HashMap(); m[k]=v; this.attrs(m)`），用它追加会连同 class/href 一起抹掉。
    if (active) { linkAttrs["aria-current"] = "true" }

    var link = VNode("a", children, attrs: Some(linkAttrs))
    match (onClick) {
        case Some(h) => link = link.onClick(h)
        case None => ()
    }

    let itemChildren = ArrayList<IComponent>()
    itemChildren.add(link)
    // EP: sub-link 只在纵向渲染，容器是嵌套的 .el-anchor__list
    // （枚举不支持 == 比较，用 match 分发——AGENTS.md「已知仓颉约束」）
    let vertical = match (direction) {
        case AnchorDirection.Vertical => true
        case AnchorDirection.Horizontal => false
    }
    if (vertical && subLinks.size > 0) {
        let subs = ArrayList<IComponent>()
        for (s in subLinks) {
            let soff = if (s._offset > 0) { s._offset } else { offset }
            subs.add(renderLink(s._title, s._href, s._children, soff, s._active, s._subLinks, s._onClick, direction))
        }
        itemChildren.add(VNode("div", subs.toArray(), attrs: Some(HashMap<String, String>([("class", "el-anchor__list")]))))
    }

    VNode("div", itemChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-anchor__item")])))
}

// 原生锚点跳转的 offset 补偿：`scroll-margin` 生效在**被跳转的元素**上，不在 `<a>` 上。
// EP 靠 JS 把距离算成 `distance - offset`；纯 DOM 方案把同样的量交给 CSS。
// 业务这样用：`div([...], attrs: Some(HashMap([("id","sec1"), ("style", scrollOffsetStyle(60))])))`
public func scrollOffsetStyle(offset: Int64): String {
    if (offset <= 0) { return "" }
    "scroll-margin-top:${offset}px"
}
