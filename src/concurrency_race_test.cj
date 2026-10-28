// 并发安全：Signal 订阅表的跨线程竞态
//
// ## 缺陷
//
// `ReactiveNode.subs` 是裸 `ArrayList`，读写没有任何同步：
//   · `Signal.get()` 在追踪作用域内会 `subscribe()` → `subs.add(...)`
//   · `Signal.set()` 会 `notify()` → 复制并遍历 `subs`
//   · `Component.unbindDeps()` → `subs.remove(i..i+1)`
//
// 三者若跨线程并发，`ArrayList` 内部结构会被改坏（add 期间扩容 + 同时遍历/删除），
// 实测**直接 SIGSEGV**（进程段错误），不是可捕获的异常。
//
// ## 真实触发场景（非人为构造）
//
// cjxt 每条 WS 连接一个线程（`App.listenLoop`）。两个浏览器标签页各一条连接时：
//   · 标签页 A 的线程在 `render()` 里读**共享的包级 Signal**（订阅）；
//   · 标签页 B 的线程同时在写同一个 Signal（notify）；
//   · 任意一方导航/换页时 `dispose()` → `unbindDeps()`（删除）。
//
// 单用户不会触发（只有一条连接），**多用户/多标签页并发操作时会**：
// 轻则丢订阅（更新不推送）、重则整个进程崩溃。
//
// ## 用例说明
//
// 用一个共享 Signal + 两条线程（一读一写）跑多轮，复刻上述时序。
// 修复前：进程 SIGSEGV（`REASON: Crashed with exit code 11`）。
// 修复后：稳定通过，且订阅数收敛。
package cjxt

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class SignalConcurrencyTest {
    // 一读一写并发：修复前 SIGSEGV
    @TestCase
    public func testConcurrentSubscribeAndNotify(): Unit {
        let s = Signal<Int64>(0)
        let rounds: Int64 = 200
        var unfinished: Int64 = 0
        let t0 = DateTime.now()

        for (_ in 0..rounds) {
            let gate = Gate(2)
            // 线程 1：读（订阅）——另一会话在 render 里读共享 Signal
            spawn {
                SignalTracker.enterScope({ => () })
                let _ = s.get()
                SignalTracker.exitScope()
                gate.arrive()
            }
            // 线程 2：写（通知）——本会话在 handler 里写同一个 Signal
            spawn {
                s.set(s.get() + 1)
                gate.arrive()
            }
            if (!gate.await(3000)) {
                unfinished += 1
            }
        }

        let ms = (DateTime.now() - t0).toMilliseconds()
        let subsAfter = s.subCount()
        // 收尾：清空订阅表必须成功（结构被改坏时这里会越界/错乱）
        s.clearSubs()
        println("[race] rounds=${rounds} 未完成=${unfinished} subs=${subsAfter} 耗时=${ms}ms")
        @Expect(unfinished, 0)
        @Expect(s.subCount(), 0)
    }

    // 订阅 + 退订 + 通知三方并发：覆盖 dispose 路径
    @TestCase
    public func testConcurrentSubscribeUnsubscribeNotify(): Unit {
        let s = Signal<Int64>(0)
        let rounds: Int64 = 150
        var unfinished: Int64 = 0

        for (_ in 0..rounds) {
            let gate = Gate(3)
            // 订阅
            spawn {
                let id = s.subscribe({ => () })
                gate.arrive()
                // id 在此仅用于让编译器保留返回值
                if (id < 0) { return }
            }
            // 退订（可能删到别人的条目）
            spawn {
                s.clearSubs()
                gate.arrive()
            }
            // 通知
            spawn {
                s.set(s.get() + 1)
                gate.arrive()
            }
            if (!gate.await(3000)) {
                unfinished += 1
            }
        }

        println("[race] 三方并发 rounds=${rounds} 未完成=${unfinished}")
        @Expect(unfinished, 0)
    }
}

// 缺陷二：两个会话并发渲染 → 组件被登记到错误的会话名下
@Test
public class CaptureConcurrencyTest {
    // 复刻 sendPatch 的三步：beginCapture(sid) → 渲染 → endCapture → 检查归属
    @TestCase
    public func testConcurrentCaptureDoesNotCrossTalk(): Unit {
        let sigA = Signal<Int64>(0)
        let sigB = Signal<Int64>(0)
        let boxA = RaceProbeBox(sigA, "A")
        let boxB = RaceProbeBox(sigB, "B")

        let wrongOwner = Box<Int64>(0)
        let emptyCapture = Box<Int64>(0)
        let rounds: Int64 = 150
        var unfinished: Int64 = 0

        for (_ in 0..rounds) {
            let gate = Gate(2)
            spawn {
                let cap = captureOf("sess-A", boxA)
                for (c in cap) {
                    if (c.ownerSid() != "sess-A") { wrongOwner.value += 1 }
                }
                if (cap.size == 0) { emptyCapture.value += 1 }
                gate.arrive()
            }
            spawn {
                let cap = captureOf("sess-B", boxB)
                for (c in cap) {
                    if (c.ownerSid() != "sess-B") { wrongOwner.value += 1 }
                }
                if (cap.size == 0) { emptyCapture.value += 1 }
                gate.arrive()
            }
            if (!gate.await(3000)) {
                unfinished += 1
            }
        }

        println("[race] 归属串台=${wrongOwner.value} 空捕获=${emptyCapture.value} 未完成=${unfinished}")
        @Expect(wrongOwner.value, 0)
        @Expect(emptyCapture.value, 0)
        @Expect(unfinished, 0)
    }
}

class RaceProbeBox <: Component {
    let s: Signal<Int64>
    let tag: String
    public init(s: Signal<Int64>, tag: String) {
        this.s = s
        this.tag = tag
    }
    public func render(): IComponent {
        div([span([text("${this.tag}=${this.s.get()}")])])
    }
}

// 复刻 sendPatch 里的捕获三步：beginCapture → 渲染 → endCapture
func captureOf(sid: String, box: Component): ArrayList<Component> {
    RenderContext.beginCapture(sid)
    let _ = RenderContext.expandTree(box, "")
    return RenderContext.endCapture()
}

// 简易屏障：等全部 worker 跑完（带超时，避免测试挂死掩盖真问题）
class Gate {
    let lock = Mutex()
    var done: Int64 = 0
    let total: Int64

    public init(total: Int64) {
        this.total = total
    }

    public func arrive(): Unit {
        lock.lock()
        try {
            done += 1
        } finally {
            lock.unlock()
        }
    }

    public func await(timeoutMs: Int64): Bool {
        var waited: Int64 = 0
        while (waited < timeoutMs) {
            lock.lock()
            let n = done
            lock.unlock()
            if (n >= total) {
                return true
            }
            sleep(Duration.millisecond * 5)
            waited += 5
        }
        false
    }
}
