package cjxt.components

import cjxt.*
import std.collection.HashMap

public class Avatar <: Component {
    var _children: Array<IComponent> = []
    var _size: String = ""
    var _shape: AvatarShape = AvatarShape.Circle
    var _icon: String = ""
    var _src: String = ""
    var _alt: String = ""
    var _srcSet: String = ""
    var _fit: AvatarFit = AvatarFit.Cover
    var _onError: Option<ActionHandler> = None
    var _hasError: Bool = false

    public init() {}
    public func children(v: Array<IComponent>): Avatar { this._children = v; this }
    public func size(v: String): Avatar { this._size = v; this }
    public func shape(v: AvatarShape): Avatar { this._shape = v; this }
    public func icon(v: String): Avatar { this._icon = v; this }
    public func src(v: String): Avatar { this._src = v; this; this._hasError = false; this }
    public func alt(v: String): Avatar { this._alt = v; this }
    public func srcSet(v: String): Avatar { this._srcSet = v; this }
    public func fit(v: AvatarFit): Avatar { this._fit = v; this }
    public func onError(h: ActionHandler): Avatar { this._onError = Some(h); this }
    public func onError(h: (ActionContext) -> Unit): Avatar {
        let wrapped: ActionHandler = { ctx => h(ctx); PatchResult.ReRender }
        this.onError(wrapped)
    }

    public func render(): IComponent {
        var cls = "el-avatar el-avatar--${this._shape.asClass()}"
        if (this._size != "") {
            if (this._size == "large" || this._size == "small") {
                cls = "${cls} el-avatar--${this._size}"
            }
        }

        let attrs = HashMap<String, String>([("class", cls)])
        if (this._size != "") {
            // EP avatar.vue：数字尺寸走 --el-avatar-size CSS 变量（avatar.scss width/height: var）
            let isNumeric = this.isNumericString(this._size)
            if (isNumeric) { attrs["style"] = "--el-avatar-size:${this._size}px" }
        }
        if (this._hasError) { this._hasError = false; attrs["class"] = "${cls} is-error" }

        let content: IComponent
        if (this._src != "" && !this._hasError) {
            let imgAttrs = HashMap<String, String>([
                ("src", this._src),
                ("style", "object-fit:${this._fit.asAttr()}")
            ])
            if (this._alt != "") { imgAttrs["alt"] = this._alt }
            if (this._srcSet != "") { imgAttrs["srcset"] = this._srcSet }
            // EP 错误回退监听原生 img error 事件 —— 服务端无法收发；
            // 不绑定 onClick（原实现语义错误：点击头像会触发 onError）
            content = VNode("img", [], attrs: Some(imgAttrs))
        } else if (this._icon != "") {
            content = Icon(this._icon).render()
        } else if (this._children.size > 0) {
            content = span(this._children)
        } else {
            content = text("")
        }

        VNode("span", [content], attrs: Some(attrs))
    }

    func isNumericString(s: String): Bool {
        if (s.size == 0) { return false }
        for (i in 0..s.size) {
            let c = s[i]
            if (c < 48 || c > 57) { return false }
        }
        true
    }
}
