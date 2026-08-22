package cjxt

// ============ 虚拟滚动纯逻辑（固定行高，服务端算可视窗口） ============

public struct VirtualWindow {
    public let startIndex: Int64 // 首行下标（含）
    public let endIndex: Int64   // 末行下标（不含，半开 [start, end)）
    public let topSpacer: Int64  // 顶部占位高度（px）
    public let bottomSpacer: Int64 // 底部占位高度（px）

    public init(startIndex: Int64, endIndex: Int64, topSpacer: Int64, bottomSpacer: Int64) {
        this.startIndex = startIndex
        this.endIndex = endIndex
        this.topSpacer = topSpacer
        this.bottomSpacer = bottomSpacer
    }
}

// 计算虚拟滚动可见窗口：滚动位置 → 只渲染 [start-buffer, start+visible+buffer] 的行
// + 顶部/底部占位保持总滚动高度。行高固定（对齐 EP VirtualList 的 itemHeight 模式）。
public func computeVirtualWindow(
    total: Int64,
    scrollTop: Int64,
    containerHeight: Int64,
    itemHeight: Int64,
    buffer: Int64
): VirtualWindow {
    if (total <= 0 || itemHeight <= 0) {
        return VirtualWindow(0, 0, 0, 0)
    }
    let containerH = if (containerHeight <= 0) { itemHeight } else { containerHeight }
    let buf = if (buffer < 0) { 0 } else { buffer }
    // 可视行数 = ceil(containerHeight / itemHeight)
    let visible = (containerH + itemHeight - 1) / itemHeight
    let scrollIdx = if (scrollTop < 0) { 0 } else { scrollTop / itemHeight }
    var start = scrollIdx - buf
    if (start < 0) { start = 0 }
    var end = start + visible + buf * 2
    if (end > total) { end = total }
    let topSpacer = start * itemHeight
    let bottomSpacer = (total - end) * itemHeight
    VirtualWindow(start, end, topSpacer, bottomSpacer)
}

// 总内容高度（滚动条用）
public func virtualTotalHeight(total: Int64, itemHeight: Int64): Int64 {
    if (total <= 0 || itemHeight <= 0) { 0 } else { total * itemHeight }
}
