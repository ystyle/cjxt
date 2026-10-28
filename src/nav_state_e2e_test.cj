// 判据核心：AppState 与「页面实例字段」的真正差别在哪？
// ① 跨导航（navigate）：页面换新实例，AppState 还在吗？
// ② 整页刷新：两者都重置（已验证）
package cjxt

import std.collection.{ArrayList, HashMap}
import std.time.*
import std.reflect.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.url.URL
import stdx.net.http.{Client, ClientBuilder, WebSocket, WebSocketFrameType}
import stdx.net.http.WebSocketFrame

class NavProbeState <: AppState {
    public var count = Signal<Int64>(0)
}

// 页面实例字段：每次导航都会新建实例
class NavPageX <: Component {
    public init() {}
    public func render(): IComponent {
        div([text("pageX")], attrs: Some(HashMap<String, String>([("class", "navx")])))
    }
}

class NavPageY <: Component {
    public init() {}
    public func render(): IComponent {
        div([text("pageY")], attrs: Some(HashMap<String, String>([("class", "navy")])))
    }
}

@Test
public class NavStateE2ETest {
    static var port: UInt16 = 18155

    @TestCase
    public func testAppStateSurvivesNavigation(): Unit {
        let registry = RouteRegistry.global()
        registry.register("/", { => NavPageX() })
        registry.register("/navx", { => NavPageX() })
        registry.register("/navy", { => NavPageY() })

        let app = App().host("127.0.0.1").port(NavStateE2ETest.port)
            .state<NavProbeState>({ => NavProbeState() })
        spawn {
            try { app.serve() } catch (_: Exception) { () }
        }
        sleep(Duration.millisecond * 300)

        let sid = "nav-probe-1"
        let client = ClientBuilder().build()
        let (ws, _) = WebSocket.upgradeFromClient(client,
            URL.parse("ws://127.0.0.1:${NavStateE2ETest.port}/ws"))
        ws.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"${sid}\"}".toArray())
        sleep(Duration.millisecond * 200)

        // 写 AppState
        match (app.sessions.get(sid)) {
            case Some(sess) =>
                match (sess.states.get(TypeInfo.of<NavProbeState>().qualifiedName)) {
                    case Some(st: NavProbeState) => st.count.set(77)
                    case _ => ()
                }
            case None => ()
        }

        // 导航到另一个页面
        ws.write(WebSocketFrameType.TextWebFrame,
            "{\"type\":\"navigate\",\"path\":\"/navy\",\"sessionId\":\"${sid}\"}".toArray())
        sleep(Duration.millisecond * 300)

        // 导航后 AppState 还在吗？
        let afterNav = match (app.sessions.get(sid)) {
            case Some(sess) =>
                match (sess.states.get(TypeInfo.of<NavProbeState>().qualifiedName)) {
                    case Some(st: NavProbeState) => st.count.get()
                    case _ => Int64(-1)
                }
            case None => Int64(-2)
        }
        // 导航后页面实例换了吗？
        let pageChanged = match (app.sessions.get(sid)) {
            case Some(sess) => match (sess.page) { case p: NavPageY => true case _ => false }
            case None => false
        }
        app.stop()
        @Expect(afterNav, 77)          // AppState 跨导航存活
        @Expect(pageChanged, true)     // 页面换成了新实例
    }
}
