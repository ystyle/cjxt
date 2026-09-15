package cjxt

import std.collection.ArrayList
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.kit.*
import stdx.encoding.url.URL
import stdx.net.http.{Client, ClientBuilder, WebSocket, WebSocketFrameType}

// 端到端：旧页面的组件不得作为脏组件补丁下发到新页面。
//
// 复现的缺陷：组件在 render 里 get() 信号 → 订阅 markDirty 回调；订阅只在
// 组件销毁时才会解除，而换页只替换 session.tree、不销毁旧页面的组件实例。
// 于是旧组件仍在监听共享信号，一旦它被标脏，sendPatch 会按**旧路径**把它渲染出来，
// 并替换 session.tree 里同路径的节点——新页面上那一格被旧页面的内容覆盖
// （实测：发布计划详情页的「发布项」表格变成计划列表，刷新页面才恢复）。
class StaleProbeCell <: Component {
    let sig: Signal<String>
    public init(sig: Signal<String>) {
        this.sig = sig
    }
    public func render(): IComponent {
        text("A-cell:" + this.sig.get())
    }
}

class StaleProbePageA <: Component {
    let sig: Signal<String>
    public init(sig: Signal<String>) {
        this.sig = sig
    }
    // 嵌套组件读共享信号：它在旧树里的路径是新页面某节点的同路径
    public func render(): IComponent {
        div([text("A-head"), div([StaleProbeCell(this.sig)])])
    }
}

class StaleProbePageB <: Component {
    let live: Signal<String>
    public init(live: Signal<String>) {
        this.live = live
    }
    public func render(): IComponent {
        div([text("B-head"), div([text("B-cell:" + this.live.get())])])
    }
}

@Test
public class StalePageDirtyE2ETest {
    static var port: UInt16 = 18129

    @TestCase
    public func testStalePageComponentNotPatchedIntoNewPage(): Unit {
        let stale = Signal<String>("s0")
        let live = Signal<String>("l0")
        let registry = RouteRegistry.global()
        registry.register("/", { => StaleProbePageB(live) })
        registry.register("/stale-probe-a", { => StaleProbePageA(stale) })
        registry.register("/stale-probe-b", { => StaleProbePageB(live) })

        let app = App().host("127.0.0.1").port(StalePageDirtyE2ETest.port)
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
                println("[E2E] serve error: ${e.message}")
                @Expect(false, true) // serve 抛异常
                return
            case None => ()
        }

        var ws: WebSocket
        try {
            let client = ClientBuilder().build()
            let (w, _) = WebSocket.upgradeFromClient(client, URL.parse("ws://127.0.0.1:${StalePageDirtyE2ETest.port}/ws"))
            ws = w
        } catch (e: Exception) {
            println("[E2E] upgrade failed: ${e.message}")
            app.stop()
            @Expect(false, true) // 连接失败
            return
        }
        ws.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"e2e-stale-1\"}".toArray())
        let _ = ws.read() // connected
        let _ = ws.read() // 初始整树

        // 导航到 A：渲染出订阅共享信号的嵌套组件
        ws.write(WebSocketFrameType.TextWebFrame,
            "{\"type\":\"navigate\",\"path\":\"/stale-probe-a\",\"sessionId\":\"e2e-stale-1\"}".toArray())
        let _ = ws.read() // A 的整树
        // 导航到 B：旧实现只换树，A 的组件实例仍订阅着 stale
        ws.write(WebSocketFrameType.TextWebFrame,
            "{\"type\":\"navigate\",\"path\":\"/stale-probe-b\",\"sessionId\":\"e2e-stale-1\"}".toArray())
        let _ = ws.read() // B 的整树

        // 同时改两个信号：stale 只有已离树的旧组件在读，live 由当前页面 B 在读
        // （后者保证无论修没修，都至少有一个补丁下发，测试不会卡在 read 上）
        let _ = app.pushUpdate("e2e-stale-1", { _ =>
            stale.set("s1")
            live.set("l1")
            PatchResult.ReRender
        })
        // 等待推送合并窗口（默认 15ms）+ 下发余量
        sleep(Duration.millisecond * 200)

        let f3 = ws.read()
        let text = String.fromUtf8(f3.payload)

        // 旧页面的组件必须已随换页退订/作废：补丁里不能出现它的内容
        @Expect(text.contains("A-cell"), false)
        // 当前页面的更新照常下发
        @Expect(text.contains("B-cell:l1"), true)
        ws.closeConn()
        app.stop()
    }
}
