package cjxt

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

// 全特性响应式核心测试：Signal / Computed / Effect / batch / untracked / 相等性 / 生命周期
@Test
public class SignalFullTest {
    // ---------- 相等性 ----------

    @TestCase
    public func testEqualitySkipsNotify(): Unit {
        let s = Signal<Int64>(0, compare: Some({ a, b => a == b }))
        let notified = Box<Int64>(0)
        s.subscribe({ => notified.value += 1 })
        s.set(0)   // 相同值：不通知
        @Expect(notified.value, 0)
        s.set(5)
        @Expect(notified.value, 1)
        s.set(5)   // 相同值：不通知
        @Expect(notified.value, 1)
    }

    @TestCase
    public func testNoCompareAlwaysNotify(): Unit {
        let s = Signal<Int64>(0)
        let notified = Box<Int64>(0)
        s.subscribe({ => notified.value += 1 })
        s.set(0)   // 未配相等性：即使值相同也通知
        @Expect(notified.value, 1)
    }

    // ---------- untracked ----------

    @TestCase
    public func testUntrackedRead(): Unit {
        let s = Signal<Int64>(0)
        let captured = Box<Int64>(-1)
        SignalTracker.enterScope({ => captured.value = 99 })
        // untracked 读取不建立订阅
        let v = untracked({ => s.get() })
        SignalTracker.exitScope()
        @Expect(v, 0)
        s.set(42)
        @Expect(captured.value, -1)  // 未被通知（untracked 读取未建立订阅）
    }

    @TestCase
    public func testTrackedReadSubscribes(): Unit {
        let s = Signal<Int64>(0)
        let captured = Box<Int64>(-1)
        SignalTracker.enterScope({ => captured.value = 99 })
        let v = s.get()   // 正常读取建立订阅
        SignalTracker.exitScope()
        @Expect(v, 0)
        s.set(7)
        @Expect(captured.value, 99)  // 被通知
    }

    // ---------- batch ----------

    @TestCase
    public func testBatchSingleNotify(): Unit {
        let s = Signal<Int64>(0)
        let notified = Box<Int64>(0)
        s.subscribe({ => notified.value += 1 })
        batch({ =>
            s.set(1)
            s.set(2)
            s.set(3)
        })
        @Expect(s.get(), 3)
        @Expect(notified.value, 1)  // 只通知一次
    }

    @TestCase
    public func testBatchMultipleSignals(): Unit {
        let a = Signal<Int64>(0)
        let b = Signal<Int64>(0)
        let notified = Box<Int64>(0)
        a.subscribe({ => notified.value += 1 })
        b.subscribe({ => notified.value += 1 })
        batch({ =>
            a.set(1)
            b.set(2)
            a.set(3)
        })
        @Expect(notified.value, 2)  // 每个变更的 signal 通知一次
        @Expect(a.get(), 3)
        @Expect(b.get(), 2)
    }

    @TestCase
    public func testBatchReturnsValue(): Unit {
        let r = batch({ => 42 })
        @Expect(r, 42)
    }

    // ---------- Computed ----------

    @TestCase
    public func testComputedBasic(): Unit {
        let a = Signal<Int64>(2)
        let b = Signal<Int64>(3)
        let sum = Computed<Int64>({ => a.get() + b.get() })
        @Expect(sum.get(), 5)
        a.set(10)
        @Expect(sum.get(), 10 + 3)
        b.set(7)
        @Expect(sum.get(), 17)
    }

    @TestCase
    public func testComputedLazyCache(): Unit {
        let a = Signal<Int64>(1)
        let computeCount = Box<Int64>(0)
        let double = Computed<Int64>({ => computeCount.value += 1; a.get() * 2 })
        // 未读取不计算
        @Expect(computeCount.value, 0)
        let v1 = double.get()
        @Expect(v1, 2)
        @Expect(computeCount.value, 1)
        // 缓存：未变化不重算
        let v2 = double.get()
        @Expect(v2, 2)
        @Expect(computeCount.value, 1)
        // 依赖变化才重算
        a.set(5)
        @Expect(double.get(), 10)
        @Expect(computeCount.value, 2)
    }

    @TestCase
    public func testComputedSubscribeDownstream(): Unit {
        let a = Signal<Int64>(1)
        let square = Computed<Int64>({ => a.get() * a.get() })
        let notified = Box<Int64>(0)
        square.subscribe({ => notified.value += 1 })
        @Expect(square.get(), 1)
        a.set(3)
        // 依赖变化 → computed 失效 → 通知下游
        @Expect(notified.value, 1)
        @Expect(square.get(), 9)
    }

    @TestCase
    public func testComputedChained(): Unit {
        let a = Signal<Int64>(1)
        let b = Computed<Int64>({ => a.get() * 2 })
        let c = Computed<Int64>({ => b.get() + 1 })
        @Expect(c.get(), 3)
        a.set(5)
        @Expect(c.get(), 11)   // 链式失效 + 重算
    }

    @TestCase
    public func testComputedInTrackingScope(): Unit {
        let a = Signal<Int64>(1)
        let double = Computed<Int64>({ => a.get() * 2 })
        let captured = Box<Int64>(-1)
        SignalTracker.enterScope({ => captured.value = 77 })
        let v = double.get()   // 组件读取 computed
        SignalTracker.exitScope()
        @Expect(v, 2)
        a.set(9)
        @Expect(captured.value, 77)  // computed 失效 → 通知订阅它的组件
    }

