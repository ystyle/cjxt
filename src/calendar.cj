package cjxt

import std.collection.ArrayList
import std.convert.*
import std.time.DateTime

// ============ 日历纯逻辑（对齐 Element Plus date-picker 的日期计算） ============

public struct CalDate {
    public let year: Int64
    public let month: Int64   // 1-12
    public let day: Int64     // 1-31

    public init(year: Int64, month: Int64, day: Int64) {
        this.year = year
        this.month = month
        this.day = day
    }

    public func toKey(): String { formatDate(this.year, this.month, this.day) }
}

// 日历网格单元格
public struct CalCell {
    public let year: Int64
    public let month: Int64
    public let day: Int64
    public let inMonth: Bool   // 是否属于当前显示月份（否则是相邻月补位）
    public let text: Int64

    public init(year: Int64, month: Int64, day: Int64, inMonth: Bool, text: Int64) {
        this.year = year
        this.month = month
        this.day = day
        this.inMonth = inMonth
        this.text = text
    }
}

public func isLeap(year: Int64): Bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

// 某年某月天数（month: 1-12）
public func daysInMonth(year: Int64, month: Int64): Int64 {
    if (month == 2) {
        if (isLeap(year)) { 29 } else { 28 }
    } else if (month == 4 || month == 6 || month == 9 || month == 11) {
        30
    } else {
        31
    }
}

// 某年某月 1 号是星期几：0=周日 ... 6=周六（EP 默认周日起始）
public func firstWeekday(year: Int64, month: Int64): Int64 {
    let m = if (month <= 2) { month + 12 } else { month }
    let y = if (month <= 2) { year - 1 } else { year }
    let y0 = y - (14 - m) / 12
    let x = y0 + y0 / 4 - y0 / 100 + y0 / 400
    let m0 = m + 12 * ((14 - m) / 12) - 2
    (x + 31 * m0 / 12 + 1) % 7
}

// 月份加减（跨年正确处理）
public func addMonths(year: Int64, month: Int64, n: Int64): (Int64, Int64) {
    let total = year * 12 + (month - 1) + n
    (total / 12, total % 12 + 1)
}

// 1970-01-01 起的序列日数（用于日期比较/区间）
public func dateToDays(year: Int64, month: Int64, day: Int64): Int64 {
    let m = if (month <= 2) { month + 12 } else { month }
    let y = if (month <= 2) { year - 1 } else { year }
    let y0 = y + 4800 - (14 - m) / 12
    let m0 = m + 12 * ((14 - m) / 12) - 3
    y0 * 365 + y0 / 4 - y0 / 100 + y0 / 400 + (153 * m0 + 2) / 5 + day - 32045 - 2440588
}

public func compareDate(a: CalDate, b: CalDate): Int64 {
    let da = dateToDays(a.year, a.month, a.day)
    let db = dateToDays(b.year, b.month, b.day)
    if (da < db) { -1 } else if (da > db) { 1 } else { 0 }
}

// 补零两位
public func pad2(n: Int64): String {
    if (n < 10) { "0${n}" } else { n.toString() }
}

// "2026-08-20"
public func formatDate(year: Int64, month: Int64, day: Int64): String {
    "${year}-${pad2(month)}-${pad2(day)}"
}

// 解析 "2026-08-20"；非法返回 None
public func parseDate(s: String): Option<CalDate> {
    let parts = s.split("-")
    if (parts.size != 3) { return None }
    let y = try { Int64.parse(parts[0]) } catch (_) { return None }
    let m = try { Int64.parse(parts[1]) } catch (_) { return None }
    let d = try { Int64.parse(parts[2]) } catch (_) { return None }
    if (m < 1 || m > 12 || d < 1 || d > daysInMonth(y, m)) { return None }
    Some(CalDate(y, m, d))
}

// 是否今天（todayKey 由组件层用 nowDateKey() 提供，便于单测）
public func isToday(year: Int64, month: Int64, day: Int64, todayKey: String): Bool {
    formatDate(year, month, day) == todayKey
}

// 本地当前日期 key（"yyyy-MM-dd"），用于今天高亮
public func nowDateKey(): String {
    DateTime.now().format("yyyy-MM-dd")
}

// 42 格月历网格（6 行 x 7 列，周日起始），补相邻月
public func monthGrid(year: Int64, month: Int64): Array<CalCell> {
    let result = ArrayList<CalCell>()
    let dim = daysInMonth(year, month)
    let first = firstWeekday(year, month)
    let prev = addMonths(year, month, -1)
    let prevDim = daysInMonth(prev[0], prev[1])
    let next = addMonths(year, month, 1)
    for (i in 0..42) {
        if (i < first) {
            // 上月补位
            let day = prevDim - first + i + 1
            result.add(CalCell(prev[0], prev[1], day, false, day))
        } else if (i < first + dim) {
            let day = i - first + 1
            result.add(CalCell(year, month, day, true, day))
        } else {
            // 下月补位
            let day = i - first - dim + 1
            result.add(CalCell(next[0], next[1], day, false, day))
        }
    }
    result.toArray()
}
