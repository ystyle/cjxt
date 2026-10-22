package cjxt.components

import cjxt.*
import std.collection.HashMap

// EP container 族：Container / Header / Aside / Main / Footer
// 语义标签与 class 对齐 element-plus container.vue / header.vue / aside.vue / main.vue / footer.vue
//
// Container 的方向判定（EP 的 isVertical）：
//   显式 direction 优先；否则「子节点里有 Header 或 Footer」即纵向，否则横向。
// EP 靠 vnode.type.name 判断，这里在构造期扫一遍子组件实例做同样的事。

public class Container <: Component {
    var _children: Array<IComponent>
    var _direction: ContainerDirection = ContainerDirection.Auto
    var _style: String = ""

    public init(children: Array<IComponent>) { this._children = children }

    public func direction(v: ContainerDirection): Container { this._direction = v; this }
    // 额外的内联样式（演示/业务场景做外包边等）。EP 的 Container 没有该 prop，
    // 这里按 cjxt 组件惯例提供透传入口，不改变 EP 的类名与语义。
    public func style(v: String): Container { this._style = v; this }

    public func render(): IComponent {
        var cls = "el-container"
        if (this.isVertical()) { cls = "${cls} is-vertical" }
        let attrs = HashMap<String, String>([("class", cls)])
        if (this._style != "") { attrs["style"] = this._style }
        VNode("section", this._children, attrs: Some(attrs))
    }

    // EP: direction 显式给定则以它为准；未给则看默认插槽里有没有 ElHeader / ElFooter
    func isVertical(): Bool {
        match (this._direction) {
            case Vertical => true
            case Horizontal => false
            case Auto => this.hasHeaderOrFooter()
        }
    }

    func hasHeaderOrFooter(): Bool {
        for (c in this._children) {
            match (c) {
                case _: Header => return true
                case _: Footer => return true
                case _ => ()
            }
        }
        false
    }
}

// Header / Footer 的高度通过 CSS 变量 --el-header-height / --el-footer-height 传递，
// 与 EP header.vue 的 ns.cssVarBlock({ height }) 一致（不改内联 height，保留 scss 的 padding 语义）
public class Header <: Component {
    var _children: Array<IComponent>
    var _height: String = ""
    var _style: String = ""

    public init(children: Array<IComponent>) { this._children = children }

    public func height(v: String): Header { this._height = v; this }
    public func style(v: String): Header { this._style = v; this }

    public func render(): IComponent {
        VNode("header", this._children, attrs: Some(cssVarAttrs("el-header", "--el-header-height", this._height, this._style)))
    }
}

public class Footer <: Component {
    var _children: Array<IComponent>
    var _height: String = ""
    var _style: String = ""

    public init(children: Array<IComponent>) { this._children = children }

    public func height(v: String): Footer { this._height = v; this }
    public func style(v: String): Footer { this._style = v; this }

    public func render(): IComponent {
        VNode("footer", this._children, attrs: Some(cssVarAttrs("el-footer", "--el-footer-height", this._height, this._style)))
    }
}

// Aside 的宽度走 --el-aside-width；EP aside.scss 的默认值是 var(--el-aside-width, 300px)
public class Aside <: Component {
    var _children: Array<IComponent>
    var _width: String = ""
    var _style: String = ""

    public init(children: Array<IComponent>) { this._children = children }

    public func width(v: String): Aside { this._width = v; this }
    public func style(v: String): Aside { this._style = v; this }

    public func render(): IComponent {
        VNode("aside", this._children, attrs: Some(cssVarAttrs("el-aside", "--el-aside-width", this._width, this._style)))
    }
}

public class Main <: Component {
    var _children: Array<IComponent>
    var _style: String = ""

    public init(children: Array<IComponent>) { this._children = children }

    public func style(v: String): Main { this._style = v; this }

    public func render(): IComponent {
        let attrs = HashMap<String, String>([("class", "el-main")])
        if (this._style != "") { attrs["style"] = this._style }
        VNode("main", this._children, attrs: Some(attrs))
    }
}

// 构造 root attrs：class + 可选 CSS 变量（空值时不写 style，避免 style="" 干扰 EP 的默认值）
func cssVarAttrs(cls: String, varName: String, varValue: String, extraStyle: String): HashMap<String, String> {
    let attrs = HashMap<String, String>([("class", cls)])
    var style = ""
    if (varValue != "") { style = "${varName}:${varValue}" }
    if (extraStyle != "") {
        style = if (style == "") { extraStyle } else { "${style};${extraStyle}" }
    }
    if (style != "") { attrs["style"] = style }
    attrs
}
