package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

public class Empty <: Component {
    var _children: Array<IComponent> = []
    var _image: String = ""
    var _imageSize: String = ""
    var _description: String = ""
    var _imageSlot: Array<IComponent> = []
    var _descSlot: Array<IComponent> = []

    public init() {}
    public func children(v: Array<IComponent>): Empty { this._children = v; this }
    public func image(v: String): Empty { this._image = v; this }
    public func imageSize(v: String): Empty { this._imageSize = v; this }
    public func imageSize(v: Int64): Empty { this._imageSize = "${v}px"; this }
    public func description(v: String): Empty { this._description = v; this }
    public func slotImage(v: Array<IComponent>): Empty { this._imageSlot = v; this }
    public func slotDescription(v: Array<IComponent>): Empty { this._descSlot = v; this }

    public func render(): IComponent {
        let cls = "el-empty"

        let imageParts = ArrayList<IComponent>()
        if (this._imageSlot.size > 0) {
            imageParts.add(Fragment(this._imageSlot))
        } else if (this._image != "") {
            // EP：div.el-empty__image > img（img 无类；尺寸作用于外层 div）
            imageParts.add(VNode("img", [], attrs: Some(HashMap<String, String>([("src", this._image)]))))
        } else {
            imageParts.add(this.renderDefaultSvg())
        }
        let imageAttrs = HashMap<String, String>([("class", "el-empty__image")])
        if (this._imageSize != "") { imageAttrs["style"] = "width:${this._imageSize}" }
        let imageDiv = div(imageParts.toArray(), attrs: Some(imageAttrs))

        let descParts = ArrayList<IComponent>()
        if (this._descSlot.size > 0) {
            descParts.add(Fragment(this._descSlot))
        } else if (this._description != "") {
            descParts.add(text(this._description))
        } else {
            descParts.add(text("暂无数据"))
        }
        let descDiv = div(descParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-empty__description")])))

        let parts = ArrayList<IComponent>()
        parts.add(imageDiv)
        parts.add(descDiv)

        if (this._children.size > 0) {
            parts.add(div(this._children, attrs: Some(HashMap<String, String>([("class", "el-empty__bottom")]))))
        }

        div(parts.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
    }

    // EP 官方默认插图（img-empty.vue，逐元素翻译）。与 EP 模板的唯一差异是把 Vue 绑定落成静态标记：
    //   ① 渐变 id 逐实例唯一（EP 用 useId()，这里用组件 uid() 拼后缀）——固定 id 在同页多个 Empty 之间会撞；
    //   ② :fill/:stop-color 的 var(...) 直接写死（EP 的 ns.cssVarBlockName('fill-color-N') 拼出来就是这个名字）；
    //   ③ <use xlink:href="#path-3"> 内联成等价 <rect>，消掉一个 id 与 xlink 依赖；
    //   ④ EP 源码那个 :mask="url(#mask-4-…)" 在 defs 里并未定义（发布的 dist 里也只有引用），
    //      浏览器按"无效引用 = 不加遮罩"渲染（实测带与不带渲染一致），故不复制这个悬空引用；
    //   ⑤ 去掉 EP 里两个相互抵消的 translate 组（translate(-1268,-535) + translate(1268,535)）。
    func renderDefaultSvg(): IComponent {
        let g = "${this.uid()}"
        let svgContent = """
            <svg viewBox="0 0 79 86" version="1.1" xmlns="http://www.w3.org/2000/svg" >
              <defs>
                <linearGradient id="el-empty-g1-${g}" x1="38.8503086%" y1="0%" x2="61.1496914%" y2="100%" >
                  <stop stop-color="var(--el-empty-fill-color-1)" offset="0%" />
                  <stop stop-color="var(--el-empty-fill-color-4)" offset="100%" />
                </linearGradient>
                <linearGradient id="el-empty-g2-${g}" x1="0%" y1="9.5%" x2="100%" y2="90.5%" >
                  <stop stop-color="var(--el-empty-fill-color-1)" offset="0%" />
                  <stop stop-color="var(--el-empty-fill-color-6)" offset="100%" />
                </linearGradient>
              </defs>
              <g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
                <path d="M39.5,86 C61.3152476,86 79,83.9106622 79,81.3333333 C79,78.7560045 57.3152476,78 35.5,78 C13.6847524,78 0,78.7560045 0,81.3333333 C0,83.9106622 17.6847524,86 39.5,86 Z" fill="var(--el-empty-fill-color-3)" />
                <polygon fill="var(--el-empty-fill-color-7)" transform="translate(27.500000, 51.500000) scale(1, -1) translate(-27.500000, -51.500000) " points="13 58 53 58 42 45 2 45" />
                <g transform="translate(34.500000, 31.500000) scale(-1, 1) rotate(-25.000000) translate(-34.500000, -31.500000) translate(7.000000, 10.000000)" >
                  <polygon fill="var(--el-empty-fill-color-7)" transform="translate(11.500000, 5.000000) scale(1, -1) translate(-11.500000, -5.000000) " points="2.84078316e-14 3 18 3 23 7 5 7" />
                  <polygon fill="var(--el-empty-fill-color-5)" points="-3.69149156e-15 7 38 7 38 43 -3.69149156e-15 43" />
                  <rect fill="url(#el-empty-g1-${g})" transform="translate(46.500000, 25.000000) scale(-1, 1) translate(-46.500000, -25.000000) " x="38" y="7" width="17" height="36" />
                  <polygon fill="var(--el-empty-fill-color-2)" transform="translate(39.500000, 3.500000) scale(-1, 1) translate(-39.500000, -3.500000) " points="24 7 41 7 55 -3.63806207e-12 38 -3.63806207e-12" />
                </g>
                <rect fill="url(#el-empty-g2-${g})" x="13" y="45" width="40" height="36" />
                <g transform="translate(53.000000, 45.000000)">
                  <rect fill="var(--el-empty-fill-color-8)" transform="translate(8.500000, 18.000000) scale(-1, 1) translate(-8.500000, -18.000000) " x="0" y="0" width="17" height="36" />
                  <polygon fill="var(--el-empty-fill-color-9)" transform="translate(12.000000, 9.000000) scale(-1, 1) translate(-12.000000, -9.000000) " points="7 0 24 0 20 18 7 16.5" />
                </g>
                <polygon fill="var(--el-empty-fill-color-2)" transform="translate(66.000000, 51.500000) scale(-1, 1) translate(-66.000000, -51.500000) " points="62 45 79 45 70 58 53 58" />
              </g>
            </svg>
        """
        VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-empty__image"), ("innerHTML", svgContent)])))
    }

}
