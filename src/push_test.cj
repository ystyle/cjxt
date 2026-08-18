package cjxt

import std.unittest.*
import std.unittest.testmacro.*

/**
 * App.pushUpdate 服务端推送测试
 *
 * 覆盖 pushUpdate 的守卫路径（会话不存在 / 未连接 / 连接但无 ws 引用）。
 *
 * 真实 WS 端到端推送（启动服务 + 客户端连接 + 补丁帧断言）在
 * harness-cj 仓库的 harness_tests 中验证——客户端升级需要
 * stdx.crypto.digest 链接，而 cjxt 主包带宏包，全局 link-option
 * 会传染宏包导致链接失败。
 */
@Test
class PushUpdateTest {

    @TestCase
    func testPushUnknownSession(): Unit {
        let app = App()
        @Expect(!app.pushUpdate("no-such-session", { _ => PatchResult.ReRender }))
    }

    @TestCase
    func testPushDisconnectedSession(): Unit {
        let app = App()
        let session = app.sessions.save("s1", text("hi"), div([]))
        session.wsState = WsState.Disconnected
        session.ws = None
        @Expect(!app.pushUpdate("s1", { _ => PatchResult.ReRender }))
    }

    @TestCase
    func testPushConnectingSession(): Unit {
        let app = App()
        let session = app.sessions.save("s2", text("hi"), div([]))
        session.wsState = WsState.Connecting
        session.ws = None
        @Expect(!app.pushUpdate("s2", { _ => PatchResult.ReRender }))
    }

    @TestCase
    func testPushConnectedWithoutWs(): Unit {
        let app = App()
        let session = app.sessions.save("s3", text("hi"), div([]))
        session.wsState = WsState.Connected
        session.ws = None
        @Expect(!app.pushUpdate("s3", { _ => PatchResult.ReRender }))
    }
}
