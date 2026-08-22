package cjxt

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class PushCoalescerTest {
    @TestCase
    public func testMarkFirstReturnsTrue(): Unit {
        let c = PushCoalescer()
        @Expect(c.mark("s1"), true)
        @Expect(c.isArmed(), true)
        @Expect(c.pendingCount(), 1)
    }

    @TestCase
    public func testMarkSameSidDedup(): Unit {
        let c = PushCoalescer()
        c.mark("s1")
        @Expect(c.mark("s1"), false) // 同会话去重，不开新 flush
        @Expect(c.pendingCount(), 1)
    }

    @TestCase
    public func testMarkOtherSidNoNewFlush(): Unit {
        let c = PushCoalescer()
        c.mark("s1")
        @Expect(c.mark("s2"), false) // 已有武装的 flush，不开新
        @Expect(c.pendingCount(), 2)
    }

    @TestCase
    public func testBeginFlushResets(): Unit {
        let c = PushCoalescer()
        c.mark("s1")
        c.mark("s2")
        c.mark("s1")
        let out = c.beginFlush()
        @Expect(out.size, 2)
        @Expect(out[0], "s1")
        @Expect(out[1], "s2")
        @Expect(c.isArmed(), false)
        @Expect(c.pendingCount(), 0)
    }

    @TestCase
    public func testNewBurstAfterFlush(): Unit {
        let c = PushCoalescer()
        c.mark("s1")
        c.beginFlush()
        @Expect(c.mark("s1"), true) // 新 burst 需要新 flush
    }

    @TestCase
    public func testEmptyBeginFlush(): Unit {
        let c = PushCoalescer()
        let out = c.beginFlush()
        @Expect(out.size, 0)
        @Expect(c.isArmed(), false)
    }
}
