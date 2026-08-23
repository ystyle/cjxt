package cjxt

import std.collection.{ArrayList, HashMap}

// ============ Cascader 纯逻辑（级联选项树 / 路径解析） ============

public class CascaderNode {
    public let label: String
    public let value: String
    public let children: ArrayList<CascaderNode>

    public init(label: String, value: String) {
        this.label = label
        this.value = value
        this.children = ArrayList<CascaderNode>()
    }

    public init(label: String, value: String, children: ArrayList<CascaderNode>) {
        this.label = label
        this.value = value
        this.children = children
    }

    public func isLeaf(): Bool { this.children.size == 0 }
}

// 根据 activePath 的值序列，解析出每层要显示的节点列。
// 返回 [[根节点...], [第二层节点...], ...]；activePath 走到的层才有后续列。
public func cascaderColumns(options: ArrayList<CascaderNode>, activePath: ArrayList<String>): ArrayList<ArrayList<CascaderNode>> {
    let columns = ArrayList<ArrayList<CascaderNode>>()
    columns.add(options)
    var current = options
    for (v in activePath) {
        var nextLevel = ArrayList<CascaderNode>()
        var found = false
        for (n in current) {
            if (n.value == v) {
                nextLevel = n.children
                found = true
                break
            }
        }
        if (!found) { break }
        columns.add(nextLevel)
        current = nextLevel
    }
    columns
}

// 选中值序列 → 各层 label（用于输入框显示，如 浙江/杭州/西湖区）
public func cascaderPathLabels(options: ArrayList<CascaderNode>, selected: ArrayList<String>): ArrayList<String> {
    let labels = ArrayList<String>()
    var current = options
    for (v in selected) {
        var matched = false
        for (n in current) {
            if (n.value == v) {
                labels.add(n.label)
                current = n.children
                matched = true
                break
            }
        }
        if (!matched) { break }
    }
    labels
}

// activePath 追加一层（父节点点击）
public func cascaderAppend(path: ArrayList<String>, v: String): ArrayList<String> {
    let next = ArrayList<String>()
    for (p in path) { next.add(p) }
    next.add(v)
    next
}
