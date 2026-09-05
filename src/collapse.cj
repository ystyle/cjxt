package cjxt

import std.collection.ArrayList

// ============ Collapse 纯逻辑（对齐 EP collapse.vue activeNames 语义） ============

/**
 * 切换折叠状态：
 * - accordion 模式（单开）：点击已激活项 → 清空；否则替换为该项
 * - 普通模式（多开）：列表 toggle（EP activeNames 增删）
 * - disabled 项不参与（调用方拦截）
 */
public func collapseToggleActive(names: ArrayList<String>, name: String, accordion: Bool): ArrayList<String> {
    let result = ArrayList<String>()
    if (accordion) {
        // 单开：点击已激活 → 全部收起；否则仅保留当前项（EP accordion 语义）
        for (n in names) {
            if (n == name) { return result }
        }
        result.add(name)
        result
    } else {
        var found = false
        for (n in names) {
            if (n == name) { found = true } else { result.add(n) }
        }
        if (!found) { result.add(name) }
        result
    }
}

// 是否为激活项（accordion 与多开共用：包含即激活）
public func collapseIsActive(names: ArrayList<String>, name: String): Bool {
    for (n in names) {
        if (n == name) { return true }
    }
    false
}
