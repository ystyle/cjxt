package cjxt.components

import cjxt.*
import std.collection.HashMap

// Scrollbar：自定义滚动条容器
//
// 对齐 EP scrollbar.vue 的 DOM 结构：
//   div.el-scrollbar > div.el-scrollbar__wrap > div.el-scrollbar__view > [内容]
//
// 与 EP 的**必要差异**（服务端模型决定，不是偷懒）：
// EP 用 JS 计算 thumb 位置/hover 淡入淡出（bar.vue 的 ratio/move/size 三组状态），
// 那套完全依赖客户端滚动事件与 DOM 测量。cjxt 的滚动条改为：
//   - 默认 native = true：`.el-scrollbar__wrap` 用浏览器原生滚动条
//     （EP 的 `__wrap--hidden-default` 会把原生滚动条藏掉，所以此时不加该类）；
//   - native = false 时按 EP 加 `hidden-default`（隐藏原生滚动条），
//     由使用方自行提供滚动指示（例如配合前端 data-scroll-* 机制）。
// 两条路径都保留 EP 的 wrap/view 结构与 CSS 变量，视觉容器一致。
public class Scrollbar <: Component {
    var _children: Array<IComponent>
    var _native: Bool = true
    var _height: String = ""
    var _maxHeight: String = ""
    var _wrapClass: String = ""
    var _viewClass: String = ""
    var _style: String = ""

    public init(children: Array<IComponent>) { this._children = children }

    // 是否使用浏览器原生滚动条（默认 true）。EP 语义是 native 时不出自定义 bar。
    public func native(v: Bool): Scrollbar { this._native = v; this }
    public func height(v: String): Scrollbar { this._height = v; this }
    public func maxHeight(v: String): Scrollbar { this._maxHeight = v; this }
    public func wrapClass(v: String): Scrollbar { this._wrapClass = v; this }
    public func viewClass(v: String): Scrollbar { this._viewClass = v; this }
    public func style(v: String): Scrollbar { this._style = v; this }

    public func render(): IComponent {
        // wrap：EP 在 !native 时加 __wrap--hidden-default（隐藏原生滚动条）
        var wrapCls = "el-scrollbar__wrap"
        if (!this._native) { wrapCls = "${wrapCls} el-scrollbar__wrap--hidden-default" }
        if (this._wrapClass != "") { wrapCls = "${wrapCls} ${this._wrapClass}" }

        var viewCls = "el-scrollbar__view"
        if (this._viewClass != "") { viewCls = "${viewCls} ${this._viewClass}" }

        let view = VNode("div", this._children, attrs: Some(HashMap<String, String>([("class", viewCls)])))
        let wrap = div([view], attrs: Some(HashMap<String, String>([("class", wrapCls)])))

        let rootAttrs = HashMap<String, String>([("class", "el-scrollbar")])
        var style = this.rootStyle()
        if (this._style != "") {
            style = if (style == "") { this._style } else { "${style};${this._style}" }
        }
        if (style != "") { rootAttrs["style"] = style }

        div([wrap], attrs: Some(rootAttrs))
    }

    // 高度走内联（EP 的 height/maxHeight 也是作用于根元素的内联 style）
    func rootStyle(): String {
        var s = ""
        if (this._height != "") { s = "height:${this._height}" }
        if (this._maxHeight != "") {
            let part = "max-height:${this._maxHeight}"
            s = if (s == "") { part } else { "${s};${part}" }
        }
        s
    }
}
