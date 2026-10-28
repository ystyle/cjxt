// 包级 Signal 作为跨组件 / 跨页面共享状态（回归）
//
// 契约：包级 `let` 上定义的 `Signal` 是所有组件共享的同一份状态——
// 一个组件的 handler 写它，**另一个页面**上读它的组件会收到补丁。
//
// 判据依据：包级 Signal 本身就能承担跨组件/跨页面共享，
// 不需要额外的"状态容器"类型（早期曾有 Store<S>，因其能力被 Signal 完全覆盖且
// 接不进组件的 bind()，已移除）。
package cjxt

import std.collection.{ArrayList, HashMap}
import std.io.StringReader
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.url.URL
import stdx.net.http.{Client, ClientBuilder, WebSocket, WebSocketFrameType}
import stdx.net.http.WebSocketFrame

// 包级共享状态：进程内所有会话共用同一份（"全局"的唯一写法）
let e2eSharedCount = Signal<Int64>(0)
// 派生状态：由源信号算出来（Computed 的能力，非 Signal 单独可比）
let e2eSharedDouble = Computed<Int64>({ => e2eSharedCount.get() * 2 })

class XCompPageA <: Component {
    public init() {}

    public func render(): IComponent {
        let handler: ActionHandler = { _ =>
            e2eSharedCount.set(e2eSharedCount.get() + 1)
            PatchResult.ReRender
        }
        div([
            span([text("A-count=${e2eSharedCount.get()},double=${e2eSharedDouble.get()}")]),
            VNode("button", [text("加一")]).onClick(handler)
        ], attrs: Some(HashMap<String, String>([("class", "xc-page-a")])))
    }
}

class XCompPageB <: Component {
    public init() {}

    // 注意：B 只是**读**，没有写入口——写发生在 A 的 handler 里
    public func render(): IComponent {
        div([
            span([text("B-count=${e2eSharedCount.get()},double=${e2eSharedDouble.get()}")])
        ], attrs: Some(HashMap<String, String>([("class", "xc-page-b")])))
    }
}

@Test
public class XCompSignalE2ETest {
    static var port: UInt16 = 18152

    @TestCase
    public func testPackageLevelSignalSharedAcrossPages(): Unit {
        e2eSharedCount.set(0)
        let registry = RouteRegistry.global()
        registry.register("/", { => XCompPageB() })
        registry.register("/xc-a", { => XCompPageA() })
        registry.register("/xc-b", { => XCompPageB() })

        let app = App().host("127.0.0.1").port(XCompSignalE2ETest.port)
        spawn {
            try {
                app.serve()
            } catch (_: Exception) {
                ()
            }
        }
        sleep(Duration.millisecond * 300)

        let sid = "e2e-xcomp-1"
        var ws: WebSocket
        let client = ClientBuilder().build()
        try {
            let (w, _) = WebSocket.upgradeFromClient(client,
                URL.parse("ws://127.0.0.1:${XCompSignalE2ETest.port}/ws"))
            ws = w
        } catch (_: Exception) {
            app.stop()
            @Expect(false, true)
            return
        }
        ws.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"${sid}\"}".toArray())
        let _ = ws.read() // connected
        let _ = ws.read() // 初始整树

        // 导航到 A：A 读共享 Signal
        ws.write(WebSocketFrameType.TextWebFrame,
            "{\"type\":\"navigate\",\"path\":\"/xc-a\",\"sessionId\":\"${sid}\"}".toArray())
        let treeA = readOne(ws)
        @Expect(treeA.contains("A-count=0"), true)

        // 触发 A 的 handler（走真实 WS action，与浏览器点击同一条链路）
        let actId = extractActionId(treeA, "加一", "click")
        if (actId == "") {
            println("[E2E-xcomp] 未能在树里找到 加一 的 click handler")
            ws.closeConn()
            app.stop()
            @Expect(false, true)
            return
        }
        ws.write(WebSocketFrameType.TextWebFrame,
            "{\"type\":\"action\",\"name\":\"${actId}\",\"params\":{},\"sessionId\":\"${sid}\"}".toArray())
        let patchA = readOne(ws)
        @Expect(patchA.contains("A-count=1"), true)

        // 导航到 B：**另一个页面**上读同一个 Signal，应看到 A 写进去的值
        ws.write(WebSocketFrameType.TextWebFrame,
            "{\"type\":\"navigate\",\"path\":\"/xc-b\",\"sessionId\":\"${sid}\"}".toArray())
        let treeB = readOne(ws)
        @Expect(treeB.contains("B-count=1"), true)
        // Computed 也跟着重算（跨组件的派生状态可用）
        @Expect(treeB.contains("double=2"), true)

        ws.closeConn()
        app.stop()
    }

    // 读一帧（带超时；超时返回空串）
    private func readOne(ws: WebSocket): String {
        let done = Box<Bool>(false)
        let got = Box<String>("")
        spawn {
            try {
                got.value = String.fromUtf8(ws.read().payload)
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
        got.value
    }

    // 读若干帧拼起来（整树/补丁可能分帧；等到没有新帧为止）
    private func readSome(ws: WebSocket): String {
        var joined = ""
        for (_ in 0..3) {
            let done = Box<Bool>(false)
            let got = Box<String>("")
            spawn {
                try {
                    got.value = String.fromUtf8(ws.read().payload)
                } catch (_: Exception) {
                    ()
                }
                done.value = true
            }
            var waited = 0
            while (!done.value && waited < 2000) {
                sleep(Duration.millisecond * 20)
                waited += 20
            }
            if (!done.value) {
                break
            }
            joined += got.value
        }
        joined
    }
}

/** 从整树 JSON 里取第一个 button 的 click handler id（值是 `h:<path>:click` 形式） */
func extractActionId(json: String, marker: String, ev: String): String {
    // 定位含 marker 的那个元素：先找 marker，再往前找它所属元素的 actions
    let at = match (json.indexOf(marker)) {
        case Some(i) => i
        case None => return ""
    }
    // 元素结构固定为 ..."actions":{"<ev>":"<id>"},"children":[...marker...]
    // 所以在 marker 之前、最近的一次 `"<ev>":"` 就是它的 handler
    let key = "\"${ev}\":\""
    var j = 0
    var hit = -1
    while (j < at) {
        match (json.indexOf(key, j)) {
            case Some(i) =>
                if (i >= at) {
                    break
                }
                hit = i
                j = i + key.size
            case None => break
        }
    }
    if (hit < 0) {
        return ""
    }
    var k = hit + key.size
    var end = -1
    while (k < json.size) {
        if (Int64(json[k]) == 34) {
            end = k
            break
        }
        k++
    }
    if (end < 0) {
        return ""
    }
    json[(hit + key.size)..end]
}
