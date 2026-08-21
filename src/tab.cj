package cjxt

import std.collection.ArrayList

// ============ Tabs 纯逻辑（便于单测） ============

// 解析当前激活标签名：active 为空或不在 pane 列表中时回退到第一个 pane
public func resolveActiveTab(active: String, names: ArrayList<String>): String {
    if (names.size == 0) { return "" }
    if (active == "") { return names[0] }
    for (n in names) {
        if (n == active) { return active }
    }
    names[0]
}
