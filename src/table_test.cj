package cjxt

import std.unittest.*
import std.unittest.testmacro.*

func assertCmp(actual: Int64, expected: Int64, label: String, a: String, b: String): Unit {
    if (actual != expected) {
        @Fail("${label}: compare(${a}, ${b}) = ${actual}, expected ${expected}")
        return
    }
    @Expect(true, true)
}

@Test
public class TableLogicTest {
    // ── compareCellValues：数值感知 ──
    @TestCase
    public func testNumericOrder(): Unit {
        // 旧字典序 "2" > "10"——数值列排序必须 2 在 10 前
        assertCmp(compareCellValues("2", "10"), -1, "numeric", "2", "10")
        assertCmp(compareCellValues("10", "2"), 1, "numeric-rev", "10", "2")
        assertCmp(compareCellValues("10", "10"), 0, "equal", "10", "10")
    }

    @TestCase
    public func testNumericNegativeAndZero(): Unit {
        assertCmp(compareCellValues("-5", "3"), -1, "neg", "-5", "3")
        assertCmp(compareCellValues("0", "0"), 0, "zero", "0", "0")
        assertCmp(compareCellValues("100", "99"), 1, "hundred", "100", "99")
    }

    @TestCase
    public func testDateStringNaturalOrder(): Unit {
        // yyyy-MM-dd 字符串序 = 日期序
        assertCmp(compareCellValues("2016-05-01", "2016-05-02"), -1, "date", "a", "b")
        assertCmp(compareCellValues("2016-05-02", "2016-05-01"), 1, "date-rev", "a", "b")
        assertCmp(compareCellValues("2016-05-03", "2016-05-03"), 0, "date-eq", "a", "b")
    }

    @TestCase
    public func testTextOrder(): Unit {
        assertCmp(compareCellValues("Alice", "Bob"), -1, "text", "a", "b")
        assertCmp(compareCellValues("California", "Texas"), -1, "text-state", "a", "b")
    }

    @TestCase
    public func testMixedNumericText(): Unit {
        // 一方数值一方文本 → 字符串序（不抛异常）
        assertCmp(compareCellValues("5", "Alice"), -1, "mixed-num-first", "5", "Alice")
        assertCmp(compareCellValues("Alice", "5"), 1, "mixed-text-first", "Alice", "5")
    }

    @TestCase
    public func testEmptyString(): Unit {
        assertCmp(compareCellValues("", "3"), -1, "empty", "", "3")
        assertCmp(compareCellValues("3", ""), 1, "empty-rev", "3", "")
        assertCmp(compareCellValues("", ""), 0, "empty-eq", "", "")
    }

    // ── tableFixedOffset ──
    @TestCase
    public func testFixedLeftOffsets(): Unit {
        let widths: Array<Int64> = [100, 80, 200, 120]
        @Expect(tableFixedOffset(widths, 0, false), 0)
        @Expect(tableFixedOffset(widths, 1, false), 100)
        @Expect(tableFixedOffset(widths, 2, false), 180)
        @Expect(tableFixedOffset(widths, 3, false), 380)
    }

    @TestCase
    public func testFixedRightOffsets(): Unit {
        let widths: Array<Int64> = [100, 80, 200, 120]
        @Expect(tableFixedOffset(widths, 3, true), 0)
        @Expect(tableFixedOffset(widths, 2, true), 120)
        @Expect(tableFixedOffset(widths, 1, true), 320)
        @Expect(tableFixedOffset(widths, 0, true), 400)
    }

    @TestCase
    public func testFixedSingleColumn(): Unit {
        let widths: Array<Int64> = [300]
        @Expect(tableFixedOffset(widths, 0, false), 0)
        @Expect(tableFixedOffset(widths, 0, true), 0)
    }

    @TestCase
    public func testFixedEmpty(): Unit {
        let widths: Array<Int64> = []
        @Expect(tableFixedOffset(widths, 0, false), 0)
        @Expect(tableFixedOffset(widths, 0, true), 0)
    }
}
