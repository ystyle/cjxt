package cjxt

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class VirtualWindowTest {
    @TestCase
    public func testTopOfList(): Unit {
        let w = computeVirtualWindow(1000, 0, 300, 40, 3)
        @Expect(w.startIndex, 0)
        @Expect(w.endIndex, 8 + 6) // ceil(300/40)=8 可见 + 6 buffer
        @Expect(w.topSpacer, 0)
        @Expect(w.bottomSpacer, (1000 - w.endIndex) * 40)
    }

    @TestCase
    public func testMiddle(): Unit {
        // scrollTop=2000 → 第 50 行；可见 8 行 + buffer 3
        let w = computeVirtualWindow(1000, 2000, 300, 40, 3)
        @Expect(w.startIndex, 47)
        @Expect(w.topSpacer, 47 * 40)
        @Expect(w.endIndex > 47, true)
        @Expect(w.endIndex <= 1000, true)
    }

    @TestCase
    public func testBottomClamp(): Unit {
        // 滚到接近底部：end 应被 clamp 到 total
        let w = computeVirtualWindow(100, 100 * 40 - 300, 300, 40, 3)
        @Expect(w.endIndex, 100)
        @Expect(w.bottomSpacer, 0)
        @Expect(w.startIndex > 0, true)
    }

    @TestCase
    public func testSmallListNoScroll(): Unit {
        let w = computeVirtualWindow(3, 0, 300, 40, 3)
        @Expect(w.startIndex, 0)
        @Expect(w.endIndex, 3)
        @Expect(w.topSpacer, 0)
        @Expect(w.bottomSpacer, 0)
    }

    @TestCase
    public func testEmpty(): Unit {
        let w = computeVirtualWindow(0, 100, 300, 40, 3)
        @Expect(w.startIndex, 0)
        @Expect(w.endIndex, 0)
        @Expect(w.topSpacer, 0)
        @Expect(w.bottomSpacer, 0)
    }

    @TestCase
    public func testNegativeClamp(): Unit {
        let w = computeVirtualWindow(50, -10, 300, 40, -1)
        @Expect(w.startIndex, 0)
        @Expect(w.topSpacer, 0)
    }

    @TestCase
    public func testSpacersSumToTotal(): Unit {
        // topSpacer + window + bottomSpacer 高度 = 总高度
        let w = computeVirtualWindow(500, 6000, 300, 40, 3)
        let windowH = (w.endIndex - w.startIndex) * 40
        @Expect(w.topSpacer + windowH + w.bottomSpacer, 500 * 40)
    }

    @TestCase
    public func testTotalHeight(): Unit {
        @Expect(virtualTotalHeight(100, 40), 4000)
        @Expect(virtualTotalHeight(0, 40), 0)
    }
}
