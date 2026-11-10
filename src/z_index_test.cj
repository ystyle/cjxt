// 弹层层级管理器（对齐 element-plus 的 useZIndex）：后打开的弹层必须叠在先打开的之上。
//
// 回归背景：Dialog 与 Drawer 原先都写死 inline z-index:2001，两层同开时只能按 DOM
// 顺序叠放 —— 「先开抽屉、再开弹窗」会看到弹窗被抽屉盖住。这里钉住管理器本身。
package cjxt

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class ZIndexTest {
    @TestCase
    func testNextZIndexIsMonotonic(): Unit {
        let a = nextZIndex()
        let b = nextZIndex()
        let c = nextZIndex()
        @Assert(b > a)
        @Assert(c > b)
    }

    @TestCase
    func testBaseIsAboveCssOverlay(): Unit {
        // .el-overlay 的 CSS 兜底是 2000；弹层必须严格大于它，否则会被遮罩吃掉
        @Assert(nextZIndex() > 2000)
    }
}
