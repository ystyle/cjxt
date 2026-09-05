package cjxt

import std.collection.ArrayList
import std.convert.*

// ============ Statistic 纯逻辑（对齐 EP statistic.vue displayValue 千分位/精度格式化） ============

/**
 * 数字格式化（displayValue 语义）：
 * - 整数部分每 3 位插 groupSeparator（如 "1,234,567"；groupSeparator 为空则跳过）
 * - 小数分隔符替换为 decimalSeparator（默认 "."）
 * - precision > 0：小数固定补位/截断到 precision 位；precision == 0 保留原始小数
 * - 非数值字符串（"$12"、"12px" 等）原样返回（EP isNumber 检查）
 */
public func formatStatistic(value: String, precision: Int64, groupSeparator: String, decimalSeparator: String): String {
    let parsed = tryParseNumeric(value)
    match (parsed) {
        case None => value
        case Some(v) =>
            let parts = v.split('.')
            let intPart = parts[0]
            let decPart = if (parts.size > 1) { parts[1] } else { "" }
            let grouped = groupDigits(intPart, groupSeparator)
            if (precision > 0) {
                let dec = padTruncate(decPart, precision)
                "${grouped}${decimalSeparator}${dec}"
            } else if (decPart != "") {
                "${grouped}${decimalSeparator}${decPart}"
            } else {
                grouped
            }
    }
}

// 数值检测（整数或十进制小数，允许符号；前后空格剥离）
func tryParseNumeric(s: String): Option<String> {
    let t = trimSpaces(s)
    if (t == "") { return None }
    var i = 0
    if (t[0] == 45u8 || t[0] == 43u8) { i = 1 }
    var dotCount = 0
    if (i >= t.toArray().size) { return None }
    let bytes = t.toArray()
    var digits = 0
    while (i < bytes.size) {
        let c = bytes[i]
        if (c >= 48u8 && c <= 57u8) { digits = digits + 1 }
        else if (c == 46u8 && dotCount == 0) { dotCount = 1 }
        else { return None }
        i = i + 1
    }
    if (digits == 0) { return None }
    Some(t)
}

// 去首尾空格(字节级, AGENTS.md: String.trim 未确认)
func trimSpaces(s: String): String {
    let bytes = s.toArray()
    var start = 0
    var end = bytes.size
    while (start < end && (bytes[start] == 32u8 || bytes[start] == 9u8)) { start = start + 1 }
    while (end > start && (bytes[end - 1] == 32u8 || bytes[end - 1] == 9u8)) { end = end - 1 }
    if (start >= end) { return "" }
    // 直接切片（⚠️ StringBuilder.append(UInt8) 会把字节转成十进制文本，禁用于字符）
    s[start..end]
}

// 整数部分分组：-1234567 → -1,234,567（groupSeparator 空则原样）
func groupDigits(intPart: String, groupSeparator: String): String {
    if (groupSeparator == "") { return intPart }
    var start = 0
    if (intPart.size > 0 && (intPart[0] == 45u8 || intPart[0] == 43u8)) { start = 1 }
    let sign = if (start == 1) { intPart[0..1] } else { "" }
    let digits = intPart[start..intPart.size]
    let n = digits.size
    if (n <= 3) { return intPart }
    // String 切片逐段拼接（StrBuilder append UInt8 会把字节转成十进制文本 —— 禁用字节级）
    let sb = StringBuilder()
    var idx = 0
    while (idx < n) {
        let remaining = n - idx
        let groupSize = if (remaining % 3 == 0) { 3 } else { if (idx == 0) { remaining % 3 } else { 3 } }
        if (sb.size > 0) { sb.append(groupSeparator) }
        sb.append(digits[idx..idx + groupSize])
        idx = idx + groupSize
    }
    var result = sign
    result = result + sb.toString()
    result
}

// 小数补位/截断：dec.padEnd(precision,'0').slice(0,precision)
func padTruncate(dec: String, precision: Int64): String {
    let p = precision
    if (p <= 0) { return "" }
    let sb = StringBuilder()
    var i = 0
    while (i < p) {
        if (i < dec.size) { sb.append(dec[i..i + 1]) } else { sb.append("0") }
        i = i + 1
    }
    sb.toString()
}
