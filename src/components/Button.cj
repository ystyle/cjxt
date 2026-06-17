package cjxt.components

import cjxt.*
import std.collection.HashMap

// kind: 默认 Default，空字符串时不加 el-button-- 修饰
public func Button(label: String, kind!: ButtonKind = ButtonKind.Default, size!: ButtonSize = ButtonSize.Default, plain!: Bool = false, round!: Bool = false, circle!: Bool = false, disabled!: Bool = false, loading!: Bool = false): VNode {
    var cls = "el-button"
    let kc = kind.asClass()
    if (kc != "") { cls = "${cls} el-button--${kc}" }
    let sc = size.asClass()
    if (sc != "") { cls = "${cls} el-button--${sc}" }
    if (plain) { cls = "${cls} is-plain" }
    if (round) { cls = "${cls} is-round" }
    if (circle) { cls = "${cls} is-circle" }
    if (disabled) { cls = "${cls} is-disabled" }
    if (loading) { cls = "${cls} is-loading" }

    let attrs = HashMap<String, String>()
    attrs["class"] = cls
    if (disabled) { attrs["disabled"] = "disabled" }
    button([text(label)], attrs: Some(attrs))
}

public func PrimaryButton(label: String): VNode {
    Button(label, kind: ButtonKind.Primary)
}

public func DangerButton(label: String): VNode {
    Button(label, kind: ButtonKind.Danger)
}

public func InfoButton(label: String): VNode {
    Button(label, kind: ButtonKind.Info)
}

public func SmallButton(label: String): VNode {
    Button(label, size: ButtonSize.Small)
}

public func TextButton(label: String): VNode {
    let attrs = HashMap<String, String>()
    attrs["class"] = "el-button is-text"
    button([text(label)], attrs: Some(attrs))
}

public func LinkButton(label: String): VNode {
    let attrs = HashMap<String, String>()
    attrs["class"] = "el-button is-link"
    button([text(label)], attrs: Some(attrs))
}
