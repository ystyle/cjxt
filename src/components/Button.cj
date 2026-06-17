package cjxt.components

import cjxt.*
import std.collection.HashMap

public func Button(label: String, typ: String, size: String, round: Bool, disabled: Bool): ComponentNode {
    var clsStr = "el-button el-button--${typ}"
    if (size != "default") { clsStr = "${clsStr} el-button--${size}" }
    if (round) { clsStr = "${clsStr} is-round" }
    if (disabled) { clsStr = "${clsStr} is-disabled" }
    let attrs = HashMap<String, String>()
    attrs["class"] = clsStr
    if (disabled) { attrs["disabled"] = "disabled" }
    button([text(label)], attrs: Some(attrs))
}

public func PrimaryButton(label: String): ComponentNode {
    Button(label, "primary", "default", false, false)
}

public func SmallButton(label: String): ComponentNode {
    Button(label, "default", "small", false, false)
}
