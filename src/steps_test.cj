package cjxt

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class StepsStatusTest {
    @TestCase
    public func testActiveMiddle(): Unit {
        // active=2：idx0 完成，idx1 进行，idx2 等待
        @Expect(stepsStatus("", 0, 2, "process", "finish"), "success")
        @Expect(stepsStatus("", 1, 2, "process", "finish"), "process")
        @Expect(stepsStatus("", 2, 2, "process", "finish"), "wait")
    }

    @TestCase
    public func testFirstActive(): Unit {
        @Expect(stepsStatus("", 0, 1, "process", "finish"), "process")
        @Expect(stepsStatus("", 1, 1, "process", "finish"), "wait")
    }

    @TestCase
    public func testForceStatus(): Unit {
        @Expect(stepsStatus("error", 1, 1, "process", "finish"), "error")
        @Expect(stepsStatus("finish", 2, 1, "process", "finish"), "success")
    }

    @TestCase
    public func testCustomStatuses(): Unit {
        // processStatus=error → 当前步 error
        @Expect(stepsStatus("", 0, 1, "error", "finish"), "error")
        @Expect(stepsStatus("", 0, 2, "process", "wait"), "wait") // finishStatus=wait → 已完成的也是 wait
    }

    @TestCase
    public func testMap(): Unit {
        @Expect(mapStepStatus("finish"), "success")
        @Expect(mapStepStatus("process"), "process")
        @Expect(mapStepStatus("wait"), "wait")
        @Expect(mapStepStatus("error"), "error")
    }

    // ============ 布局（对齐 EP item.vue style 计算） ============

    @TestCase
    public func testFlexStyleBasis(): Unit {
        // 3 步非末步：basis = 100/(3-1) = 50%，无 max-width
        @Expect(stepFlexStyle(3, false, false), "flex-basis: 50.000000%")
        // 4 步非末步：basis = 100/3 = 33.333333%
        @Expect(stepFlexStyle(4, false, false), "flex-basis: 33.333333%")
    }

    @TestCase
    public func testFlexStyleLast(): Unit {
        // 末步：basis + max-width = 100/n%
        @Expect(stepFlexStyle(3, true, false), "flex-basis: 50.000000%; max-width: 33.333333%")
        @Expect(stepFlexStyle(2, true, false), "flex-basis: 100.000000%; max-width: 50.000000%")
    }

    @TestCase
    public func testFlexStyleVertical(): Unit {
        // 垂直方向无布局样式（基础布局由 is-vertical 类驱动）
        @Expect(stepFlexStyle(3, false, true), "")
        @Expect(stepFlexStyle(3, true, true), "")
    }

    @TestCase
    public func testFlexStyleSingle(): Unit {
        // 单步：占满
        @Expect(stepFlexStyle(1, true, false), "flex-basis: 100%; max-width: 100%")
        @Expect(stepFlexStyle(1, false, false), "flex-basis: 100%")
    }
}
