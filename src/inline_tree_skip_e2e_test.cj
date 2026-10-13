package cjxt

import std.collection.ArrayList
import std.io.StringReader
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.url.URL
import stdx.net.http.{Client, ClientBuilder, WebSocket, WebSocketFrameType}
import stdx.net.http.WebSocketFrame

/**
 * 内联首屏的整树去重（真实 HTTP + WS）。
 *
 * 契约：HTTP 首屏已经把初始树内联进 HTML（`__CJXT_INITIAL_TREE__`），因此后续
 * WS 连上时，只要服务端待发树与内联那棵一致，就**不得**再下发一遍整树——
 * 否则页面刚渲染完就被整棵替换，丢掉焦点/滚动位置与客户端组件局部状态。
 *
 * 反向也要钉住：没有内联基线的连接（直接连 WS、没有走 HTTP）必须照常收到整树，
 * 否则页面会停在空壳上。两条断言一起才说明"去重靠的是指纹比对"，而不是"干脆不发了"。
 */
@Test
public class InlineTreeSkipE2ETest {
    static var port: UInt16 = 18141

    @TestCase
    public func testInlinedSessionSkipsDuplicateTree(): Unit {
        RouteRegistry.global().register("/", { => div([text("inline-skip")]) })
        let app = App().host("127.0.0.1").port(InlineTreeSkipE2ETest.port)
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
                @Expect(false, true)
                return
            case None => ()
        }

        // ── 1) 走 HTTP 首屏：拿到内联树与其中的会话 id ──
        let html = fetchPage("/")
        @Expect(html.contains("__CJXT_INITIAL_TREE__ = "), true)
        let sid = extractShellSessionId(html)
        @Expect(sid != "", true)

        // ── 2) 用同一个会话 id 连 WS：只应收到 connected，不应再收到整树 ──
        let ws = upgrade(InlineTreeSkipE2ETest.port)
        ws.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"${sid}\"}".toArray())
        let frames = readFrames(ws, 3)
        @Expect(frames.size >= 1, true)
        @Expect(frames[0].contains("\"kind\":\"connected\""), true)
        var gotTree = false
        for (i in 0..frames.size) {
            if (i == 0) { continue }
            if (frames[i].contains("\"kind\":\"patch\"") || frames[i].contains("\"kind\":\"fullTree\"")) {
                gotTree = true
            }
        }
        @Expect(gotTree, false)
        ws.closeConn()
        app.stop()
    }

    // 反例：不经 HTTP 首屏直连 WS（无内联基线）→ 必须照常收到整树
    @TestCase
    public func testSessionWithoutInlineStillReceivesTree(): Unit {
        RouteRegistry.global().register("/", { => div([text("no-inline")]) })
        let app = App().host("127.0.0.1").port(InlineTreeSkipE2ETest.port + 1)
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
                @Expect(false, true)
                return
            case None => ()
        }

        let ws = upgrade(InlineTreeSkipE2ETest.port + 1)
        ws.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"e2e-no-inline\"}".toArray())
        let frames = readFrames(ws, 3)
        @Expect(frames.size >= 2, true)
        @Expect(frames[0].contains("\"kind\":\"connected\""), true)
        @Expect(frames[1].contains("\"kind\":\"patch\"") || frames[1].contains("\"kind\":\"fullTree\""), true)
        ws.closeConn()
        app.stop()
    }

    // ── helpers ──

    private func upgrade(port: UInt16): WebSocket {
        let client = ClientBuilder().build()
        let (w, _) = WebSocket.upgradeFromClient(client, URL.parse("ws://127.0.0.1:${port}/ws"))
        w
    }

    private func readFrames(ws: WebSocket, max: Int64): ArrayList<String> {
        let out = ArrayList<String>()
        for (_ in 0..max) {
            match (readWithTimeout(ws)) {
                case Some(f) => out.add(String.fromUtf8(f.payload))
                case None => break
            }
        }
        out
    }

    /// 读一帧（带超时）：读线程可能在超时后才返回，因此不能让 it 阻塞测试线程
    private func readWithTimeout(ws: WebSocket): Option<WebSocketFrame> {
        let done = Box<Bool>(false)
        let got = Box<Option<WebSocketFrame>>(None)
        spawn {
            try {
                let f = ws.read()
                got.value = Some(f)
            } catch (e: Exception) {
                got.value = None
            }
            done.value = true
        }
        var waited = 0
        while (waited < 3000 && !done.value) {
            sleep(Duration.millisecond * 20)
            waited += 20
        }
        got.value
    }

    private func fetchPage(path: String): String {
        let client = ClientBuilder().build()
        let resp = client.get("http://127.0.0.1:${InlineTreeSkipE2ETest.port}${path}")
        let text = StringReader(resp.body).readToEnd()
        client.close()
        text
    }

    /// 从首屏 HTML 的 `new CangjieUI(..., "sid", ...)` 里取会话 id
    private func extractShellSessionId(html: String): String {
        let marker = "document.getElementById('app'), \""
        match (html.indexOf(marker, 0)) {
            case Some(i) =>
                let from = i + marker.size
                match (html.indexOf("\"", from)) {
                    case Some(j) => html[from..j]
                    case None => ""
                }
            case None => ""
        }
    }
}
