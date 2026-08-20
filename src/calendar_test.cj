package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

func assertCal(c: CalDate, y: Int64, m: Int64, d: Int64): Unit {
    @Expect(c.year, y)
    @Expect(c.month, m)
    @Expect(c.day, d)
}

@Test
public class CalendarLogicTest {
    @TestCase
    public func testIsLeap(): Unit {
        @Expect(isLeap(2024), true)
        @Expect(isLeap(2000), true)
        @Expect(isLeap(1900), false)
        @Expect(isLeap(2023), false)
    }

    @TestCase
    public func testDaysInMonth(): Unit {
        @Expect(daysInMonth(2024, 2), 29)
        @Expect(daysInMonth(2023, 2), 28)
        @Expect(daysInMonth(2026, 4), 30)
        @Expect(daysInMonth(2026, 6), 30)
        @Expect(daysInMonth(2026, 1), 31)
        @Expect(daysInMonth(2026, 12), 31)
    }

    @TestCase
    public func testFirstWeekday(): Unit {
        // 1970-01-01 是周四(4)；2024-01-01 是周一(1)；2026-08-01 是周六(6)
        @Expect(firstWeekday(1970, 1), 4)
        @Expect(firstWeekday(2024, 1), 1)
        @Expect(firstWeekday(2024, 2), 4)
        @Expect(firstWeekday(2026, 8), 6)
    }

    @TestCase
    public func testAddMonths(): Unit {
        let a = addMonths(2026, 8, 1)
        @Expect(a[0], 2026)
        @Expect(a[1], 9)
        let b = addMonths(2026, 12, 1)
        @Expect(b[0], 2027)
        @Expect(b[1], 1)
        let c = addMonths(2026, 1, -1)
        @Expect(c[0], 2025)
        @Expect(c[1], 12)
    }

    @TestCase
    public func testMonthGrid2026Aug(): Unit {
        // 2026-08：31 天，8/1 是周六(6)
        let grid = monthGrid(2026, 8)
        @Expect(grid.size, 42)
        // 前 6 格是 7 月补位
        @Expect(grid[0].inMonth, false)
        @Expect(grid[0].month, 7)
        @Expect(grid[5].inMonth, false)
        @Expect(grid[5].day, 31)
        // 第 7 格是 8 月 1 日
        @Expect(grid[6].inMonth, true)
        @Expect(grid[6].day, 1)
        @Expect(grid[6].month, 8)
        // 8 月 31 日（last inMonth cell 在 index 36）
        @Expect(grid[36].inMonth, true)
        @Expect(grid[36].day, 31)
        // 之后是 9 月补位
        @Expect(grid[37].inMonth, false)
        @Expect(grid[37].day, 1)
        @Expect(grid[37].month, 9)
        @Expect(grid[41].inMonth, false)
    }

    @TestCase
    public func testMonthGridFebLeap(): Unit {
        // 2024-02：29 天，2/1 是周四(4)
        let grid = monthGrid(2024, 2)
        @Expect(grid.size, 42)
        @Expect(grid[4].inMonth, true)
        @Expect(grid[4].day, 1)
        @Expect(grid[32].inMonth, true)
        @Expect(grid[32].day, 29)
    }

    @TestCase
    public func testFormatDate(): Unit {
        @Expect(formatDate(2026, 8, 5), "2026-08-05")
        @Expect(formatDate(2026, 12, 31), "2026-12-31")
    }

    @TestCase
    public func testPad2(): Unit {
        @Expect(pad2(5), "05")
        @Expect(pad2(12), "12")
        @Expect(pad2(0), "00")
    }

    @TestCase
    public func testParseDate(): Unit {
        match (parseDate("2026-08-05")) {
            case Some(d) => assertCal(d, 2026, 8, 5)
            case None => @Fail("expected parse")
        }
        match (parseDate("2026-13-01")) { case Some(_) => @Fail("bad month"); case None => @Expect(true, true) }
        match (parseDate("2026-02-30")) { case Some(_) => @Fail("bad day"); case None => @Expect(true, true) }
        match (parseDate("not-a-date")) { case Some(_) => @Fail("bad format"); case None => @Expect(true, true) }
    }

    @TestCase
    public func testDateToDays(): Unit {
        @Expect(dateToDays(1970, 1, 1), 0)
        @Expect(dateToDays(1970, 1, 2), 1)
        @Expect(dateToDays(2026, 8, 2) - dateToDays(2026, 8, 1), 1)
        @Expect(dateToDays(2027, 1, 1) - dateToDays(2026, 12, 31), 1)
    }

    @TestCase
    public func testCompareDate(): Unit {
        let a = CalDate(2026, 8, 5)
        let b = CalDate(2026, 8, 6)
        @Expect(compareDate(a, b), -1)
        @Expect(compareDate(b, a), 1)
        @Expect(compareDate(a, CalDate(2026, 8, 5)), 0)
        @Expect(a.toKey(), "2026-08-05")
    }

    @TestCase
    public func testIsTodayWithKey(): Unit {
        @Expect(isToday(2026, 8, 5, "2026-08-05"), true)
        @Expect(isToday(2026, 8, 6, "2026-08-05"), false)
    }
}
