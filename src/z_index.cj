package cjxt

import std.sync.AtomicInt64

// 弹层 z-index 管理器（对齐 element-plus 的 useZIndex 语义）。
//
// 为什么需要：Dialog / Drawer 这类 overlay 若各自写死同一个 z-index，两层同时打开时
// 只能按 DOM 顺序叠放——「先开抽屉、再开弹窗」就会看到弹窗被抽屉盖住。element-plus 的做法
// 是模块级计数器：每次打开弹层取 nextZIndex()，基线 2000、单调递增、关闭不回退，于是
// 后打开的永远在上面，与 DOM 顺序无关。
//
// 服务端渲染不知道弹层何时关闭，也不需要：只要保证同一次请求内先后打开的层递增即可。
private let Z_INDEX_BASE: Int64 = 2000
private let zIndexSeq = AtomicInt64(0)

// 取下一个弹层层级。首次返回 2001（与组件此前写死的值一致），此后每次 +1。
public func nextZIndex(): Int64 {
    Z_INDEX_BASE + zIndexSeq.fetchAdd(1) + 1
}
