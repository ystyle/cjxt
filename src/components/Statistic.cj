package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}
import std.convert

public class Statistic <: Component {
    var _children: Array<IComponent> = []
    var _title: String = ""
    var _value: String = "0"
    var _prefix: String = ""
    var _suffix: String = ""
    var _valueStyle: String = ""
    var _precision: Int64 = 0
    var _groupSeparator: String = ","
    var _decimalSeparator: String = "."
    var _titleSlot: Array<IComponent> = []
    var _prefixSlot: Array<IComponent> = []
    var _suffixSlot: Array<IComponent> = []

    public init() {}
    public func children(v: Array<IComponent>): Statistic { this._children = v; this }
    public func title(v: String): Statistic { this._title = v; this }
    public func value(v: String): Statistic { this._value = v; this }
    public func value(v: Int64): Statistic { this._value = v.toString(); this }
    public func prefix(v: String): Statistic { this._prefix = v; this }
    public func suffix(v: String): Statistic { this._suffix = v; this }
    public func valueStyle(v: String): Statistic { this._valueStyle = v; this }
    public func precision(v: Int64): Statistic { this._precision = v; this }
    public func groupSeparator(v: String): Statistic { this._groupSeparator = v; this }
    public func decimalSeparator(v: String): Statistic { this._decimalSeparator = v; this }
    public func slotTitle(v: Array<IComponent>): Statistic { this._titleSlot = v; this }
    public func slotPrefix(v: Array<IComponent>): Statistic { this._prefixSlot = v; this }
    public func slotSuffix(v: Array<IComponent>): Statistic { this._suffixSlot = v; this }

    // EP displayValue：千分位/精度格式化（非数值原样）
    func displayValue(): String {
        formatStatistic(this._value, this._precision, this._groupSeparator, this._decimalSeparator)
    }

    public func render(): IComponent {
        let parts = ArrayList<IComponent>()

        if (this._titleSlot.size > 0) {
            parts.add(VNode("div", this._titleSlot, attrs: Some(HashMap<String, String>([("class", "el-statistic__head")]))))
        } else if (this._title != "") {
            parts.add(VNode("div", [text(this._title)], attrs: Some(HashMap<String, String>([("class", "el-statistic__head")]))))
        }

        let valueParts = ArrayList<IComponent>()
        if (this._prefixSlot.size > 0) {
            valueParts.add(VNode("span", this._prefixSlot, attrs: Some(HashMap<String, String>([("class", "el-statistic__prefix")]))))
        } else if (this._prefix != "") {
            valueParts.add(VNode("span", [text(this._prefix)], attrs: Some(HashMap<String, String>([("class", "el-statistic__prefix")]))))
        }
        valueParts.add(VNode("span", [text(this.displayValue())], attrs: Some(HashMap<String, String>([("class", "el-statistic__value")]))))
        if (this._suffixSlot.size > 0) {
            valueParts.add(VNode("span", this._suffixSlot, attrs: Some(HashMap<String, String>([("class", "el-statistic__suffix")]))))
        } else if (this._suffix != "") {
            valueParts.add(VNode("span", [text(this._suffix)], attrs: Some(HashMap<String, String>([("class", "el-statistic__suffix")]))))
        }

        let valueAttrs = HashMap<String, String>([("class", "el-statistic__content")])
        if (this._valueStyle != "") { valueAttrs["style"] = this._valueStyle }
        parts.add(VNode("div", valueParts.toArray(), attrs: Some(valueAttrs)))

        VNode("div", parts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-statistic")])))
    }
}
