package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

/**
 * 会话回收回归（2026-10-16 忆时塔生产 OOM 事故）。
 *
 * 事故根因：`SessionManager.cleanup()` 没有任何调用点 → `sessions` 只增不减。
 * 每次 HTTP 页面请求（含 Docker 健康检查每 30s 一次的 `curl /`）都会
 * `sessions.create(...)` 建一个会话，而会话持有一整棵渲染树；生产实测
 * 1756 个会话 = 608MB（堆 1GB 的 57%），最终持续 OOM。
 *
 * 这里的用例覆盖三层：cleanup 本身正确、两档 TTL 生效、App 层巡检可达。
 */
@Test
public class SessionCleanupTest {

    // cleanup 必须真的删掉过期会话（旧实现有方法但无人调用，等于没有）
    @TestCase
    public func testCleanupRemovesExpired(): Unit {
        // detachedTtl=0：未建 WS 的会话立即可回收
        let mgr = SessionManager(300000, detachedTtlMillis: 0)
        let s = mgr.create(div([]), div([]))
        @Expect(mgr.size(), Int64(1))
        let n = mgr.cleanup()
        @Expect(n, Int64(1))
        @Expect(mgr.size(), Int64(0))
        // 该会话确实取不到了
        match (mgr.get(s.id)) {
            case Some(_) => @Fail("过期会话应已被回收")
            case None => ()
        }
    }

    // 未过期的会话不得被误删
    @TestCase
    public func testCleanupKeepsFresh(): Unit {
        let mgr = SessionManager(300000, detachedTtlMillis: 300000)
        let _ = mgr.create(div([]), div([]))
        @Expect(mgr.cleanup(), Int64(0))
        @Expect(mgr.size(), Int64(1))
    }

    /**
     * 两档 TTL：已建立 WebSocket 的会话用长 TTL，从未建过 WS 的用短 TTL。
     * 这是本次修复的关键语义 —— 健康检查这类一次性请求不该长期驻留，
     * 而真实页面会话（有长连接）不能被杀。
     */
    @TestCase
    public func testDetachedSessionUsesShortTtl(): Unit {
        // 长 TTL 很大、短 TTL 为 0：只有「未建 WS」的那个会被回收
        let mgr = SessionManager(3600000, detachedTtlMillis: 0)
        let detached = mgr.create(div([]), div([]))          // 一次性 HTTP 请求
        let live = mgr.save("live", div([]), div([]))        // 模拟真实页面会话
        live.markConnected()                                  // 已建 WS → 走长 TTL
        @Expect(mgr.size(), Int64(2))

        let removed = mgr.cleanup()
        @Expect(removed, Int64(1))
        @Expect(mgr.size(), Int64(1))

        // 被回收的是 detached，不是 live
        match (mgr.get(detached.id)) {
            case Some(_) => @Fail("未建 WS 的会话应按短 TTL 回收")
            case None => ()
        }
        match (mgr.get("live")) {
            case Some(_) => ()
            case None => @Fail("已建 WS 的会话不应被短 TTL 误杀")
        }
    }

    // markConnected 置位 everConnected（两处状态不漂移）
    @TestCase
    public func testMarkConnectedSetsFlag(): Unit {
        let s = Session("s1", div([]), div([]))
        @Expect(s.everConnected(), false)
        s.markConnected()
        @Expect(s.everConnected(), true)
        // 同时把 wsState 标为 Connected（与旧行为一致）
        match (s.wsState) {
            case WsState.Connected => ()
            case _ => @Fail("markConnected 应同时把 wsState 置为 Connected")
        }
    }

    /**
     * cleanup 不能边遍历边删 HashMap（未定义行为：可能跳过元素）。
     * 多个过期会话必须**一次全部**回收，不能只删掉一部分。
     */
    @TestCase
    public func testCleanupRemovesAllExpiredAtOnce(): Unit {
        let mgr = SessionManager(300000, detachedTtlMillis: 0)
        let ids = ArrayList<String>()
        for (i in 0..20) {
            let s = mgr.create(div([]), div([]))
            ids.add(s.id)
        }
        @Expect(mgr.size(), Int64(20))
        let removed = mgr.cleanup()
        // 全部回收：漏删即说明迭代期删除跳过了元素
        @Expect(removed, Int64(20))
        @Expect(mgr.size(), Int64(0))
    }

    // 巡检可被手动触发（App 层入口；不必等后台周期）
    @TestCase
    public func testAppSweepSessionsOnce(): Unit {
        let app = App()
        // 默认 5 分钟 TTL：刚建的会话不该被回收
        let _ = app.sessions.create(div([]), div([]))
        @Expect(app.sweepSessionsOnce(), Int64(0))
        @Expect(app.sessions.size(), Int64(1))
    }

    /**
     * **仍连着的会话永不回收** —— 即使 lastActiveAt 已超过 TTL。
     *
     * 这一条是关键：用户开着页面只读不动（不发消息）时 lastActiveAt 不更新，
     * 若按「曾连接就用 lastActiveAt 判 TTL」会把活跃会话误杀。
     * 真实形态：页面开着 10 分钟没操作，但 WS 连接仍在。
     */
    @TestCase
    public func testConnectedSessionNeverReclaimed(): Unit {
        // 极短 TTL：确保「按时间判必然过期」
        let mgr = SessionManager(1, detachedTtlMillis: 1)
        let live = mgr.save("live", div([]), div([]))
        live.markConnected()                    // wsState = Connected
        live.lastActiveAt = 0                   // 伪造：很久没活动
        @Expect(mgr.cleanup(), Int64(0))
        @Expect(mgr.size(), Int64(1))
    }

    /**
     * 曾连接但**已断开**的会话：过了重连宽限期（ttlMillis）后回收。
     * 客户端断线后每 3s 自动重连并复用同一 sid，所以断开不能立刻删。
     */
    @TestCase
    public func testDisconnectedSessionReclaimedAfterTtl(): Unit {
        let mgr = SessionManager(1, detachedTtlMillis: 1)   // 宽限期 1ms
        let s = mgr.save("gone", div([]), div([]))
        s.markConnected()
        s.wsState = WsState.Disconnected        // 模拟 listenLoop 断开后的状态
        s.lastActiveAt = 0
        @Expect(mgr.cleanup(), Int64(1))
        @Expect(mgr.size(), Int64(0))
    }

    // 断开但在宽限期内（刚断开，客户端可能 3s 后重连）→ 不回收
    @TestCase
    public func testDisconnectedWithinGraceKept(): Unit {
        let mgr = SessionManager(600000, detachedTtlMillis: 1)   // 宽限 10 分钟
        let s = mgr.save("reconnecting", div([]), div([]))
        s.markConnected()
        s.wsState = WsState.Disconnected
        s.touch()                               // 刚断开
        @Expect(mgr.cleanup(), Int64(0))
        @Expect(mgr.size(), Int64(1))
    }

    // 巡检线程可启动且幂等（重复调用不产生第二个线程/不抛错）
    @TestCase
    public func testStartSessionSweeperIsIdempotent(): Unit {
        let app = App()
        app.sessionSweepMs = 1000
        app.startSessionSweeper()
        app.startSessionSweeper()   // 第二次应直接返回
        @Expect(app.sweeperStarted, true)
        app.stopSessionSweeper()
    }
}
