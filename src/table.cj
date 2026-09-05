package cjxt

import std.convert.*

// ============ Table 纯逻辑（对齐 EP table 排序/固定列布局语义） ============

/**
 * 单元格值比较：数值感知（"2" < "10"，旧实现字典序 2 > 10）。
 * - 双方都是整数 → 数值比较；全是数字的列（主键/序号/金额整数）不再按字典序
 * - 其余（含浮点/日期 "yyyy-MM-dd" 自然序即可）→ 字符串比较
 */
public func compareCellValues(a: String, b: String): Int64 {
    if (a == b) { return 0 }
    let na = tryParseInt(a)
    let nb = tryParseInt(b)
    match (na) {
        case Some(fa) =>
            match (nb) {
                case Some(fb) => if (fa < fb) { -1 } else if (fa > fb) { 1 } else { 0 }
                case None => compareStr2(a, b)
            }
        case None => compareStr2(a, b)
    }
}

func compareStr2(a: String, b: String): Int64 {
    if (a < b) { -1 }
    else if (a > b) { 1 }
    else { 0 }
}

func tryParseInt(s: String): Option<Int64> {
    if (s == "") { return None }
    try {
        Some(Int64.parse(s))
    } catch (e: Exception) {
        None
    }
}

/**
 * 固定列计算：第 idx 列（-1 右列场景由调用方传 right=true）的 sticky 偏移。
 * left 模式：左侧所有固定列宽度之和（EP getFixedColumnOffset 同类语义）。
 * 旧实现所有 fixed 列都 left:0/right:0，多固定列会重叠。
 */
public func tableFixedOffset(widths: Array<Int64>, idx: Int64, right: Bool): Int64 {
    var off: Int64 = 0
    if (right) {
        var i: Int64 = widths.size - 1
        while (i > idx) {
            off += widths[i]
            i--
        }
        off
    } else {
        var j: Int64 = 0
        while (j < idx) {
            off += widths[j]
            j++
        }
        off
    }
}
