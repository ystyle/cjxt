package cjxt

import std.collection.ArrayList

// ============ Rate 纯逻辑（对齐 EP rate.vue 半星/标签语义） ============

// 每颗星状态：0 未选 / 1 整星激活 / 2 半星（decimal 覆盖）
public func rateStarStates(value: Float64, max: Int64, allowHalf: Bool): ArrayList<Int64> {
    let res = ArrayList<Int64>()
    var idx: Int64 = 1
    while (idx <= max) {
        if (Float64(idx) <= value) {
            res.add(1)
        } else if (allowHalf && ceilValue(value) == Float64(idx) && value > 0.0) {
            res.add(2)
        } else {
            res.add(0)
        }
        idx = idx + 1
    }
    res
}

// 半星判定（showDecimalIcon：item == Math.ceil(value) 且值非整数）
public func rateIsHalfItem(value: Float64, idx: Int64, allowHalf: Bool): Bool {
    allowHalf && value > 0.0 && ceilValue(value) == Float64(idx) && value != Float64(idx)
}

// 点击值：half=true → idx-0.5，否则 idx；负值夹取 0
public func rateValueFromClick(idx: Int64, half: Bool): Float64 {
    if (half) {
        let v = Float64(idx) - 0.5
        if (v < 0.0) { 0.0 } else { v }
    } else {
        Float64(idx)
    }
}

// 文本标签索引（EP labelIdx = Math.ceil(value) - 1；越界回退 0）
public func rateLabelIndex(value: Float64, textsSize: Int64): Int64 {
    if (textsSize <= 0) { return 0 }
    let c = ceilValue(value)
    let idx = Int64(c) - 1
    if (idx < 0) { 0 } else if (idx >= textsSize) { textsSize - 1 } else { idx }
}

// 展示字符串：整数值不带 .0（"3"），半星 "3.5"（Float64.toString 会出 6 位小数）
public func rateValueText(value: Float64): String {
    let whole = Int64(value)
    if (Float64(whole) == value) { return whole.toString() }
    let frac = value - Float64(whole)
    if (frac == 0.5) { "${whole}.5" } else { value.toString() }
}

// 向上取整（正数）
func ceilValue(v: Float64): Float64 {
    let whole = Int64(v)
    if (Float64(whole) >= v) { Float64(whole) } else { Float64(whole + 1) }
}
