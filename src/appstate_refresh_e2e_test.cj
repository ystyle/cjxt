// AppState 的生存期：整页刷新后还在不在？
//
// 文档里曾写「AppState 跨整页刷新」，但 `servePage` 每次 HTTP 请求都
// `sessions.create()`（新 id、新 session、新 states）。这里实测钉住真相。
package cjxt

import std.collection.{ArrayList, HashMap}
import std.io.StringReader
import std.time.*
import std.reflect.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.net.http.{Client, ClientBuilder}
import stdx.encoding.url.URL
import stdx.net.http.{WebSocket, WebSocketFrameType}
import stdx.net.http.WebSocketFrame

class RefreshProbeState <: AppState {
    public var hits = Signal<Int64>(0)
}

class RefreshProbePage <: Component {
    public init() {}
    public func render(): IComponent {
        div([text("probe-page")], attrs: Some(HashMap<String, String>([("class", "rp-page")])))
    }
}

@Test
public class AppStateRefreshE2ETest {
    static var port: UInt16 = 18154

    @TestCase
    public func testAppStateResetsOnFullPageReload(): Unit {
        let registry = RouteRegistry.global()
        registry.register("/", { => RefreshProbePage() })
        registry.register("/rp", { => RefreshProbePage() })

        let app = App()
            .host("127.0.0.1").port(AppStateRefreshE2ETest.port)
            .state<RefreshProbeState>({ => RefreshProbeState() })
        spawn {
            try {
                app.serve()
            } catch (_: Exception) {
                ()
            }
        }
        sleep(Duration.millisecond * 300)

        // 第一次 HTTP 请求（模拟标签页打开）
        let client = ClientBuilder().build()
        let r1 = client.get("http://127.0.0.1:${AppStateRefreshE2ETest.port}/rp")
        let h1 = StringReader(r1.body).readToEnd()
        r1.close()
        let sid1 = match (extractSid(h1)) {
            case Some(s) => s
            case None => ""
        }
        @Expect(sid1.size > 0, true)

        // 往这个会话的 AppState 写一个值（走 WS action 才能拿到实例）
        let s1 = app.sessions.get(sid1)
        let st1 = match (s1) {
            case Some(sess) =>
                match (sess.states.get(TypeInfo.of<RefreshProbeState>().qualifiedName)) {
                    case Some(s: RefreshProbeState) => s.hits.set(42)
                    case _ => ()
                }
            case None => ()
        }
        // 二次读取确认写入生效
        let val1 = match (app.sessions.get(sid1)) {
            case Some(sess) =>
                match (sess.states.get(TypeInfo.of<RefreshProbeState>().qualifiedName)) {
                    case Some(s: RefreshProbeState) =>
                        match (s.hits.get()) {
                            case v => v
                        }
                    case _ => Int64(-1)
                }
            case None => Int64(-2)
        }
        @Expect(val1, 42)

        // 整页刷新：再发一次 HTTP 请求（浏览器刷新 = 新请求，无 sid 传递）
        let r2 = client.get("http://127.0.0.1:${AppStateRefreshE2ETest.port}/rp")
        let h2 = StringReader(r2.body).readToEnd()
        r2.close()
        let sid2 = match (extractSid(h2)) {
            case Some(s) => s
            case None => ""
        }
        @Expect(sid2.size > 0, true)

        // 关键断言：新会话的 AppState 是全新实例（值回到 0），不是 42
        println("[rp] sid1=${sid1} sid2=${sid2} sidChanged=${sid1 != sid2}")
        let val2 = match (app.sessions.get(sid2)) {
            case Some(sess) =>
                match (sess.states.get(TypeInfo.of<RefreshProbeState>().qualifiedName)) {
                    case Some(s: RefreshProbeState) =>
                        match (s.hits.get()) {
                            case v => v
                        }
                    case _ => Int64(-1)
                }
            case None => Int64(-2)
        }
        app.stop()
        // 整页刷新 → 新 session → AppState 重置
        @Expect(val2, 0)
    }
}

func extractSid(html: String): Option<String> {
    let marker = "new CangjieUI("
    let at = match (html.indexOf(marker)) {
        case Some(i) => i
        case None => return None
    }
    var i = at + marker.size
    var first = -1
    while (i < html.size) {
        if (Int64(html[i]) == 34) {
            if (first < 0) {
                first = i
            } else {
                return Some(html[(first + 1)..i])
            }
        }
        i++
    }
    None
}
