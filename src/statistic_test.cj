package cjxt

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class StatisticLogicTest {
    @TestCase
    public func testGroupThousands(): Unit {
        @Expect(formatStatistic("1234567", 0, ",", "."), "1,234,567")
        @Expect(formatStatistic("1000000", 0, ",", "."), "1,000,000")
        @Expect(formatStatistic("1000", 0, ",", "."), "1,000")
        @Expect(formatStatistic("999", 0, ",", "."), "999")
        @Expect(formatStatistic("12", 0, ",", "."), "12")
    }

    @TestCase
    public func testNegativeAndSpaceGroup(): Unit {
        @Expect(formatStatistic("-1234567", 0, ",", "."), "-1,234,567")
        @Expect(formatStatistic("1234567", 0, " ", "."), "1 234 567")
        @Expect(formatStatistic("-1000", 0, ",", "."), "-1,000")
    }

    @TestCase
    public func testDecimal(): Unit {
        @Expect(formatStatistic("1234567.89", 2, ",", "."), "1,234,567.89")
        @Expect(formatStatistic("1234567.8", 2, ",", "."), "1,234,567.80")
        @Expect(formatStatistic("123.5", 0, ",", "."), "123.5")
        @Expect(formatStatistic("3.14159", 2, ",", "."), "3.14")
    }

    @TestCase
    public func testPrecisionTruncate(): Unit {
        @Expect(formatStatistic("3.14159", 3, ",", "."), "3.141")
        @Expect(formatStatistic("3", 2, ",", "."), "3.00")
        @Expect(formatStatistic("0.5", 1, ",", "."), "0.5")
    }

    @TestCase
    public func testDecimalSeparator(): Unit {
        @Expect(formatStatistic("1234.5", 1, ",", "，"), "1,234，5")
        @Expect(formatStatistic("1234.5", 1, ",", ","), "1,234,5")
    }

    @TestCase
    public func testNoGroup(): Unit {
        @Expect(formatStatistic("1234567", 0, "", "."), "1234567")
        @Expect(formatStatistic("1234.5", 1, "", "."), "1234.5")
    }

    @TestCase
    public func testNonNumericPassthrough(): Unit {
        @Expect(formatStatistic("$12", 0, ",", "."), "$12")
        @Expect(formatStatistic("12px", 2, ",", "."), "12px")
        @Expect(formatStatistic("", 0, ",", "."), "")
        @Expect(formatStatistic("1.2.3", 0, ",", "."), "1.2.3")
    }
}
