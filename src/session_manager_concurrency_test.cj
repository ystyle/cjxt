// SessionManager 的并发安全（回归）
//
// ## 缺陷
//
// `SessionManager.sessions` 是裸 `HashMap`，却有**三类线程**在并发访问：
//   · HTTP 请求协程  —— `create()`（每次页面请求都建一个会话）
//   · WS 连接协程    —— `get()` 查会话、断开时 `remove()`
//   · 巡检协程       —— `cleanup()` 遍历 + 删除（每 30s 一次）
//
// `HashMap` 在「一边遍历一边增删」时会进入未定义行为。实测表现有两种：
//   · 进程**卡死**（测试整轮超时、日志一行为空）—— 迭代器在扩容/搬移中迷路
//   · 崩溃（SIGSEGV）
//
// 这条比 Signal 那几处更容易触发：每个 HTTP 请求都会 `create()`，
// 而巡检每 30s 就遍历一次整张表。
//
// ## 为什么不做 Go 式的 Hub
//
// Go 的 hub 模式（单 goroutine 独占 map + channel 投递）在仓颉上不成立：
// 标准库没有 `Channel`，得自建一套「投递 → 等回传 → 被唤醒」的消息机制，
// 而 chan-bench 实测这种 park/unpark 往返是 **1130–1610 ns/次**
// （`chan-bench-cj/docs/patterns.md` §5），且那正是其「反模式」表里
// 「用队列传任务」一项。会话查找处在每次 WS 消息的热路径上，不适合付这个成本。
//
// 采用**分片 + 每片 ReadWriteLock**（patterns 模式 D）：
// 会话表按 sid 哈希分片，各片独立加锁，天然消除「多消费者争一把锁」的惊群，
// 实测比共享单锁快约 1.5x，且读读之间可并发。
package cjxt

import std.collection.ArrayList
import std.sync.Mutex
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

// 轻量屏障：等 n 个 worker 全部到达（带超时，避免测试挂死掩盖真问题）
class RaceGate {
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

@Test
public class SessionManagerConcurrencyTest {
    // 建 / 查 / 删 三方并发（对应 HTTP / WS / WS 断开三条真实路径）
    @TestCase
    public func testConcurrentCreateGetRemove(): Unit {
        let mgr = SessionManager(300000)
        let rounds: Int64 = 300
        var unfinished: Int64 = 0
        let seen = ArrayList<String>()

        for (_ in 0..rounds) {
            let gate = RaceGate(3)
            // HTTP：建会话并回查
            spawn {
                let s = mgr.create(text("p"), text("t"))
                let _ = mgr.get(s.id)
                gate.arrive()
            }
            // WS 断开：建了立刻删
            spawn {
                let s = mgr.create(text("a"), text("b"))
                mgr.remove(s.id)
                gate.arrive()
            }
            // 巡检/统计：只读
            spawn {
                let _ = mgr.size()
                gate.arrive()
            }
            if (!gate.await(5000)) {
                unfinished += 1
            }
        }

        println("[sm-conc] 未完成=${unfinished}")
        @Expect(unfinished, 0)
    }

    // 巡检 cleanup（遍历 + 删除）与 HTTP 建会话并发 —— 最容易撞的时序
    @TestCase
    public func testCleanupRacingWithCreate(): Unit {
        // TTL 设 0：任何未连接的会话都立即过期，逼 cleanup 真的删东西
        let mgr = SessionManager(0, detachedTtlMillis: 0)
        let rounds: Int64 = 400
        var unfinished: Int64 = 0

        for (_ in 0..rounds) {
            let gate = RaceGate(2)
            // HTTP 侧：连续建会话
            spawn {
                for (_ in 0..4) {
                    let _ = mgr.create(text("p"), text("t"))
                }
                gate.arrive()
            }
            // 巡检侧：遍历 + 删
            spawn {
                let _ = mgr.cleanup()
                gate.arrive()
            }
            if (!gate.await(5000)) {
                unfinished += 1
            }
        }

        println("[sm-conc] cleanup 并发 未完成=${unfinished} 剩余=${mgr.size()}")
        @Expect(unfinished, 0)
    }
}
