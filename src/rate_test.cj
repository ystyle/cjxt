package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

func assertStates(actual: ArrayList<Int64>, expected: Array<Int64>, label: String): Unit {
    if (actual.size != expected.size) {
        @Fail("${label}: size mismatch actual=${actual.size} expected=${expected.size}")
        return
    }
    for (i in 0..actual.size) {
        if (actual[i] != expected[i]) {
            @Fail("${label}: elem ${i} actual=${actual[i]} expected=${expected[i]}")
            return
        }
    }
    @Expect(true, true)
}

@Test
public class RateLogicTest {
    // ── rateStarStates ──
    @TestCase
    public func testWholeValue(): Unit {
        // 3.0 → 前 3 整星，后 2 未选（半星未开启也不影响整星判定）
        assertStates(rateStarStates(3.0, 5, false), [1, 1, 1, 0, 0], "whole")
        assertStates(rateStarStates(3.0, 5, true), [1, 1, 1, 0, 0], "whole-half")
    }

    @TestCase
    public func testHalfValue(): Unit {
        // 3.5 → 前 3 整星，第 4 半星，第 5 未选
        assertStates(rateStarStates(3.5, 5, true), [1, 1, 1, 2, 0], "half")
        // allowHalf 关闭时 3.5 按整体第 4 星未激活（EP 整星对比）
        assertStates(rateStarStates(3.5, 5, false), [1, 1, 1, 0, 0], "half-off")
    }

    @TestCase
    public func testEdgeValues(): Unit {
        assertStates(rateStarStates(0.0, 3, true), [0, 0, 0], "zero")
        assertStates(rateStarStates(5.0, 5, true), [1, 1, 1, 1, 1], "max")
        assertStates(rateStarStates(2.5, 3, true), [1, 1, 2], "two-half")
    }

    // ── rateIsHalfItem ──
    @TestCase
    public func testHalfItem(): Unit {
        @Expect(rateIsHalfItem(3.5, 4, true), true)
        @Expect(rateIsHalfItem(3.5, 5, true), false)
        @Expect(rateIsHalfItem(3.5, 3, true), false)
        @Expect(rateIsHalfItem(3.5, 4, false), false)
        @Expect(rateIsHalfItem(3.0, 4, true), false)
    }

    // ── rateValueFromClick ──
    @TestCase
    public func testClickValue(): Unit {
        @Expect(rateValueFromClick(4, false), 4.0)
        @Expect(rateValueFromClick(4, true), 3.5)
        @Expect(rateValueFromClick(1, true), 0.5)
    }

    // ── rateLabelIndex ──
    @TestCase
    public func testLabelIndex(): Unit {
        @Expect(rateLabelIndex(3.0, 3), 2)
        @Expect(rateLabelIndex(3.5, 3), 2)
        @Expect(rateLabelIndex(0.0, 3), 0)
        @Expect(rateLabelIndex(1.5, 3), 1)
        @Expect(rateLabelIndex(5.0, 3), 2)
        @Expect(rateLabelIndex(2.0, 0), 0)
    }

    // ── rateValueText ──
    @TestCase
    public func testValueText(): Unit {
        @Expect(rateValueText(3.0), "3")
        @Expect(rateValueText(3.5), "3.5")
        @Expect(rateValueText(0.5), "0.5")
    }
}
