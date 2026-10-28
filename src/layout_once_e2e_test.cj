// Layout 包裹次数（回归）
//
// 契约：`@Page` 的 layout 函数**只被套一次**。
//
// 曾经的缺陷：`resumeSession` 里对 `session.tree` 又调了一次 `applyLayout`，
// 而 HTTP 首渲那条路径渲染时已经套过。于是 WS 连接后页面被 layout 包两层 ——
// 侧栏/菜单出现两遍。
//
// 为什么长期没被发现：示例站没注册过 layout；本工作区的实际应用
// （atelier-lumine）为了绕开这个问题，改成自己在页面里包一层 shell，
// 从没用过 `@Page` 的第四参数。也就是说这个功能实际上处于"没人用 → 没人验"的状态。
//
// 断言方式：layout 里塞一个唯一 class 的 div，数它在整树 JSON 里出现的次数。
package cjxt

import std.collection.{ArrayList, HashMap}
import std.io.StringReader
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.kit.*
import stdx.encoding.url.URL
import stdx.net.http.{Client, ClientBuilder, WebSocket, WebSocketFrameType}
import stdx.net.http.WebSocketFrame

class LayoutProbePage <: Component {
    public init() {}

    public func render(): IComponent {
        div([text("页面内容")], attrs: Some(HashMap<String, String>([("class", "probe-page-body")])))
    }
}

@Test
public class LayoutOnceE2ETest {
    static var port: UInt16 = 18151

    @TestCase
    public func testLayoutAppliedExactlyOnceAfterWsResume(): Unit {
        // layout：给页面套一层带唯一标记的壳
        let layoutFn: LayoutFn = { raw: IComponent =>
            div([raw], attrs: Some(HashMap<String, String>([("class", "probe-layout-shell")])))
        }
        let guardFn: GuardFn = { _: HashMap<String, String> => None }
        RouteRegistry.global().register("/layout-once", { => LayoutProbePage() },
            "布局测试", guardFn, layoutFn)

        // 确认注册成功（否则后面的断言在测空气）
        match (RouteRegistry.global().getLayout("/layout-once")) {
            case Some(_) => ()
            case None => println("[E2E-layout] getLayout 未命中")
        }
        let app = App().host("127.0.0.1").port(LayoutOnceE2ETest.port)
        spawn {
            try {
                app.serve()
            } catch (_: Exception) {
                ()
            }
        }
        sleep(Duration.millisecond * 300)

        // HTTP 首渲：拿到 sessionId（WS 要用它恢复同一个会话）
        let client = ClientBuilder().build()
        let resp = client.get("http://127.0.0.1:${LayoutOnceE2ETest.port}/layout-once")
        let html = StringReader(resp.body).readToEnd()
        let status = resp.status
        println("[E2E-layout] 含 probe-page-body: ${countOf(html, "probe-page-body")}")
        resp.close()

        // 首渲的 HTML 里 layout 壳只该出现一次
        @Expect(countOf(html, "probe-layout-shell"), 1)

        // 从 HTML 里取 sessionId（形如 new CangjieUI(el, "01ABC...", ...)）
        let sid = match (extractSessionId(html)) {
            case Some(s) => s
            case None => ""
        }
        if (sid == "") {
            app.stop()
            @Expect(false, true)
            return
        }

        // WS 连接并恢复该会话：服务端会重算一遍树下发
        var ws: WebSocket
        try {
            let (w, _) = WebSocket.upgradeFromClient(client,
                URL.parse("ws://127.0.0.1:${LayoutOnceE2ETest.port}/ws"))
            ws = w
        } catch (_: Exception) {
            app.stop()
            @Expect(false, true)
            return
        }
        ws.write(WebSocketFrameType.TextWebFrame,
            "{\"sessionId\":\"${sid}\",\"token\":\"\"}".toArray())

        // 收集若干帧，找整树下发那一帧
        var joined = ""
        for (i in 0..4) {
            let f = match (readFrame(ws)) {
                case Some(x) => x
                case None => break
            }
            joined += String.fromUtf8(f.payload)
        }
        // 关键断言：恢复会话后若服务端下发整树，layout 壳仍然只出现一次。
        //
        // 注意「可能不下发」是**正常**的：首屏已内联整树、且本次连接没有改变它时，
        // resumeSession 会跳过整树下发（inlinedMatches 分支，避免白丢焦点/滚动位置）。
        // 所以这里只能断言「要么没下发、要么恰好一份」，不能强求出现一次。
        // 缺陷版本（resume 二次 applyLayout）下指纹永远对不上 → 必然下发且是两份。
        let shellN = countOf(joined, "probe-layout-shell")
        @Expect(shellN == 0 || shellN == 1)

        ws.closeConn()
        app.stop()
    }

    private func readFrame(ws: WebSocket): Option<WebSocketFrame> {
        let done = Box<Bool>(false)
        let out = Box<Option<WebSocketFrame>>(None)
        spawn {
            try {
                let f = ws.read()
                out.value = Some(f)
            } catch (_: Exception) {
                ()
            }
            done.value = true
        }
        var waited = 0
        while (!done.value && waited < 3000) {
            sleep(Duration.millisecond * 20)
            waited += 20
        }
        out.value
    }
}

/** 数 needle 出现次数 */
func countOf(hay: String, needle: String): Int64 {
    var n: Int64 = 0
    var i = 0
    while (true) {
        match (hay.indexOf(needle, i)) {
            case Some(at) =>
                n++
                i = at + needle.size
            case None => break
        }
    }
    n
}

/** 从 HTML 里取 `new CangjieUI(el, "<sid>"` 的 sid */
func extractSessionId(html: String): Option<String> {
    let marker = "new CangjieUI("
    let at = match (html.indexOf(marker)) {
        case Some(i) => i
        case None => return None
    }
    // 往后找第一对双引号
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
