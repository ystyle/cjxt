package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

// EP config-provider：`config-provider.vue` 的模板只是一个 renderSlot（不输出任何元素），
// 配置通过 Vue 的 provide/inject 向下传递（`hooks/use-global-config.ts`）。
//
// cjxt 是服务端驱动渲染，没有 provide/inject 通道：树在服务端一次性算好，
// 组件看不到祖先的上下文。因此这里改用 **CSS 变量的继承** 作为等价通道——
// 它同样「向下生效且不影响兄弟」，是当前架构里唯一真实可用的机制。
//
// 因此本组件必然多出一个 EP 没有的包裹元素 `.el-config-provider`。
// 这是刻意的架构适配，不是对齐疏漏：没有包裹元素就没地方挂 CSS 变量。
//
// size 语义（EP `useSizeProp` 的 large/default/small）落成 `--el-component-size`：
// 主题变量表里 `--el-component-size` 的默认值是 32px，`input.scss` 里
// `.el-input { --el-input-height: var(--el-component-size) }` 等规则直接消费它，
// 所以在包裹层改写这个变量，子树里默认尺寸的组件会整体换高——与 EP 的「全局 size」同效。
// 注意与 EP 的差异：EP 是给每个子组件加 `el-xxx--large/--small` 修饰类，
// 那需要遍历子树并按各组件自己的 size 枚举逐个改写（各组件 size 类型并不统一：
// ButtonSize / TagSize / ComponentSize…），在服务端做等价于把子组件全部重写一遍。
// 故 large/small 走「改写默认高度」这条路：视觉结果一致，类名不对齐，已在此说明。
public class ConfigProvider <: Component {
    var _children: Array<IComponent>
    var _size: Option<ComponentSize> = None
    var _zIndex: Int64 = 0
    var _style: String = ""
    // 额外的主题变量（如 --el-color-primary），按插入顺序落地
    var _cssVars: ArrayList<(String, String)> = ArrayList<(String, String)>()

    public init(children: Array<IComponent>) { this._children = children }

    public func size(v: ComponentSize): ConfigProvider { this._size = Some(v); this }
    // 弹层初始 z-index（EP 的 configProvider.zIndex，默认 2000）。0 = 不注入，沿用主题变量。
    public func zIndex(v: Int64): ConfigProvider { this._zIndex = v; this }
    public func style(v: String): ConfigProvider { this._style = v; this }
    // 覆盖任意主题变量：name 可写 "color-primary" 或 "--el-color-primary"，统一补 `--el-` 前缀
    public func cssVar(name: String, value: String): ConfigProvider {
        this._cssVars.add((name, value))
        this
    }

    public func render(): IComponent {
        let attrs = HashMap<String, String>([("class", "el-config-provider")])
        let style = this.buildStyle()
        if (style != "") { attrs["style"] = style }
        VNode("div", this._children, attrs: Some(attrs))
    }

    func buildStyle(): String {
        let parts = ArrayList<String>()
        match (this._size) {
            case Some(s) => parts.add("--el-component-size:${sizeToPx(s)}")
            case None => ()
        }
        if (this._zIndex > 0) {
            // EP 的 zIndex 是「弹层初始层级」，主题里对应 --el-index-popper（默认 2000）
            parts.add("--el-index-popper:${this._zIndex}")
        }
        for ((k, v) in this._cssVars) {
            let name = if (k.startsWith("--")) { k } else { "--el-${k}" }
            parts.add("${name}:${v}")
        }
        if (this._style != "") { parts.add(this._style) }
        joinStyleParts(parts)
    }
}

// 各 size 对应的组件高度，取自主题变量表的默认值
// （`--el-component-size-large: 40px` / `--el-component-size: 32px` / `--el-component-size-small: 24px`）
func sizeToPx(s: ComponentSize): String {
    match (s) {
        case Large => "40px"
        case Default => "32px"
        case Small => "24px"
    }
}

// 用分号连接非空片段；全空时返回 ""（调用方据此不写 style 属性）
func joinStyleParts(parts: ArrayList<String>): String {
    var out = ""
    for (p in parts) {
        if (p == "") { continue }
        let t = p.trimAscii()
        if (t == "") { continue }
        if (out != "") { out = "${out};" }
        out = "${out}${t}"
    }
    out
}
