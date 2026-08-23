package cjxt

import std.collection.HashMap

// ============ Tree 纯逻辑（展开状态 / 节点路径） ============

// 返回翻转后的展开状态副本
public func treeToggle(expanded: HashMap<String, Bool>, path: String): HashMap<String, Bool> {
    let next = HashMap<String, Bool>()
    for ((k, v) in expanded) { next[k] = v }
    let cur = match (expanded.get(path)) { case Some(v) => v case None => false }
    next[path] = !cur
    next
}

public func treeIsExpanded(expanded: HashMap<String, Bool>, path: String): Bool {
    match (expanded.get(path)) { case Some(v) => v case None => false }
}

// 子节点路径：父路径 + 索引（父路径空 → "0"；父 "0/1" → "0/1/2"）
public func treeChildPath(parent: String, idx: Int64): String {
    if (parent == "") { idx.toString() } else { "${parent}/${idx}" }
}
