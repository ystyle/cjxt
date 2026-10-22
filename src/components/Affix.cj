package cjxt.components

import cjxt.*
import std.collection.HashMap

// ============ Affix 吸顶（对齐 Element Plus affix） ============
//
// EP 的做法是 `position: fixed` + JS 滚动测量：affix.vue 用 useElementBounding 把 root 顶部
// 与 offset 比较，判定吸附后把内容 teleport 到 body 并补上测量的宽高（避免脱离文档流后塌陷）。
// cjxt 是服务端驱动，**服务端不知道滚动位置**，所以这里改用 **CSS position: sticky**：
// 「滚到哪里就吸附」完全交给浏览器，零 JS、零前端改动，且吸附点与 EP 的 top 吸附一致。
// sticky 元素仍占据原位，因此不需要 EP 那套「fixed 时补 width/height、留占位」的补偿。
//
// 与 EP 的两处有意差异（都写在这里，不靠读源码的人自己发现）：
//   ① 只有一层节点。EP 恒为 root(.el-affix) + 内层(.el-affix--fixed) 两层，
//      内层是 teleport/测量后的 fixed 定位载体；sticky 不需要搬运节点，多包一层只是多一个空 div。
//   ② 不输出 `.el-affix--fixed`。该类在 EP 里表达的是**运行时状态**「此刻已吸附」，
//      对应 CSS 是 position:fixed，与这里的静态 sticky 不是同一回事（同时输出会打架）。
//      实际定位方式改由 data-affix-position 标记，供业务 CSS 或将来接前端监听时选择。
//
// 已知限制：
//   - sticky 依赖祖先没有 `overflow: hidden/auto`（浏览器的既有约束），也不适用于
//     `display: table` 等场合；EP 的 fixed 方案没有这个限制。
//   - EP 的 target（滚动容器选择器）在 sticky 下不需要：滚动容器由浏览器沿祖先链自动选定。
//     该 prop 仍保留（API 对齐 + 未来接监听用），以 data-affix-target 输出。

public class Affix <: Component {
    var _children: Array<IComponent>
    var _offset: Int64 = 0
    var _position: AffixPosition = AffixPosition.Fixed
    var _fromBottom: Bool = false
    var _zIndex: Int64 = 100
    var _target: String = ""
    var _style: String = ""

    public init(children: Array<IComponent>) { this._children = children }

    // EP offset：吸附时与视口（或滚动容器）边缘的距离
    public func offset(v: Int64): Affix { this._offset = v; this }
    // Fixed = sticky 吸附（默认）；Absolute = 相对已定位祖先固定，不随滚动跟随
    public func position(v: AffixPosition): Affix { this._position = v; this }
    // 吸附到容器底部而非顶部（对应 EP
    // affix 的 position="bottom"；这里 position 已被定位方式占用，故单独一个开关）
    public func bottom(): Affix { this._fromBottom = true; this }
    public func zIndex(v: Int64): Affix { this._zIndex = v; this }
    public func target(selector: String): Affix { this._target = selector; this }
    public func style(v: String): Affix { this._style = v; this }

    public func render(): IComponent {
        let attrs = HashMap<String, String>([
            ("class", "el-affix"),
            ("data-affix", "1"),
            ("data-affix-position", this._position.asClass()),
            ("style", this.rootStyle()),
        ])
        if (this._target != "") { attrs["data-affix-target"] = this._target }
        VNode("div", this._children, attrs: Some(attrs))
    }

    // 定位方式 + 吸附边 + 层级（+ 调用方样式）。未吸附时的其它表现交给业务 CSS。
    func rootStyle(): String {
        // AffixPosition.Fixed 表达的是 EP 的「吸附跟随」语义，落地方式选 sticky（见文件头说明）；
        // Absolute 则是相对已定位祖先固定，不跟随滚动。
        var out = match (this._position) {
            case AffixPosition.Fixed => "position:sticky"
            case AffixPosition.Absolute => "position:absolute"
        }
        let edge = if (this._fromBottom) { "bottom" } else { "top" }
        out = "${out};${edge}:${this._offset}px;z-index:${this._zIndex}"
        if (this._style != "") { out = "${out};${this._style}" }
        out
    }
}