    // ---------- Effect ----------

    @TestCase
    public func testEffectRunsImmediatelyAndOnChange(): Unit {
        let s = Signal<Int64>(0)
        let log = ArrayList<Int64>()
        let eff = Effect({ => log.add(s.get()) })
        // 立即运行一次
        @Expect(log.size, 1)
        @Expect(log[0], 0)
        s.set(1)
        @Expect(log.size, 2)
        @Expect(log[1], 1)
        s.set(2)
        @Expect(log.size, 3)
        @Expect(log[2], 2)
    }

    @TestCase
    public func testEffectDisposeStops(): Unit {
        let s = Signal<Int64>(0)
        let count = Box<Int64>(0)
        let eff = Effect({ => count.value += 1; let _ = s.get() })
        @Expect(count.value, 1)
        eff.dispose()
        s.set(1)
        @Expect(count.value, 1)  // dispose 后不再运行
    }

    @TestCase
    public func testEffectUntrackedReadNoRerun(): Unit {
        let s = Signal<Int64>(0)
        let count = Box<Int64>(0)
        let eff = Effect({ =>
            count.value += 1
            let _ = untracked({ => s.get() })
        })
        @Expect(count.value, 1)
        s.set(5)
        @Expect(count.value, 1)  // untracked 读取不建立依赖 → 不重跑
    }

    @TestCase
    public func testEffectReadsMultipleDeps(): Unit {
        let a = Signal<Int64>(1)
        let b = Signal<Int64>(2)
        let last = Box<Int64>(0)
        let eff = Effect({ => last.value = a.get() + b.get() })
        @Expect(last.value, 3)
        a.set(10)
        @Expect(last.value, 12)
        b.set(20)
        @Expect(last.value, 30)
    }

    // ---------- 订阅生命周期（unsubscribe by id） ----------

    @TestCase
    public func testUnsubscribeById(): Unit {
        let s = Signal<Int64>(0)
        let c1 = Box<Int64>(0)
        let c2 = Box<Int64>(0)
        let id1 = s.subscribe({ => c1.value += 1 })
        let id2 = s.subscribe({ => c2.value += 1 })
        s.set(1)
        @Expect(c1.value, 1)
        @Expect(c2.value, 1)
        s.unsubscribe(id1)
        s.set(2)
        @Expect(c1.value, 1)   // 退订后不再通知
        @Expect(c2.value, 2)
    }
}

// ============ 原有兼容性测试（Signal 基础 + Store） ============

@Test
public class SignalTest {
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
        SignalTracker.enterScope({ => captured.value = 99 })
        let v = s.get()
        SignalTracker.exitScope()
        @Expect(v, 0)
        s.set(42)
        @Expect(captured.value, 99)
    }

    @TestCase
    public func testStoreAutoSubscribe() {
        let st = Store<Int64>(0)
        let captured = Box<Int64>(-1)
        SignalTracker.enterScope({ => captured.value = 77 })
        let v = st.get()
        SignalTracker.exitScope()
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

    @TestCase
    public func testSignalClearSubs() {
        let s = Signal<Int64>(0)
        let captured = Box<Int64>(-1)
        s.subscribe({ => captured.value = 99 })
        s.set(5)
        @Expect(captured.value, 99)

        s.clearSubs()
        captured.value = -1
        s.set(10)
        @Expect(captured.value, -1)
    }
}

@Test
public class EffectReentrancyTest {
    @TestCase
    public func testEffectSelfWriteNoStackOverflow(): Unit {
        // effect 写自身读取的依赖（无条件 +1）：重入保护把递归变成有界重跑（这里用有限条件验证不栈溢出）
        let s = Signal<Int64>(0)
        let runs = Box<Int64>(0)
        let eff = Effect({ =>
            runs.value += 1
            let cur = s.get()
            if (cur < 5) {
                s.set(cur + 1)
            }
        })
        // 收敛到 5；每次 set 触发一次重跑（重入保护使运行中变更延迟到结束）
        @Expect(s.get(), 5)
        @Expect(runs.value >= 5, true)
        @Expect(runs.value < 20, true) // 没有无限递归/栈溢出
    }

    @TestCase
    public func testEffectSelfWriteEqualValueConverges(): Unit {
        // effect 写回相同值（相等性信号）：不触发重跑，不循环
        let s = Signal<Int64>(1, compare: Some({ a, b => a == b }))
        let runs = Box<Int64>(0)
        let eff = Effect({ =>
            runs.value += 1
            s.set(s.get()) // 写回相同值
        })
        @Expect(runs.value, 1) // 只跑一次
        @Expect(s.get(), 1)
    }

    @TestCase
    public func testEffectDisposeStopsPendingRerun(): Unit {
        let s = Signal<Int64>(0)
        let runs = Box<Int64>(0)
        let eff = Effect({ =>
            runs.value += 1
            let cur = s.get()
            if (cur < 3) { s.set(cur + 1) }
        })
        eff.dispose()
        let before = runs.value
        s.set(100)
        @Expect(runs.value, before) // dispose 后不再重跑
    }
}
