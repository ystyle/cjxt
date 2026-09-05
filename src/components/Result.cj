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
        // EP 官方图标（result.ts 映射 CircleCheckFilled/CircleCloseFilled/WarningFilled/InfoFilled）
        // Icons.cj 已含官方 path 数据（info-filled/warning-filled/success-filled/circle-close）
        let iconName = match (icon) {
            case ResultIcon.Success => "success-filled"
            case ResultIcon.Error => "error-filled"
            case ResultIcon.Warning => "warning-filled"
            case _ => "info-filled"
        }
        Icon(iconName).size("64px").render()
    }
}
