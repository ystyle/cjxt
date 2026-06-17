package cjxt.components

import cjxt.*
import std.collection.HashMap

// 按钮 type：primary / success / warning / danger / info / ""（默认）
// 按钮 size：large / small / ""（默认）
public func Button(label: String, kind!: String = "", size!: String = "", plain!: Bool = false, round!: Bool = false, circle!: Bool = false, disabled!: Bool = false, loading!: Bool = false): VNode {
    var cls = "el-button"
    if (kind != "") { cls = "${cls} el-button--${kind}" }
    if (size != "") { cls = "${cls} el-button--${size}" }
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

// 便捷函数
public func PrimaryButton(label: String): VNode {
    Button(label, kind: "primary")
}

public func DangerButton(label: String): VNode {
    Button(label, kind: "danger")
}

public func SmallButton(label: String): VNode {
    Button(label, size: "small")
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
