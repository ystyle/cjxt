package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// Scrollbar：自定义滚动条容器
//
// 对齐 EP scrollbar.vue 的 DOM 结构：
//   div.el-scrollbar > div.el-scrollbar__wrap > div.el-scrollbar__view > [内容]
//
// 两条路径：
//   - native = true（默认）：`.el-scrollbar__wrap` 用浏览器原生滚动条，不渲染自定义 bar。
//   - native = false：按 EP 加 `hidden-default`（隐藏原生滚动条）**并渲染自定义 bar/thumb**，
//     由前端 `attachScrollbar` 计算 thumb 的尺寸与位移（照 EP bar.vue 的公式）。
//
// 自定义 bar 的实现方式（2026-10-23 补）：
//   EP 的 thumb 尺寸/位移完全靠客户端测量（bar.vue 的 update()），服务端无法预知
//   `scrollHeight / clientHeight`，所以这里只输出**结构骨架**（bar + thumb，尺寸留空），
//   真实几何由前端在渲染后/滚动/resize 时计算并写入内联 style。
//   公式与 EP 一致：offset = wrap.offsetX - GAP；original = offset² / scrollX；
//   size = max(original, minSize)；move = scrollTop * 100 / offset * ratio。
// 这样滚动条「可见、细（6px，来自 scss）、且**不占布局宽度**（absolute 覆盖）」，
// 正是 el-time-spinner 这类窄列需要的形态。
public class Scrollbar <: Component {
    var _children: Array<IComponent>
    var _native: Bool = true
    var _height: String = ""
    var _maxHeight: String = ""
    var _wrapClass: String = ""
    var _viewClass: String = ""
    var _style: String = ""
    // wrap 上的额外属性（如 data-scroll-active）：用于把滚动容器本身交给前端机制识别
    var _wrapAttrs: HashMap<String, String> = HashMap<String, String>()

    public init(children: Array<IComponent>) { this._children = children }

    // 是否使用浏览器原生滚动条（默认 true）。EP 语义是 native 时不出自定义 bar。
    public func native(v: Bool): Scrollbar { this._native = v; this }
    public func height(v: String): Scrollbar { this._height = v; this }
    public func maxHeight(v: String): Scrollbar { this._maxHeight = v; this }
    public func wrapClass(v: String): Scrollbar { this._wrapClass = v; this }
    public func viewClass(v: String): Scrollbar { this._viewClass = v; this }
    public func style(v: String): Scrollbar { this._style = v; this }
    // 给 wrap 追加属性（例：.wrapAttr("data-scroll-active", "true") 让 patch 后自动滚到 .is-active）
    public func wrapAttr(k: String, v: String): Scrollbar { this._wrapAttrs[k] = v; this }

    public func render(): IComponent {
        // wrap：EP 在 !native 时加 __wrap--hidden-default（隐藏原生滚动条）
        var wrapCls = "el-scrollbar__wrap"
        if (!this._native) { wrapCls = "${wrapCls} el-scrollbar__wrap--hidden-default" }
        if (this._wrapClass != "") { wrapCls = "${wrapCls} ${this._wrapClass}" }

        var viewCls = "el-scrollbar__view"
        if (this._viewClass != "") { viewCls = "${viewCls} ${this._viewClass}" }

        let view = VNode("div", this._children, attrs: Some(HashMap<String, String>([("class", viewCls)])))
        let wrapAttrsMap = HashMap<String, String>([("class", wrapCls)])
        for ((k, v) in this._wrapAttrs) { wrapAttrsMap[k] = v }
        let wrap = div([view], attrs: Some(wrapAttrsMap))

        let parts = ArrayList<IComponent>()
        parts.add(wrap)
        // 非 native：渲染 EP 的 bar/thumb 骨架（几何由前端 attachScrollbar 计算）
        if (!this._native) {
            parts.add(this.buildBar(true))
            parts.add(this.buildBar(false))
        }

        let rootAttrs = HashMap<String, String>([("class", "el-scrollbar")])
        if (!this._native) { rootAttrs["data-scrollbar"] = "1" }
        var style = this.rootStyle()
        if (this._style != "") {
            style = if (style == "") { this._style } else { "${style};${this._style}" }
        }
        if (style != "") { rootAttrs["style"] = style }

        div(parts.toArray(), attrs: Some(rootAttrs))
    }

    // bar + thumb 骨架。竖向 is-vertical / 横向 is-horizontal（scss 里 6px 宽/高）。
    // thumb 的 width/height/transform 由前端写入，这里不预置（避免服务端猜测的假尺寸闪烁）。
    func buildBar(isVertical: Bool): IComponent {
        let barCls = if (isVertical) { "el-scrollbar__bar is-vertical" } else { "el-scrollbar__bar is-horizontal" }
        let thumbAttrs = HashMap<String, String>([
            ("class", "el-scrollbar__thumb"),
            ("style", "display:none"),
        ])
        let thumb = VNode("div", [], attrs: Some(thumbAttrs))
        VNode("div", [thumb], attrs: Some(HashMap<String, String>([("class", barCls)])))
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
