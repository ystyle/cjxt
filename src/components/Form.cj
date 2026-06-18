package cjxt.components

import cjxt.*
import std.collection.{HashMap, ArrayList}

public class FormItem <: Component {
    var _children: Array<Component>
    var _label: String = ""
    var _prop: String = ""
    var _required: Bool = false
    var _error: String = ""

    public init(children: Array<Component>) { this._children = children }
    public func label(v: String): FormItem { this._label = v; this }
    public func setProp(v: String): FormItem { this._prop = v; this }
    public func required(): FormItem { this._required = true; this }
    public func error(v: String): FormItem { this._error = v; this }

    public func render(): Component {
        var cls = "el-form-item"
        if (this._error != "") { cls = "${cls} is-error" }
        if (this._required) { cls = "${cls} is-required" }
        let children = ArrayList<Component>()
        if (this._label != "") {
            children.add(VNode("label", [text(this._label)], attrs: Some(HashMap<String, String>([("class", "el-form-item__label")]))))
        }
        let contentChildren = ArrayList<Component>()
        for (c in this._children) { contentChildren.add(c) }
        if (this._error != "") {
            contentChildren.add(VNode("span", [text(this._error)], attrs: Some(HashMap<String, String>([("class", "el-form-item__error")]))))
        }
        children.add(VNode("div", contentChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-form-item__content")]))))
        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
    }
}

public class Form <: Component {
    var _children: Array<Component>

    public init(children: Array<Component>) { this._children = children }

    public func render(): Component {
        VNode("form", this._children, attrs: Some(HashMap<String, String>([("class", "el-form")])))
    }
}
