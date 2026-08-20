package cjxt

import std.collection.ArrayList

// ============ Toast 队列纯逻辑（Message / Notification 共用，便于单测） ============

var _toastId = [0]

// 单调递增的 toast id（模块级共享，避免队列实例随组件重渲染重建导致 id 冲突）
public func nextToastId(): Int64 {
    _toastId[0] += 1
    _toastId[0]
}

// 追加一条（返回新列表，不修改入参）
public func toastPush<T>(list: ArrayList<T>, item: T): ArrayList<T> {
    let c = ArrayList<T>(list)
    c.add(item)
    c
}

// 按下标移除（返回新列表；越界时原样返回副本）
public func toastRemoveAt<T>(list: ArrayList<T>, index: Int64): ArrayList<T> {
    let c = ArrayList<T>(list)
    if (index >= 0 && index < c.size) { c.remove(index..index + 1) }
    c
}
