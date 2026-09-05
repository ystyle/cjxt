package cjxt

// ============ Select 纯逻辑（对齐 EP useSelect 键盘高亮语义） ============

/**
 * 键盘高亮索引移动。
 * - current=-1 表示无高亮；count=可见选项数（含分组内选项，按 DOM 顺序）
 * - ArrowDown（dir=+1）：-1 → 0，之后 min(i+1, count-1)（底部 clamp，不循环，对齐 EP hoverIndex 递增 clamp）
 * - ArrowUp（dir=-1）：-1 → count-1（顶部起跳直接到底），之后 max(i-1, 0)
 * - count<=0（无可选项）恒为 -1
 */
public func selectMoveHighlight(current: Int64, count: Int64, dir: Int64): Int64 {
    if (count <= 0) { return -1 }
    if (current == -1) { return if (dir > 0) { 0 } else { count - 1 } }
    let next = current + dir
    if (next < 0) { 0 } else if (next >= count) { count - 1 } else { next }
}

/**
 * 高亮索引是否落在可见范围内（选中前校验，防越界异常）。
 */
public func selectHighlightValid(highlight: Int64, count: Int64): Bool {
    highlight >= 0 && highlight < count
}
