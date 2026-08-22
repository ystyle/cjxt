package cjxt

import std.collection.ArrayList
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.kit.*
import stdx.encoding.url.URL
import stdx.net.http.{Client, ClientBuilder, WebSocket, WebSocketFrameType}

// 端到端：多次 pushUpdate（流式 token 突发）合并为一次 sendPatch 下发
// 需要真实 WS 客户端（upgradeFromClient → SHA1 digest），依赖 target 级 link-option。

class E2ePushPage <: Component {
    let sig: Signal<Int64>
    public init(sig: Signal<Int64>) {
        this.sig = sig
    }
    public func render(): IComponent {
        div([text("n=${this.sig.get()}")])
    }
}

@Test
public class PushCoalesceE2ETest {
    static var port: UInt16 = 18123

    @TestCase
    public func testBurstCoalescesIntoOnePatch(): Unit {
        let sig = Signal<Int64>(0)
        RouteRegistry.global().register("/", { => E2ePushPage(sig) })
        App.sendPatchCount = 0
        let app = App().host("127.0.0.1").port(PushCoalesceE2ETest.port)
        let serveErr = Box<Option<Exception>>(None)
        spawn {
            try {
                app.serve()
            } catch (e: Exception) {
                serveErr.value = Some(e)
            }
        }
        sleep(Duration.millisecond * 300)
        match (serveErr.value) {
            case Some(e) =>
                @Expect(false, true) // serve 抛异常
                println("[E2E] serve error: ${e.message}")
                return
            case None => ()
        }

        // 连接 WS → 建会话（读 connected + 初始树）
        var ws: WebSocket
        try {
            let client = ClientBuilder().build()
            let (w, _) = WebSocket.upgradeFromClient(client, URL.parse("ws://127.0.0.1:${PushCoalesceE2ETest.port}/ws"))
            ws = w
        } catch (e: Exception) {
            println("[E2E] upgrade failed: ${e.message}")
            app.stop()
            @Expect(false, true) // 连接失败
            return
        }
        ws.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"e2e-c-1\"}".toArray())
        let f1 = ws.read() // connected
        let f2 = ws.read() // full tree

        // 5 次 pushUpdate 突发（模拟流式 token），应合并为 1 次 sendPatch
        for (i in 1..=5) {
            let v = i
            app.pushUpdate("e2e-c-1", { _ =>
                sig.set(v)
                PatchResult.ReRender
            })
        }
        // 等待 flush 窗口（15ms）+ 下发余量
        sleep(Duration.millisecond * 150)

        // 客户端读取合并后的 patch
        let f3 = ws.read()
        let text = String.fromUtf8(f3.payload)
        

        @Expect(App.sendPatchCount, 1) // 5 次 pushUpdate → 1 次 sendPatch
        @Expect(text.contains("\"kind\":\"patch\""), true)
        @Expect(text.contains("n=5"), true) // 合并 patch 反映全部 5 次更新
        ws.closeConn()
        app.stop()
    }
}
