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
}
