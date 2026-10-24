package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}
import std.convert.*

// ============ Carousel 走马灯（对齐 Element Plus carousel） ============
//
// EP 结构（carousel.vue / carousel-item.vue）：
//   div.el-carousel.el-carousel--<direction>[.is-vertical-outside]
//     ├─ button.el-carousel__arrow.el-carousel__arrow--left|--right      ← arrow != never 且非 vertical
//     ├─ div.el-carousel__container[style=height:Npx]
//     │    └─ div.el-carousel__item[.is-active][.is-in-stage][.is-animating][.el-carousel__item--card]
//     │         └─ div.el-carousel__mask                                  ← card 类型的非激活遮罩
//     └─ ul.el-carousel__indicators.el-carousel__indicators--<direction>[--labels][--outside][--right]
//          └─ li.el-carousel__indicator.el-carousel__indicator--<direction>[.is-active]
//               └─ button.el-carousel__button > span（有 label 时）
//
// 与 EP 的**必要偏差（位移计算）**：EP 的 use-carousel-item 用 `translate` 像素值来摆位，
// 依赖 `root.offsetWidth/offsetHeight`（ResizeObserver 量出来的容器尺寸），服务端拿不到。
// 但 CSS 的**百分比 translate 是相对元素自身尺寸**，而 `.el-carousel__item` 的宽/高都是
// 容器的 100%，所以「第 i 项相对当前项偏移 (i - active) 个身位」可以写成
// `translateX((i-active)*100%)`，**与容器像素宽度无关**。这就是本实现采用的等价表达：
// 非激活项被容器（`.el-carousel--horizontal { overflow: hidden }`）裁掉，激活项居中，
// 切换时由 `.is-animating` 的 `transition: transform .4s` 产生与 EP 一致的滑动动画。
//
// **未实现**：
// - `autoplay` / `interval`：EP 靠 `setInterval` 在客户端推进。cjxt 的组件不持有定时器
//   （服务端每轮渲染是纯函数，无组件级时钟），自动轮播需要在 `public/js/cangjie-ui.js` 加
//   一条「到点发 bind 消息」的机制（对照已有 `data-auto-dismiss` 的实现）。本组件已按 EP
//   结构备好 DOM 与 `data-carousel` 标记，接线时无需改结构；当前只支持手动切换。
// - `type=card` 的层叠位移：EP 的卡式布局按 `(2-cardScale)*(index-active)+1)/4 * parentWidth`
//   摆位，同样依赖容器像素宽度；这里只落地 card 的类名与遮罩（结构对齐），不叠加 3D 位移。
// - `motionBlur`：EP 是过渡期加 `filter: url(#elCarouselHorizontal)`，它只影响动画过程中的
//   观感，服务端渲染无过渡期状态，故不渲染那段内联 svg。

public class CarouselItem <: Component {
    var _children: Array<IComponent>
    var _name: String = ""
    var _label: String = ""

    public init(children: Array<IComponent>) { this._children = children }

    // name 用于按名字切换（EP 的 setActiveItem 接受 name）
    public func name(v: String): CarouselItem { this._name = v; this }
    // label 非空时指示器变成文字按钮（EP 的 indicators--labels）
    public func label(v: String): CarouselItem { this._label = v; this }

    // 自身不单独成树（由 Carousel 统一布局）
    public func render(): IComponent { div([]) }
}

public class Carousel <: Component {
    var _children: Array<IComponent>
    var _activeSignal: Option<Signal<Int64>> = None
    var _initialIndex: Int64 = 0
    var _height: String = ""
    var _direction: CarouselDirection = CarouselDirection.Horizontal
    var _typ: CarouselType = CarouselType.Default
    var _loop: Bool = true
    var _arrow: String = "hover"            // always | hover | never
    var _indicatorPosition: String = ""     // "" | none | outside
    var _trigger: String = "hover"          // hover | click（指示器触发方式）
    var _cardScale: String = "0.83"          // EP 默认 0.83
    var _onChange: Option<ActionHandler> = None

    public init(children: Array<IComponent>) { this._children = children }

