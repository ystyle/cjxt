package cjxt.components

import cjxt.*
import std.regex.*
import std.collection.{HashMap, ArrayList}

public struct FormRule {
    var required: Bool = false
    var message: String = ""
    var min: Int64 = 0
    var max: Int64 = 0
    var pattern: String = ""

    public init(required!: Bool = false, message!: String = "", min!: Int64 = 0, max!: Int64 = 0, pattern!: String = "") {
        this.required = required
        this.message = message
        this.min = min
        this.max = max
        this.pattern = pattern
    }

    public func check(value: String): String {
        if (this.required && value == "") {
            return if (this.message != "") { this.message } else { "此项为必填" }
        }
        if (value == "") { return "" }
        if (this.min > 0 && value.size < this.min) {
            return if (this.message != "") { this.message } else { "最少${this.min}个字符" }
        }
        if (this.max > 0 && value.size > this.max) {
            return if (this.message != "") { this.message } else { "最多${this.max}个字符" }
        }
        if (this.pattern != "") {
            let re = Regex(this.pattern)
            match (re.find(value)) {
                case Some(_) => ()
                case None => return if (this.message != "") { this.message } else { "格式不正确" }
            }
        }
        ""
    }
}

public class FormItem <: Component {
    var _children: Array<IComponent>
    var _label: String = ""
    var _prop: String = ""
    var _required: Bool = false
    var _error: String = ""
    var _valid: Bool = false
    var _rules: ArrayList<FormRule> = ArrayList<FormRule>()
    var _getValue: Option<() -> String> = None
    var _errorSignal: Option<Signal<String>> = None
    var _validSignal: Option<Signal<Bool>> = None

    public init(children: Array<IComponent>) { this._children = children }
    public func label(v: String): FormItem { this._label = v; this }
    public func setProp(v: String): FormItem { this._prop = v; this }
    public func required(): FormItem { this._required = true; this }
    public func error(v: String): FormItem { this._error = v; this }
    public func rule(r: FormRule): FormItem { this._rules.add(r); if (r.required) { this._required = true }; this }
    public func errorSignal(signal: Signal<String>): FormItem { this._errorSignal = Some(signal); this }

    public func bind(signal: Signal<String>): FormItem {
        let s = signal
        this._getValue = Some({ => s.get() })
        this
    }

    public func validate(): Bool {
        let value = match (this._getValue) {
            case Some(fn) => fn()
            case None => ""
        }
        for (rule in this._rules) {
            let err = rule.check(value)
            if (err != "") {
                this.setError(err)
                this._valid = false
                return false
            }
        }
        this.setError("")
        this._valid = true
        true
    }

    public func clearValidate(): Unit {
        this.setError("")
        this._valid = false
    }

    func setError(v: String): Unit {
        this._error = v
        match (this._errorSignal) {
            case Some(s) => s.set(v)
            case None => ()
        }
    }

    public func render(): IComponent {
        let currentError = match (this._errorSignal) {
            case Some(s) => s.get()
            case None => this._error
        }
        var cls = "el-form-item"
        if (currentError != "") { cls = "${cls} is-error" } else if (this._valid) { cls = "${cls} is-success" }
        if (this._required) { cls = "${cls} is-required" }
        let children = ArrayList<IComponent>()
        if (this._label != "") {
            children.add(VNode("label", [text(this._label)], attrs: Some(HashMap<String, String>([("class", "el-form-item__label")]))))
        }
        let contentChildren = ArrayList<IComponent>()
        for (c in this._children) { contentChildren.add(c) }
        if (currentError != "") {
            contentChildren.add(VNode("span", [text(currentError)], attrs: Some(HashMap<String, String>([("class", "el-form-item__error")]))))
        }
        children.add(VNode("div", contentChildren.toArray(), attrs: Some(HashMap<String, String>([("class", "el-form-item__content")]))))
        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", cls)])))
    }
}

public class Form <: Component {
    var _children: Array<IComponent>
    var _items: ArrayList<FormItem>

    public init(children: Array<IComponent>) {
        this._children = children
        this._items = ArrayList<FormItem>()
        for (c in children) {
            if (c is FormItem) {
                match (c as FormItem) {
                    case Some(actual) => this._items.add(actual)
                    case None => ()
                }
            }
        }
    }

    public func add(item: FormItem): Form {
        this._items.add(item)
        let newChildren = ArrayList<IComponent>()
        for (ch in this._children) { newChildren.add(ch) }
        newChildren.add(item)
        this._children = newChildren.toArray()
        this
    }

    public func validate(): Bool {
        var ok = true
        for (item in this._items) {
            if (!item.validate()) { ok = false }
        }
        ok
    }

    public func clearValidate(): Unit {
        for (item in this._items) {
            item.clearValidate()
        }
    }

    public func render(): IComponent {
        VNode("form", this._children, attrs: Some(HashMap<String, String>([("class", "el-form")])))
    }
}
