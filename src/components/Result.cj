package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class Result <: Component {
    var _children: Array<IComponent> = []
    var _title: String = ""
    var _subTitle: String = ""
    var _icon: ResultIcon = ResultIcon.Info
    var _iconSlot: Array<IComponent> = []
    var _titleSlot: Array<IComponent> = []
    var _subTitleSlot: Array<IComponent> = []

    public init() {}
    public func children(v: Array<IComponent>): Result { this._children = v; this }
    public func title(v: String): Result { this._title = v; this }
    public func subTitle(v: String): Result { this._subTitle = v; this }
    public func icon(v: ResultIcon): Result { this._icon = v; this }
    public func slotIcon(v: Array<IComponent>): Result { this._iconSlot = v; this }
    public func slotTitle(v: Array<IComponent>): Result { this._titleSlot = v; this }
    public func slotSubTitle(v: Array<IComponent>): Result { this._subTitleSlot = v; this }

    public func render(): IComponent {
        let parts = ArrayList<IComponent>()

        // Icon
        if (this._iconSlot.size > 0) {
            parts.add(VNode("div", this._iconSlot, attrs: Some(HashMap<String, String>([("class", "el-result__icon")]))))
        } else {
            let iconCls = "el-result__icon ${this._icon.asClass()}"
            parts.add(VNode("div", [this.renderSvgIcon(this._icon)], attrs: Some(HashMap<String, String>([("class", iconCls)]))))
        }

        // Title
        if (this._titleSlot.size > 0) {
            parts.add(VNode("div", this._titleSlot, attrs: Some(HashMap<String, String>([("class", "el-result__title")]))))
        } else if (this._title != "") {
            parts.add(VNode("div", [VNode("p", [text(this._title)])], attrs: Some(HashMap<String, String>([("class", "el-result__title")]))))
        }

        // Sub title
        if (this._subTitleSlot.size > 0) {
            parts.add(VNode("div", this._subTitleSlot, attrs: Some(HashMap<String, String>([("class", "el-result__subtitle")]))))
        } else if (this._subTitle != "") {
            parts.add(VNode("div", [VNode("p", [text(this._subTitle)])], attrs: Some(HashMap<String, String>([("class", "el-result__subtitle")]))))
        }

        // Extra (children / default slot)
        if (this._children.size > 0) {
            parts.add(VNode("div", this._children, attrs: Some(HashMap<String, String>([("class", "el-result__extra")]))))
        }

        VNode("div", parts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-result")])))
    }

    func renderSvgIcon(icon: ResultIcon): IComponent {
        let iconSvg: String
        match (icon) {
            case ResultIcon.Success =>
                iconSvg = "<svg viewBox=\"0 0 48 48\" xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M24 4a20 20 0 100 40 20 20 0 000-40\" fill=\"currentColor\"/><path d=\"M22 32.2l-8-8 2.8-2.8L22 26.5l10.2-10.2L35 19l-13 13.2z\" fill=\"#fff\"/></svg>"
            case ResultIcon.Warning =>
                iconSvg = "<svg viewBox=\"0 0 48 48\" xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M24 4L2 42h44L24 4zm0 6.2L38.5 38H9.5L24 10.2z\" fill=\"currentColor\"/><path d=\"M22 22v8h4v-8h-4zm0 12v4h4v-4h-4z\" fill=\"#fff\"/></svg>"
            case ResultIcon.Error =>
                iconSvg = "<svg viewBox=\"0 0 48 48\" xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M24 4a20 20 0 100 40 20 20 0 000-40\" fill=\"currentColor\"/><path d=\"M32.5 31.5L28.3 27l4.2-4.5L30 21l-6 6.3-6-6.3-2.5 2.5 4.2 4.5-4.2 4.5 2.5 2.5 6-6.3 6 6.3 2.5-2.5z\" fill=\"#fff\"/></svg>"
            case _ => // Primary or Info
                iconSvg = "<svg viewBox=\"0 0 48 48\" xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M24 4a20 20 0 100 40 20 20 0 000-40\" fill=\"currentColor\"/><path d=\"M24 13a2.5 2.5 0 110 5 2.5 2.5 0 010-5zm-4 10h8v16h-8V23z\" fill=\"#fff\"/></svg>"
        }
        VNode("div", [], attrs: Some(HashMap<String, String>([("innerHTML", iconSvg)])))
    }
}
