// 页面实例身份：导航走开再回来，是同一个实例还是新的？
package cjxt

import std.collection.{ArrayList, HashMap}
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.url.URL
import stdx.net.http.{Client, ClientBuilder, WebSocket, WebSocketFrameType}
import stdx.net.http.WebSocketFrame

let pageSeq = Signal<Int64>(0)

class IdentityPage <: Component {
    // 实例字段：每次 new 一次就 +1（用于判断是否复用了实例）
    let born: Int64
    public init() {
        this.born = pageSeq.get() + 1
        pageSeq.set(this.born)
    }
    public func render(): IComponent {
        div([text("born=${this.born}")], attrs: Some(HashMap<String, String>([("class", "idp")])))
    }
}

class OtherPage <: Component {
    public init() {}
    public func render(): IComponent {
        div([text("other")], attrs: Some(HashMap<String, String>([("class", "otherp")])))
    }
}

@Test
public class PageIdentityE2ETest {
    static var port: UInt16 = 18156

    @TestCase
    public func testNavigateBackCreatesNewPageInstance(): Unit {
        pageSeq.set(0)
        let registry = RouteRegistry.global()
        registry.register("/", { => IdentityPage() })
        registry.register("/idp", { => IdentityPage() })
        registry.register("/other", { => OtherPage() })

        let app = App().host("127.0.0.1").port(PageIdentityE2ETest.port)
        spawn { try { app.serve() } catch (_: Exception) { () } }
        sleep(Duration.millisecond * 300)

        let sid = "pid-1"
        let client = ClientBuilder().build()
        let (ws, _) = WebSocket.upgradeFromClient(client,
            URL.parse("ws://127.0.0.1:${PageIdentityE2ETest.port}/ws"))
        ws.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"${sid}\"}".toArray())
        sleep(Duration.millisecond * 200)

        ws.write(WebSocketFrameType.TextWebFrame,
            "{\"type\":\"navigate\",\"path\":\"/idp\",\"sessionId\":\"${sid}\"}".toArray())
        sleep(Duration.millisecond * 300)
        ws.write(WebSocketFrameType.TextWebFrame,
            "{\"type\":\"navigate\",\"path\":\"/other\",\"sessionId\":\"${sid}\"}".toArray())
        sleep(Duration.millisecond * 300)
        ws.write(WebSocketFrameType.TextWebFrame,
            "{\"type\":\"navigate\",\"path\":\"/idp\",\"sessionId\":\"${sid}\"}".toArray())
        sleep(Duration.millisecond * 300)

        // 页面构造了几次？
        println("[pid] IdentityPage 构造次数=${pageSeq.get()}")
        app.stop()
        // 每次导航都 new 一个页面实例（不是复用）
        // 初始 HTTP 首渲 1 次 + /idp 1 次 + 回到 /idp 1 次 = 3（每次导航都新建实例，不复用）
        @Expect(pageSeq.get(), 3)
    }
}