    public func bind(signal: Signal<Int64>): Carousel { this._activeSignal = Some(signal); this }
    public func initialIndex(v: Int64): Carousel { this._initialIndex = v; this }
    public func height(v: String): Carousel { this._height = v; this }
    public func direction(v: CarouselDirection): Carousel { this._direction = v; this }
    public func carouselType(v: CarouselType): Carousel { this._typ = v; this }
    public func loop(v: Bool): Carousel { this._loop = v; this }
    public func arrow(v: String): Carousel { this._arrow = v; this }
    public func indicatorPosition(v: String): Carousel { this._indicatorPosition = v; this }
    public func trigger(v: String): Carousel { this._trigger = v; this }
    // card 类型下次级卡的缩放比例（EP 的 cardScale，默认 0.83）
    public func cardScale(v: String): Carousel { this._cardScale = v; this }
    public func onChange(h: ActionHandler): Carousel { this._onChange = Some(h); this }

    public func render(): IComponent {
        let items = this.collectItems()
        let active = this.effectiveActive(items.size)
        let isVertical = isVerticalDirection(this._direction)
        let isCard = isCardType(this._typ)
        let layoutCls = this._direction.asClass()

        let children = ArrayList<IComponent>()

        // 箭头：EP 里 vertical 不显示箭头（arrowDisplay = arrow !== never && !isVertical）
        if (this._arrow != "never" && !isVertical) {
            children.add(this.buildArrow(active, items.size, "left"))
            children.add(this.buildArrow(active, items.size, "right"))
        }

        // 容器 + 各 item
        let itemNodes = ArrayList<IComponent>()
        var i = 0
        for (it in items) {
            itemNodes.add(this.buildItem(it, i, active, isVertical, isCard))
            i = i + 1
        }
        let containerAttrs = HashMap<String, String>([("class", "el-carousel__container")])
        if (this._height != "") {
            containerAttrs["style"] = "height:${normalizeCssLength(this._height)}"
        }
        children.add(VNode("div", itemNodes.toArray(), attrs: Some(containerAttrs)))

        // 指示器
        if (this._indicatorPosition != "none") {
            children.add(this.buildIndicators(items, active, layoutCls, isVertical))
        }

        var rootCls = "el-carousel el-carousel--${layoutCls}"
        if (isCard) { rootCls = "${rootCls} el-carousel--card" }
        if (isVertical && this._indicatorPosition == "outside") { rootCls = "${rootCls} is-vertical-outside" }

        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([
            ("class", rootCls),
            ("data-carousel", layoutCls),
        ])))
    }

    func collectItems(): ArrayList<CarouselItem> {
        let out = ArrayList<CarouselItem>()
        for (c in this._children) {
            match (c) {
                case it: CarouselItem => out.add(it)
                case _ => ()
            }
        }
        out
    }

    func activeIndex(): Int64 {
        match (this._activeSignal) {
            case Some(s) => s.get()
            case None => this._initialIndex
        }
    }

    // EP 的 setActiveItem 边界处理：越界时 loop 折返，否则夹到首/尾
    func effectiveActive(count: Int64): Int64 {
        if (count <= 0) { return 0 }
        let raw = this.activeIndex()
        if (raw < 0) { return if (this._loop) { count - 1 } else { 0 } }
        if (raw >= count) { return if (this._loop) { 0 } else { count - 1 } }
        raw
    }

    func buildItem(it: CarouselItem, index: Int64, active: Int64, isVertical: Bool, isCard: Bool): IComponent {
        let isActive = index == active
        var cls = "el-carousel__item"
        if (isActive) { cls = "${cls} is-active" }
        // 与服务端模型相关：每轮渲染都是新树，插值位移是一次性设定的终态，
        // 所以恒挂 is-animating 让「换页 → 新的终态」走 transition（EP 在动画期间才挂）。
        cls = "${cls} is-animating"
        if (isCard) {
            cls = "${cls} el-carousel__item--card"
            if (isVertical) { cls = "${cls} el-carousel__item--card-vertical" }
            if (isActive) { cls = "${cls} is-in-stage" }
        }

        // 相对当前项的「身位」偏移，用百分比表达（详见文件头注释）
        let offset = index - active
        let translate = if (isVertical) { "translateY(${offset * 100}%)" } else { "translateX(${offset * 100}%)" }
        var transform = translate
        if (isCard) { transform = "${translate} scale(${cardScaleCss(isActive, this._cardScale)})" }
        let style = "transform:${transform}"

        let inner = ArrayList<IComponent>(it._children)
        // card 类型的非激活项盖一层白色遮罩（EP 的 __mask）
        if (isCard && !isActive) {
            inner.add(VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-carousel__mask")]))))
        }

        let attrs = HashMap<String, String>([("class", cls), ("style", style)])
        if (it._name != "") { attrs["data-name"] = it._name }
        // EP 的 item 点击在 card 类型用于切到该卡；这里统一提供切换入口（点击非激活项切过去）
        let el = VNode("div", inner.toArray(), attrs: Some(attrs))
        if (!isActive) {
            el.onClick({ ctx => this.setActive(index, ctx) })
        } else {
            el
        }
    }

    func buildArrow(active: Int64, count: Int64, side: String): IComponent {
        let isLeft = side == "left"
        // EP: v-show="(arrow==='always' || hover) && (loop || activeIndex > 0)"
        // 服务端没有 hover 态，按 arrow 的值决定是否输出可见箭头；loop 关闭时在端点隐藏
        let atBoundary = if (isLeft) { active <= 0 } else { active >= count - 1 }
        let hiddenByLoop = atBoundary && !this._loop
        if (hiddenByLoop) { return EmptyVNode() }

        let cls = "el-carousel__arrow el-carousel__arrow--${side}"
        let icon = Icon(if (isLeft) { "arrow-left" } else { "arrow-right" })
        var btn = VNode("button", [icon], attrs: Some(HashMap<String, String>([
            ("class", cls),
            ("type", "button"),
            ("aria-label", if (isLeft) { "上一张" } else { "下一张" }),
        ])))
        let target = if (isLeft) { active - 1 } else { active + 1 }
        btn.onClick({ ctx => this.setActive(target, ctx) })
    }

    func buildIndicators(items: ArrayList<CarouselItem>, active: Int64, layoutCls: String, isVertical: Bool): IComponent {
        var hasLabel = false
        for (it in items) { if (it._label != "") { hasLabel = true } }

        // 类名必须与方向一致：EP 的纵向指示器是 `.el-carousel__indicators--vertical`
        // （scss 里给它 right:0 + top:50% + translateY(-50%)，竖排居中）。
        // 原来纵向时错误地加了 `--right`（该类只有 right:0，没有垂直居中），
        // 于是指示器落在容器下半部分、且只露出一半。
        // layoutCls 已经是 "vertical"/"horizontal"，直接用即可。
        var cls = "el-carousel__indicators el-carousel__indicators--${layoutCls}"
        if (hasLabel) { cls = "${cls} el-carousel__indicators--labels" }
        if (this._indicatorPosition == "outside") { cls = "${cls} el-carousel__indicators--outside" }

        let lis = ArrayList<IComponent>()
        var i = 0
        for (it in items) {
            // lambda 不能捕获可变变量（编译期报 "'i' is mutable"）→ 每轮取一个不可变副本
            let idx = i
            var liCls = "el-carousel__indicator el-carousel__indicator--${layoutCls}"
            if (idx == active) { liCls = "${liCls} is-active" }
            let labelSpan: Array<IComponent> = if (hasLabel) { [text(it._label)] } else { [] }
            let buttonAttrs = HashMap<String, String>([
                ("class", "el-carousel__button"),
                ("aria-label", "第 ${idx + 1} 张"),
            ])
            let btn = VNode("button", labelSpan, attrs: Some(buttonAttrs))
            let li = VNode("li", [btn], attrs: Some(HashMap<String, String>([("class", liCls)])))
            lis.add(li.onClick({ ctx => this.setActive(idx, ctx) }))
            i = i + 1
        }
        VNode("ul", lis.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
    }

    func setActive(index: Int64, ctx: ActionContext): PatchResult {
        match (this._activeSignal) {
            case Some(s) =>
                if (index != s.get()) {
                    s.set(index)
                    match (this._onChange) {
                        case Some(fn) => runCb(fn, ctx)
                        case None => ()
                    }
                }
            case None => ()
        }
        PatchResult.ReRender
    }
}

func isVerticalDirection(d: CarouselDirection): Bool {
    match (d) {
        case Horizontal => false
        case Vertical => true
    }
}

func isCardType(t: CarouselType): Bool {
    match (t) {
        case Card => true
        case Default => false
    }
}

// card 类型下激活项不缩放、非激活项缩到 cardScale（EP 的 scale：激活=1，其余=cardScale）
func cardScaleCss(isActive: Bool, scale: String): String {
    if (isActive) { return "1" }
    scale
}

// 尺寸归一：带单位原样用，裸数字按 px
func normalizeCssLength(raw: String): String {
    let v = raw.trimAscii()
    if (v == "") { return v }
    if (v.endsWith("%") || v.endsWith("px") || v.endsWith("rem") || v.endsWith("vh") || v.endsWith("em")) { return v }
    "${v}px"
}
