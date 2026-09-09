package cjxt

import std.collection.{ArrayList, HashMap}
import std.convert.*
import std.fs.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.kit.*
import stdx.encoding.url.URL
import stdx.net.http.{Client, ClientBuilder, WebSocket, WebSocketFrameType}

// 回归：WS 长连接断开后服务端必须回收连接（CLOSE_WAIT/fd 泄漏 —— 与 mcp-cj SSE
// 同款问题，每次进界面/刷新/关页即泄漏一条）。listenLoop 的 finally 保证所有退出
// 路径（Close 帧 break、对端直接断连抛 ConnectionException、处理异常逃逸）都
// closeConn()。
// 断言方式：进程内 /proc/self/fd 计数——WS 建立后 fd 上升，断开回收后应回落。
class WsReclaimPage <: Component {
    public override func render(): IComponent {
        div([text("ws-conn-reclaim")])
    }
}

@Test
public class WsConnReclaimE2ETest {
    static var port: UInt16 = 18141
    static var seqPort: UInt16 = 18142

    // 进程内打开 fd 数（/proc/self/fd 目录条目数）
    private static func fdCount(): Int64 {
        let entries = Directory.readFrom("/proc/self/fd")
        Int64(entries.size)
    }

    // 建连（不关闭）→ fd 上升；Close 帧断开 → 服务端回收 → fd 回落。
    @TestCase
    public func testCloseFrameReclaimsConn(): Unit {
        let page = WsReclaimPage()
        RouteRegistry.global().register("/", { => page })
        let app = App().host("127.0.0.1").port(WsConnReclaimE2ETest.port)
        spawn { app.serve() }
        sleep(Duration.millisecond * 300)

        let fdBefore = fdCount()
        var ws1: WebSocket
        try {
            let client = ClientBuilder().build()
            let (w, _) = WebSocket.upgradeFromClient(client, URL.parse("ws://127.0.0.1:${WsConnReclaimE2ETest.port}/ws"))
            ws1 = w
        } catch (e: Exception) {
            app.stop()
            @Expect(false, true) // 连接失败
            return
        }
        ws1.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"reclaim-1\"}".toArray())
        let f1 = ws1.read() // connected
        @Expect(f1.frameType == WebSocketFrameType.TextWebFrame, true)
        let fdDuring = fdCount()
        // 建连后 fd 应上升（至少 +1）
        @Expect(fdDuring > fdBefore, true)

        // 正常 Close 帧断开（浏览器关页/刷新等价路径）
        ws1.writeCloseFrame()
        // 等待服务端 listenLoop 退出 + finally closeConn
        sleep(Duration.millisecond * 500)
        let fdAfter = fdCount()
        // 服务端已回收该连接：fd 应回落（旧代码不 closeConn → fd 保持高位）
        @Expect(fdAfter <= fdBefore + 1, true)

        app.stop()
    }
}
