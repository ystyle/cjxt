package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// 数组比较辅助（Float64 元素级，带相对误差）
func assertFloatList(actual: ArrayList<Float64>, expected: Array<Float64>): Unit {
    if (actual.size != expected.size) {
        @Fail("size mismatch: actual=${actual.size} expected=${expected.size}")
        return
    }
    for (i in 0..actual.size) {
        let a = actual[i]
        let e = expected[i]
        let diff = if (a > e) { a - e } else { e - a }
        if (diff > 0.000001) {
            @Fail("elem ${i}: actual=${a} expected=${e}")
            return
        }
    }
    @Expect(true, true)
}

@Test
public class SliderLogicTest {
    // ── sliderValueFromRatio ──
    @TestCase
    public func testRatioEndpoints(): Unit {
        @Expect(sliderValueFromRatio(0.0, 0, 100, 1), 0)
        @Expect(sliderValueFromRatio(1.0, 0, 100, 1), 100)
    }

    @TestCase
    public func testRatioMidpoint(): Unit {
        @Expect(sliderValueFromRatio(0.5, 0, 100, 1), 50)
    }

    @TestCase
    public func testRatioStepAlign(): Unit {
        // step=10：0.34 → 34 → round(3.4)=3 → 30；0.36 → 36 → round(3.6)=4 → 40
        @Expect(sliderValueFromRatio(0.34, 0, 100, 10), 30)
        @Expect(sliderValueFromRatio(0.36, 0, 100, 10), 40)
        // 恰好半格：round(3.5)=4（对齐 JS Math.round 的半上取整）
        @Expect(sliderValueFromRatio(0.35, 0, 100, 10), 40)
    }

    @TestCase
    public func testRatioNonZeroMin(): Unit {
        // min=20 max=80：0.5 → 50；step=15 → round((50-20)/15=2.0)=2 → 50
        @Expect(sliderValueFromRatio(0.5, 20, 80, 1), 50)
        @Expect(sliderValueFromRatio(0.5, 20, 80, 15), 50)
    }

    @TestCase
    public func testRatioClamp(): Unit {
        @Expect(sliderValueFromRatio(-0.1, 0, 100, 1), 0)
        @Expect(sliderValueFromRatio(1.2, 0, 100, 1), 100)
        @Expect(sliderValueFromRatio(9.9, 90, 100, 1), 100)
    }

    @TestCase
    public func testRatioInvalidRange(): Unit {
        @Expect(sliderValueFromRatio(0.5, 10, 10, 1), 10)
        @Expect(sliderValueFromRatio(0.5, 10, 10, 0), 10)
        @Expect(sliderValueFromRatio(0.5, 20, 10, 1), 20)
    }

    // ── sliderPercent ──
    @TestCase
    public func testPercentBasic(): Unit {
        @Expect(sliderPercent(0, 0, 100), 0.0)
        @Expect(sliderPercent(50, 0, 100), 0.5)
        @Expect(sliderPercent(100, 0, 100), 1.0)
    }

    @TestCase
    public func testPercentNonZeroMin(): Unit {
        @Expect(sliderPercent(50, 20, 80), 0.5)
        @Expect(sliderPercent(20, 20, 80), 0.0)
        @Expect(sliderPercent(80, 20, 80), 1.0)
    }

    @TestCase
    public func testPercentClamp(): Unit {
        @Expect(sliderPercent(-5, 0, 100), -0.05)
        @Expect(sliderPercent(105, 0, 100), 1.05)
    }

    @TestCase
    public func testPercentInvalidRange(): Unit {
        @Expect(sliderPercent(50, 10, 10), 0.0)
        @Expect(sliderPercent(50, 20, 10), 0.0)
    }

    // ── sliderPercentString ──
    @TestCase
    public func testPercentString() : Unit {
        @Expect(sliderPercentString(0.0), "0%")
        @Expect(sliderPercentString(0.5), "50%")
        @Expect(sliderPercentString(1.0), "100%")
    }

    @TestCase
    public func testPercentStringFraction() : Unit {
        @Expect(sliderPercentString(1.0 / 3.0), "33.33%")
        @Expect(sliderPercentString(2.0 / 3.0), "66.67%")
    }

    // ── sliderStopPercents ──
    @TestCase
    public func testStopsBasic(): Unit {
        let stops = sliderStopPercents(0, 100, 10)
        assertFloatList(stops, [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0])
    }

    @TestCase
    public func testStopsNonZeroMin(): Unit {
        // min=20 max=80 step=20：边界 20/40/60/80，EP 步宽 = 100*20/60 = 33.33%，
        // 停靠点位置 0 / 33.33% / 66.67% / 100%（stopCount=3 → 4 个）
        let stops = sliderStopPercents(20, 80, 20)
        assertFloatList(stops, [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0])
    }

    @TestCase
    public func testStopsUnixStepFloor(): Unit {
        // step=30，range=100：stopCount=3（向下取整），只到 90%
        let stops = sliderStopPercents(0, 100, 30)
        assertFloatList(stops, [0.0, 0.3, 0.6, 0.9])
    }

    @TestCase
    public func testStopsInvalid(): Unit {
        @Expect(sliderStopPercents(10, 10, 1).size, 0)
        @Expect(sliderStopPercents(0, 100, 0).size, 0)
        @Expect(sliderStopPercents(20, 10, 1).size, 0)
    }
}
