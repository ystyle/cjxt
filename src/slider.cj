package cjxt

import std.collection.ArrayList

// ============ Slider 纯逻辑（对齐 Element Plus slider.vue 位置/取值算法） ============

/**
 * 位置比例（0..1）→ 步进对齐后的值。
 * 语义对齐 EP 的 useSlider：value = min + round((raw - min) / step) * step，
 * raw = min + ratio * (max - min)；结果夹取到 [min, max]。
 */
public func sliderValueFromRatio(ratio: Float64, min: Int64, max: Int64, step: Int64): Int64 {
    let range = max - min
    if (range <= 0 || step <= 0) { return min }
    let r = if (ratio < 0.0) { 0.0 } else if (ratio > 1.0) { 1.0 } else { ratio }
    let raw = Float64(min) + r * Float64(range)
    let rough = Int64((raw - Float64(min)) / Float64(step) + 0.5)
    let aligned = min + rough * step
    if (aligned < min) { min } else if (aligned > max) { max } else { aligned }
}

// 值 → 位置比例（0..1）；非法范围返回 0
public func sliderPercent(value: Int64, min: Int64, max: Int64): Float64 {
    let range = max - min
    if (range <= 0) { return 0.0 }
    Float64(value - min) / Float64(range)
}

/**
 * 位置比例 → 百分数字符串（最多两位小数，如 "50%"、"33.33%"）。
 * 用于 bar/button 的 inline style，避免 Float64.toString 长小数。
 */
public func sliderPercentString(pct: Float64): String {
    let v = Int64(pct * 100.0 * 100.0 + 0.5)  // 百分数 × 100（两位小数）
    let whole = v / 100
    let frac = v % 100
    if (frac == 0) {
        "${whole}%"
    } else {
        let f = if (frac < 10) { "0${frac}" } else { "${frac}" }
        "${whole}.${f}%"
    }
}

/**
 * 步进刻度点位置比例列表（对齐 EP stops 算法）：
 * stopCount = (max - min) / step（整数向下取整），
 * stop i 位置 = i * stepWidth，其中 stepWidth = 100 * step / (max - min)。
 */
public func sliderStopPercents(min: Int64, max: Int64, step: Int64): ArrayList<Float64> {
    let res = ArrayList<Float64>()
    let range = max - min
    if (range <= 0 || step <= 0) { return res }
    let stopCount = range / step
    let stepWidth = 100.0 * Float64(step) / Float64(range)
    for (i in 0..=stopCount) {
        res.add(Float64(i) * stepWidth / 100.0)
    }
    res
}
