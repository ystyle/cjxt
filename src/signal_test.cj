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
    public func testStoreSubscribeOnSet() {
        let st = Store<Int64>(10)
        let captured = Box<Int64>(-1)
        st.subscribe({ => captured.value = st.get() })
        st.set({ v => v * 2 })
        @Expect(captured.value, 20)
        @Expect(st.get(), 20)
    }
}
