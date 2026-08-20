package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// 纯逻辑辅助：数组比较（元素级）
func assertPages(actual: Array<Int64>, expected: Array<Int64>): Unit {
    if (actual.size != expected.size) {
        @Fail("size mismatch: actual=${actual.size} expected=${expected.size}")
        return
    }
    for (i in 0..actual.size) {
        if (actual[i] != expected[i]) {
            @Fail("elem ${i}: actual=${actual[i]} expected=${expected[i]}")
            return
        }
    }
    @Expect(true, true)
}

@Test
public class PaginationLogicTest {
    // ── computePageCount ──
    @TestCase
    public func testPageCountExact(): Unit {
        @Expect(computePageCount(100, 10), 10)
    }

    @TestCase
    public func testPageCountCeil(): Unit {
        @Expect(computePageCount(95, 10), 10)
        @Expect(computePageCount(101, 10), 11)
        @Expect(computePageCount(105, 20), 6)
    }

    @TestCase
    public func testPageCountEdge(): Unit {
        @Expect(computePageCount(0, 10), 1)
        @Expect(computePageCount(10, 0), 1)
        @Expect(computePageCount(5, 10), 1)
    }

    // ── computePager（对齐 EP pager.vue 算法，pagerCount=7）──
    @TestCase
    public func testPagerFewerThanPagerCount(): Unit {
        // pageCount=3 <= pagerCount：无省略号，中间页 [2]
        let info = computePager(2, 3, 7)
        @Expect(info.showPrevMore, false)
        @Expect(info.showNextMore, false)
        assertPages(info.pages, [2])
    }

    @TestCase
    public func testPagerPageCountTwo(): Unit {
        // pageCount=2：中间页为空，首尾页单独渲染
        let info = computePager(1, 2, 7)
        @Expect(info.showPrevMore, false)
        @Expect(info.showNextMore, false)
        assertPages(info.pages, [])
    }

    @TestCase
    public func testPagerFirstPage(): Unit {
        // pageCount=10, cp=1：showNextMore=true，中间页 [2..6]
        let info = computePager(1, 10, 7)
        @Expect(info.showPrevMore, false)
        @Expect(info.showNextMore, true)
        assertPages(info.pages, [2, 3, 4, 5, 6])
    }

    @TestCase
    public func testPagerMiddlePage(): Unit {
        // pageCount=10, cp=5：双向省略，中间页 [cp-2..cp+2]
        let info = computePager(5, 10, 7)
        @Expect(info.showPrevMore, true)
        @Expect(info.showNextMore, true)
        assertPages(info.pages, [3, 4, 5, 6, 7])
    }

    @TestCase
    public func testPagerNearLast(): Unit {
        // pageCount=10, cp=8：showNextMore=false，中间页从 pageCount-(pagerCount-2)=5 到 9
        let info = computePager(8, 10, 7)
        @Expect(info.showPrevMore, true)
        @Expect(info.showNextMore, false)
        assertPages(info.pages, [5, 6, 7, 8, 9])
    }

    @TestCase
    public func testPagerLastPage(): Unit {
        let info = computePager(10, 10, 7)
        @Expect(info.showPrevMore, true)
        @Expect(info.showNextMore, false)
        assertPages(info.pages, [5, 6, 7, 8, 9])
    }

    // ── 边界：currentPage 越界 → clamp ──
    @TestCase
    public func testClampPage(): Unit {
        @Expect(clampPage(0, 5), 1)
        @Expect(clampPage(6, 5), 5)
        @Expect(clampPage(3, 5), 3)
        @Expect(clampPage(1, 1), 1)
    }
}
