package cjxt

import std.collection.{ArrayList, HashMap}
import std.convert.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.kit.*
import stdx.encoding.url.URL
import stdx.net.http.{Client, ClientBuilder, WebSocket, WebSocketFrameType}

// 端到端：事件驱动 DOM 事务——服务端发 dom_command → 客户端执行 → 回 dom_result →
// 服务端 dispatchDomResult 跑续体 → 补丁。证明"基于事件处理"的完整闭环。

class DomTxPage <: Component {
    let out: Signal<Int64>
    public init(out: Signal<Int64>) {
        this.out = out
    }
    public func render(): IComponent {
        let h: ActionHandler = { ctx =>
            match (ctx.dom) {
                case Some(d) =>
                    d.query("domtx-panel", "offsetHeight") { results =>
                        var v = 0
                        match (results.get("r1")) {
                            case Some(s) => v = Int64.parse(s, radix: 10)
                            case None => ()
                        }
                        this.out.set(v)
                        PatchResult.ReRender
                    }
                case None => ()
            }
            PatchResult.ReRender
        }
        div([
            VNode("div", [text("v=${this.out.get()}")], attrs: Some(HashMap<String, String>([("class", "dom-tx-panel")]))).ref("domtx-panel"),
            VNode("button", [text("查询")], attrs: Some(HashMap<String, String>([("type", "button")]))).onClick(h),
        ])
    }
}

@Test
public class DomTransactionE2ETest {
    static var port: UInt16 = 18131
    static var seqPort: UInt16 = 18132

    @TestCase
    public func testQueryRoundTrip(): Unit {
        let out = Signal<Int64>(0)
        RouteRegistry.global().register("/", { => DomTxPage(out) })
        App.sendPatchCount = 0
        let app = App().host("127.0.0.1").port(DomTransactionE2ETest.port)
        spawn { app.serve() }
        sleep(Duration.millisecond * 300)
        
        var ws: WebSocket
        try {
            let client = ClientBuilder().build()
            let (w, _) = WebSocket.upgradeFromClient(client, URL.parse("ws://127.0.0.1:${DomTransactionE2ETest.port}/ws"))
            ws = w
        } catch (e: Exception) {
            app.stop()
            @Expect(false, true) // 连接失败
            return
        }
        ws.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"dom-e2e-1\"}".toArray())
        let f1 = ws.read() // connected
        let f2 = ws.read() // full tree
        
        // 找"查询"按钮 action id：VNode.toJson 顺序是 attrs→actions→children，
        // 所以按钮 click action 在"查询"文本之前 → 搜前缀里最后一个 "click":" 提取
        var queryId = ""
        let treeJson = String.fromUtf8(f2.payload)
        match (treeJson.indexOf("查询")) {
            case Some(qi) =>
                let prefix = treeJson[0..qi]
                match (prefix.lastIndexOf("\"click\":\"")) {
                    case Some(ci) => queryId = extractQuotedAfter(prefix[ci..], "\"click\":\"")
                    case None => ()
                }
            case None => ()
        }

        // 触发查询 action
        ws.write(WebSocketFrameType.TextWebFrame, "{\"type\":\"action\",\"name\":\"${queryId}\",\"params\":{},\"sessionId\":\"dom-e2e-1\"}".toArray())
        // 读 dom_command
        var gotDomCommand = false
        var txId = ""
        var gotPatch42 = false
        for (i in 0..8) {
            let f = ws.read()
            let text = String.fromUtf8(f.payload)
            if (text.contains("\"kind\":\"dom_command\"")) {
                gotDomCommand = true
                // 提取 txId
                txId = extractQuotedAfter(text, "\"txId\":\"")
                // 前端执行后回 dom_result（模拟 offsetHeight=42）
                if (txId != "") {
                    ws.write(WebSocketFrameType.TextWebFrame, "{\"type\":\"dom_result\",\"txId\":\"${txId}\",\"results\":{\"r1\":\"42\"},\"sessionId\":\"dom-e2e-1\"}".toArray())
                }
            }
            if (text.contains("\"kind\":\"patch\"") && text.contains("v=42")) {
                gotPatch42 = true
                break
            }
        }
        ws.closeConn()
        app.stop()
        @Expect(gotDomCommand, true) // 收到 dom_command
        @Expect(gotPatch42, true)    // 续体跑完 → out=42 → 补丁
    }
}


