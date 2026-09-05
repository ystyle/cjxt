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

    // EP 官方默认插图（img-empty.vue 全量 path；渐变 id 固定，实例间视觉一致）
    func renderDefaultSvg(): IComponent {
        let svgContent = "<svg viewBox=\"0 0 79 86\" xmlns=\"http://www.w3.org/2000/svg\">"
            + "<defs><linearGradient id=\"el-empty-g1\" x1=\"38.8503086%\" y1=\"0%\" x2=\"61.1496914%\" y2=\"100%\">"
            + "<stop stop-color=\"var(--el-fill-color-1)\"/><stop offset=\"100%\" stop-color=\"var(--el-fill-color-4)\"/></linearGradient>"
            + "<linearGradient id=\"el-empty-g2\" x1=\"0%\" y1=\"9.5%\" x2=\"100%\" y2=\"90.5%\">"
            + "<stop stop-color=\"var(--el-fill-color-1)\"/><stop offset=\"100%\" stop-color=\"var(--el-fill-color-6)\"/></linearGradient>"
            + "<linearGradient id=\"el-empty-g3\" x1=\"12.6%\" y1=\"12.6%\" x2=\"87.4%\" y2=\"87.4%\">"
            + "<stop stop-color=\"var(--el-fill-color-1)\"/><stop offset=\"100%\" stop-color=\"var(--el-fill-color-4)\"/></linearGradient>"
            + "</defs>"
            + "<g stroke=\"none\" stroke-width=\"1\" fill=\"none\" fill-rule=\"evenodd\">"
            + "<path d=\"M39.5,86 C61.3152476,86 79,83.9106622 79,81.3333333 C79,78.7560045 57.3152476,78 35.5,78 C13.6847524,78 0,78.7560045 0,81.3333333 C0,83.9106622 17.6847524,86 39.5,86 Z\" fill=\"var(--el-fill-color-3)\"/>"
            + "<polygon fill=\"var(--el-fill-color-7)\" transform=\"translate(27.500000, 51.500000) scale(1, -1) translate(-27.500000, -51.500000)\" points=\"13 58 53 58 42 45 2 45\"/>"
            + "<polygon fill=\"var(--el-fill-color-7)\" transform=\"translate(46.000000, 36.500000) scale(1, -1) translate(-46.000000, -36.500000)\" points=\"73 26 73 47 72 47 69 29 67 28 67 26 68 26 71 29 73 26\"/>"
            + "<polygon fill=\"var(--el-fill-color-7)\" transform=\"translate(16.000000, 36.500000) scale(1, -1) translate(-16.000000, -36.500000)\" points=\"5 26 6 29 9 28 10 26 8 26 6 29 5 26\"/>"
            + "<polygon fill=\"var(--el-fill-color-5)\" points=\"1 30 22 30 22 43 1 43\"/>"
            + "<rect fill=\"url(#el-empty-g1)\" x=\"0\" y=\"12\" width=\"23\" height=\"31\"/>"
            + "<polygon fill=\"var(--el-fill-color-2)\" points=\"13 5 36 5 24 9 13 9\"/>"
            + "<polygon fill=\"var(--el-fill-color-7)\" transform=\"translate(15.000000, 36.500000) scale(1, -1) translate(-15.000000, -36.500000)\" points=\"8 26 12 27 16 26 12 27 8 26\"/>"
            + "<polygon fill=\"var(--el-fill-color-7)\" transform=\"translate(65.000000, 36.500000) scale(1, -1) translate(-65.000000, -36.500000)\" points=\"65 27 61 26 57 27 61 26 65 27\"/>"
            + "<polygon fill=\"var(--el-fill-color-7)\" transform=\"translate(43.500000, 36.500000) scale(1, -1) translate(-43.500000, -36.500000)\" points=\"40 26 43 28 46 26 43 28 40 26\"/>"
            + "<rect fill=\"url(#el-empty-g2)\" x=\"34\" y=\"9\" width=\"12\" height=\"27\"/>"
            + "<polygon fill=\"var(--el-fill-color-2)\" points=\"34 6 46 6 40 9 34 9\"/>"
            + "<polygon fill=\"var(--el-fill-color-7)\" transform=\"translate(40.000000, 22.500000) scale(1, -1) translate(-40.000000, -22.500000)\" points=\"40 14 43 17 40 21 37 17 40 14\"/>"
            + "<polygon fill=\"var(--el-fill-color-7)\" transform=\"translate(40.000000, 28.500000) scale(1, -1) translate(-40.000000, -28.500000)\" points=\"40 25 43 29 40 32 37 29 40 25\"/>"
            + "<polygon fill=\"var(--el-fill-color-5)\" transform=\"translate(33.500000, 45.500000) scale(1, -1) translate(-33.500000, -45.500000)\" points=\"28 40 39 51 28 51 28 40\"/>"
            + "<polygon fill=\"var(--el-fill-color-7)\" transform=\"translate(46.500000, 39.500000) scale(1, -1) translate(-46.500000, -39.500000)\" points=\"41 34 52 45 41 45 41 34\"/>"
            + "<rect fill=\"url(#el-empty-g3)\" x=\"54\" y=\"8\" width=\"21\" height=\"43\"/>"
            + "<polygon fill=\"var(--el-fill-color-2)\" points=\"54 4 75 4 64 8 54 8\"/>"
            + "<polygon fill=\"var(--el-fill-color-7)\" points=\"58 12 72 12 72 14 58 14\"/>"
            + "<polygon fill=\"var(--el-fill-color-7)\" points=\"58 20 72 20 72 22 58 22\"/>"
            + "</g></svg>"
        VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-empty__image"), ("innerHTML", svgContent)])))
    }
}
