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
    public func description(v: String): Empty { this._description = v; this }
    public func slotImage(v: Array<IComponent>): Empty { this._imageSlot = v; this }
    public func slotDescription(v: Array<IComponent>): Empty { this._descSlot = v; this }

    public func render(): IComponent {
        let cls = "el-empty"

        let imageParts = ArrayList<IComponent>()
        if (this._imageSlot.size > 0) {
            imageParts.add(Fragment(this._imageSlot))
        } else if (this._image != "") {
            let imgAttrs = HashMap<String, String>([("class", "el-empty__image"), ("src", this._image)])
            if (this._imageSize != "") { imgAttrs["style"] = "width:${this._imageSize}" }
            imageParts.add(VNode("img", [], attrs: Some(imgAttrs)))
        } else {
            imageParts.add(this.renderDefaultSvg())
        }
        let imageDiv = div(imageParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-empty__image")])))

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

    func renderDefaultSvg(): IComponent {
        // EP empty state default SVG
        let svgContent = "<svg class=\"el-empty__image\" viewBox=\"0 0 79 86\" xmlns=\"http://www.w3.org/2000/svg\"><defs><linearGradient id=\"a\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\"><stop offset=\"0%\" stop-color=\"#FFF\"/><stop offset=\"100%\" stop-color=\"#F0F5FF\"/></linearGradient></defs><ellipse cx=\"39.5\" cy=\"43\" rx=\"39.5\" ry=\"43\" fill=\"url(#a)\" opacity=\".8\"/><path d=\"M31.2 27.1c.6-1 1.3-2.6 2.1-5.8.4-1.5 2-5.5 6.1-5.5h7.6c4.7 0 5.8 3.7 6.4 5.7.7 2.3 1.4 4.4 2.4 5.6h-24.6z\" fill=\"#D5E4FF\"/><path d=\"M55 31.5H25.1c-5.3 0-8.1-1.8-14.2-3.8 2.7 21.5 4.6 34.2 5.6 38.2 1 4 5.3 6.2 10.1 6.2h27.4c4.8 0 9.3-2.2 10.2-6.2 1-4 2.9-16.7 5.6-38.2-6.1 2-8.9 3.8-14.2 3.8z\" fill=\"#EFF5FF\"/><path d=\"M64.6 71.2c1.7 0 3.1-1.3 3.1-2.9 0-1.6-1.4-2.9-3.1-2.9H15.4c-1.7 0-3.1 1.3-3.1 2.9 0 1.6 1.4 2.9 3.1 2.9h49.2z\" fill=\"#D5E4FF\"/></svg>"
        VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-empty__image"), ("innerHTML", svgContent)])))
    }
}