// 在 text 中查找 key 后的带引号值（key 以 \" 结尾，值到下一个 \" 为止；ASCII 值安全字节切片）
func extractQuotedAfter(text: String, key: String): String {
    match (text.indexOf(key)) {
        case Some(start) =>
            let after = text[start + key.size..]
            var end = 0
            var found = false
            for (i in 0..after.size) {
                if (after[i] == 34u8) { end = i; found = true; break }
            }
            if (found) { after[0..end] } else { "" }
        case None => ""
    }
}



// 超时兜底 e2e：客户端不回 dom_result → seq.timeout 到点触发续体 → 补丁
class DomTimeoutPage <: Component {
    let out: Signal<String>
    public init(out: Signal<String>) {
        this.out = out
    }
    public func render(): IComponent {
        let h: ActionHandler = { ctx =>
            match (ctx.dom) {
                case Some(d) =>
                    let seq = d.seq()
                    seq.queryInt64("t-a", "offsetHeight") { h => () } // 不回 → 触发超时
                    seq.timeout(300, { =>
                        this.out.set("timeout")
                        PatchResult.ReRender
                    })
                case None => ()
            }
            PatchResult.ReRender
        }
        div([
            VNode("div", [text("s=${this.out.get()}")], attrs: Some(HashMap<String, String>([("class", "t-a")]))).ref("t-a"),
            VNode("button", [text("超时测试")], attrs: Some(HashMap<String, String>([("type", "button")]))).onClick(h),
        ])
    }
}

@Test
public class DomTimeoutE2ETest {
    static var port: UInt16 = 18133

    @TestCase
    public func testTimeoutFires(): Unit {
        let out = Signal<String>("init")
        RouteRegistry.global().register("/", { => DomTimeoutPage(out) })
        let app = App().host("127.0.0.1").port(DomTimeoutE2ETest.port)
        spawn { app.serve() }
        sleep(Duration.millisecond * 300)

        var ws: WebSocket
        try {
            let client = ClientBuilder().build()
            let (w, _) = WebSocket.upgradeFromClient(client, URL.parse("ws://127.0.0.1:${DomTimeoutE2ETest.port}/ws"))
            ws = w
        } catch (e: Exception) {
            app.stop()
            @Expect(false, true)
            return
        }
        ws.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"timeout-e2e-1\"}".toArray())
        let f1 = ws.read()
        let f2 = ws.read()
        let treeJson = String.fromUtf8(f2.payload)

        // 找"超时测试"按钮 action
        var actId = ""
        match (treeJson.indexOf("超时测试")) {
            case Some(qi) =>
                let prefix = treeJson[0..qi]
                match (prefix.lastIndexOf("\"click\":\"")) {
                    case Some(ci) => actId = extractQuotedAfter(prefix[ci..], "\"click\":\"")
                    case None => ()
                }
            case None => ()
        }
        if (actId == "") { ws.closeConn(); app.stop(); throw Exception("actId extraction failed") }

        // 触发 → 收到 dom_command（不回）→ 等超时补丁（s=timeout）
        ws.write(WebSocketFrameType.TextWebFrame, "{\"type\":\"action\",\"name\":\"${actId}\",\"params\":{},\"sessionId\":\"timeout-e2e-1\"}".toArray())
        var gotCmd = false
        var gotTimeoutPatch = false
        for (i in 0..6) {
            let f = ws.read()
            let text = String.fromUtf8(f.payload)
            if (text.contains("\"kind\":\"dom_command\"")) { gotCmd = true } // 不回
            if (text.contains("\"kind\":\"patch\"") && text.contains("s=timeout")) {
                gotTimeoutPatch = true
                break
            }
        }
        ws.closeConn()
        app.stop()
        @Expect(gotCmd, true)
        @Expect(gotTimeoutPatch, true) // 超时续体跑 → 补丁
    }
}
