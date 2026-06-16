package cjxt

import std.unittest.*

@Test
class SignalTest {
    @TestCase
    public func testSignalGetSet() {
        let s = Signal<Int64>(0)
        s.set(42)
        @Expect(s.get(), 42)
    }

    @TestCase
    public func testSignalUpdate() {
        let s = Signal<Int64>(0)
        s.update({ v => v + 1 })
        @Expect(s.get(), 1)
    }

    @TestCase
    public func testSignalUpdateMulti() {
        let s = Signal<Int64>(0)
        s.update({ v => v + 1 })
        s.update({ v => v + 2 })
        @Expect(s.get(), 3)
    }

    @TestCase
    public func testSignalUpdateString() {
        let s = Signal<String>("hello")
        s.update({ v => "${v} world" })
        @Expect(s.get(), "hello world")
    }

    @TestCase
    public func testSignalSubscribe() {
        let s = Signal<Int64>(0)
        let captured = Box<Int64>(0)
        s.subscribe({ => captured.value = 99 })
        s.set(5)
        @Expect(captured.value, 99)
        @Expect(s.get(), 5)
    }

    @TestCase
    public func testSignalSubscribeOnUpdate() {
        let s = Signal<Int64>(10)
        let captured = Box<Int64>(-1)
        s.subscribe({ => captured.value = s.get() })
        s.update({ v => v * 2 })
        @Expect(captured.value, 20)
        @Expect(s.get(), 20)
    }

    @TestCase
    public func testStoreSet() {
        let st = Store<Int64>(0)
        st.set({ v => v + 1 })
        @Expect(st.get(), 1)
    }

    @TestCase
    public func testStoreSetMulti() {
        let st = Store<Int64>(0)
        st.set({ v => v + 5 })
        st.set({ v => v * 2 })
        @Expect(st.get(), 10)
    }

    @TestCase
    public func testSignalAutoSubscribe() {
        let s = Signal<Int64>(0)
        let captured = Box<Int64>(-1)
        // 模拟 initSignals 中的 auto-subscribe 流程
        SignalTracker.pendingSub = Some({ => captured.value = 99 })
        let v = s.get()
        SignalTracker.pendingSub = None
        @Expect(v, 0)
        // 此时 s 的 subs 应该有刚才添加的 callback
        // 再手动触发 set 来验证 subscriber 是否被调用
        s.set(42)
        @Expect(captured.value, 99)
    }

    @TestCase
    public func testStoreAutoSubscribe() {
        let st = Store<Int64>(0)
        let captured = Box<Int64>(-1)
        SignalTracker.pendingSub = Some({ => captured.value = 77 })
        let v = st.get()
        SignalTracker.pendingSub = None
        @Expect(v, 0)
        st.set({ v => v + 1 })
        @Expect(st.get(), 1)
        @Expect(captured.value, 77)
    }

    @TestCase
    public func testStoreSubscribeOnSet() {
        let st = Store<Int64>(10)
        let captured = Box<Int64>(-1)
        st.subscribe({ => captured.value = st.get() })
        st.set({ v => v * 2 })
        @Expect(captured.value, 20)
        @Expect(st.get(), 20)
    }
}
