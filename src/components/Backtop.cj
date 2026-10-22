package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ============ Backtop 回到顶部（对齐 Element Plus backtop） ============
//
// EP 的可见性与滚动动作都由 JS 驱动：use-backtop.ts 监听 scroll，scrollTop >= visibilityHeight
// 才渲染按钮，点击走 `el.scrollTo({ top: 0, behavior: 'smooth' })`。
// 服务端读不到 scrollTop，所以这里把两件事分别交给浏览器与纯 DOM：
//   ① 可见性 → **不需要服务端参与**：按钮恒渲染，但用 `position: absolute` 之外的方式隐藏？
//      不行——EP 的「滚动超过阈值才出现」本身就是纯客户端状态，服务端无法复现。
//      故这里改为**恒显示**（EP 在长页面里的稳态），把淡入/阈值留给业务 CSS 或后续接监听。
//   ② 回顶动作 → **不依赖 JS**：按钮包一层 `<a href="#">`。浏览器原生锚点跳转到文档顶部，
//      并带 hash 处理；这是一条零 JS、零框架改动的路径。
//
// 关键约束：不能让这个 `#` 跳转被框架当成路由导航。前端 `attachHistoryHandler` 只听 popstate
// （路径变化才发 navigate），`attachClickDelegate` 只处理 `[data-action-click]`，
// 而 `<a href="#">` 两者都不触发——所以点击后只是浏览器滚动，不会切页面。
// 反过来，若给按钮挂 cjxt 的 onClick action，服务端拿到点击却**没有任何办法让浏览器滚动**
// （现有 dom_command 只有 focus/scrollIntoView/setProperty/getProperty，没有 scrollTo），
// 所以那种做法只能空转。这里选锚点。
//
// 已知差异：
//   - 不实现 EP 的 visibilityHeight 显隐与平滑滚动曲线（服务端无滚动状态；`scroll-behavior`
//     可由业务 CSS 控制）。该 prop 仍保留并输出为 data 标记，便于将来接监听。
//   - EP 的 target（自定义滚动容器）在原生锚点下不适用，同样只作 data 标记输出。

public class Backtop <: Component {
    var _children: Array<IComponent> = []
    var _visibilityHeight: Int64 = 200
    var _right: Int64 = 40
    var _bottom: Int64 = 40
    var _target: String = ""
    var _href: String = "#"
    var _style: String = ""
    var _onClick: Option<ActionHandler> = None

    public init() {}
    // 自定义内容（EP 默认插槽）：不给则渲染 EP 的 caret-top 图标
    public init(children: Array<IComponent>) { this._children = children }

    // 按钮开始出现的滚动阈值（当前不驱动显隐，见文件头说明；输出为 data 标记）
    public func visibilityHeight(v: Int64): Backtop { this._visibilityHeight = v; this }
    public func right(v: Int64): Backtop { this._right = v; this }
    public func bottom(v: Int64): Backtop { this._bottom = v; this }
    public func target(selector: String): Backtop { this._target = selector; this }
    // 回顶目标：默认 "#"（文档顶部）。给了具体锚点则滚到该元素。
    public func href(v: String): Backtop { this._href = v; this }
    public func style(v: String): Backtop { this._style = v; this }
    // 额外回调（EP 的 click 事件）。注意：它**不负责滚动**——滚动由原生锚点完成，
    // 服务端侧的滚动指令目前不存在（见文件头）。这里用作埋点/统计等旁路。
    public func onClick(h: ActionHandler): Backtop { this._onClick = Some(h); this }

    public func render(): IComponent {
        // 显式标注类型 + 统一用 ArrayList.toArray()：两个分支分别产出「字段」与「新建数组」，
        // 直接写字面量时编译器会把元素类型退化成 Interface-Any（VNode 构造报 mismatched types）。
        let body: Array<IComponent> = if (this._children.size > 0) {
            this._children
        } else {
            // EP 默认插槽：<el-icon class="el-backtop__icon"><caret-top /></el-icon>
            // 仓内图标表没有 caret-top，用 arrow-up 表达同一语义（向上箭头）。
            let fallback = ArrayList<IComponent>()
            fallback.add(VNode("span", [Icon("arrow-up").render()], attrs: Some(HashMap<String, String>([("class", "el-backtop__icon")]))))
            fallback.toArray()
        }

        var linkAttrs = HashMap<String, String>([
            ("class", "el-backtop__link"),
            ("href", this._href),
            ("aria-label", "回到顶部"),
            // <a> 撑满整个圆按钮（.el-backtop 是 flex 居中容器），否则只有图标本身可点；
            // color/text-decoration 必须继承/清掉，否则按钮文字色被浏览器默认链接样式覆盖。
            ("style", this.linkStyle()),
        ])
        var link = VNode("a", body, attrs: Some(linkAttrs))
        // 旁路回调：挂在 <a> 上会让浏览器同时执行默认跳转与 action，两者不冲突
        match (this._onClick) {
            case Some(h) => link = link.onClick(h)
            case None => ()
        }

        let attrs = HashMap<String, String>([
            ("class", "el-backtop"),
            ("data-backtop", "1"),
            ("data-visibility-height", "${this._visibilityHeight}"),
            // EP 用内联 right/bottom 定位（backtop.scss 里已有 position: fixed）
            ("style", "right:${this._right}px;bottom:${this._bottom}px"),
        ])
        if (this._target != "") { attrs["data-backtop-target"] = this._target }
        VNode("div", [link], attrs: Some(attrs))
    }

    // <a> 铺满按钮 + 继承按钮的前景色，去掉链接默认下划线/蓝色。
    // 放在内联而不是 scss：backtop.scss 是 vendored 的 EP 产物，不该为本地补丁改写。
    func linkStyle(): String {
        var out = "display:flex;align-items:center;justify-content:center;width:100%;height:100%;color:inherit;text-decoration:none;"
        if (this._style != "") { out = "${out}${this._style}" }
        out
    }
}
