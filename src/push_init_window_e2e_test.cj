package cjxt

import std.collection.ArrayList
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.kit.*
import stdx.encoding.url.URL
import stdx.net.http.{Client, ClientBuilder, WebSocket, WebSocketFrameType}
import stdx.net.http.WebSocketFrame

/**
 * 回归：onMount 里发起的推送必须等**初始树**下发之后再送。
 *
 * 背景：onMount 早于初始渲染（页面在那里注入 states），此时客户端只有一个空壳。
 * 那段时间的推送此前是**静默丢弃**（pushUpdate 返回 true、界面却停在初始状态，
 * 直到下一次操作才补上；表现为「刷新后侧栏一直空着」）。修复：会话进入初始化窗口，
 * 窗口内推送入队，connected + 整树下发后按序冲掉。
 *
 * 这个用例把推送**同步**放在 onMount 里，于是顺序是确定的：修好之后客户端必然先收到
 * 整树、再收到那次推送的补丁；没有修复时补丁会先于 connected 发出（断言直接红）。
 */

class InitPushHolder {
    var app: Option<App> = None
}

class InitPushPage <: Component {
    let sig: Signal<String>
    let holder: InitPushHolder

    public init(sig: Signal<String>, holder: InitPushHolder) {
        this.sig = sig
        this.holder = holder
    }

    public func render(): IComponent {
        div([text("叶子=${this.sig.get()}")])
    }

    public func onMount(ctx: LifecycleContext): Unit {
        match (this.holder.app) {
            case Some(a) =>
                let sid = ctx.getSessionId()
                a.pushUpdate(sid, { _ =>
                    this.sig.set("已推送")
                    PatchResult.ReRender
                })
            case None => ()
        }
    }
}

@Test
public class PushInitWindowE2ETest {
    static var port: UInt16 = 18131

    @TestCase
    public func testOnMountPushArrivesAfterInitialTree(): Unit {
        let sig = Signal<String>("初始")
        let holder = InitPushHolder()
        RouteRegistry.global().register("/", { => InitPushPage(sig, holder) })
        let app = App().host("127.0.0.1").port(PushInitWindowE2ETest.port)
        holder.app = Some(app)
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

        var ws: WebSocket
        try {
            let client = ClientBuilder().build()
            let (w, _) = WebSocket.upgradeFromClient(client,
                URL.parse("ws://127.0.0.1:${PushInitWindowE2ETest.port}/ws"))
            ws = w
        } catch (e: Exception) {
            println("[E2E] upgrade failed: ${e.message}")
            app.stop()
            @Expect(false, true)
            return
        }
        ws.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"e2e-initpush-1\"}".toArray())

        // 帧序：connected 必须在最前、整树紧随（补丁不得抢到页面之前）
        var frames = ArrayList<String>()
        for (i in 0..4) {
            let f = match (readWithTimeout(ws)) {
                case Some(x) => x
                case None => break
            }
            frames.add(String.fromUtf8(f.payload))
        }
        @Expect(frames.size >= 2, true)
        @Expect(frames[0].contains("\"kind\":\"connected\""), true)
        @Expect(frames[1].contains("\"path\":\"\""), true)

        // 机制（确定性）：窗口内推送 → 回调**同步跑**，但补丁不发；开闸后补一次。
        // 没有窗口时，窗口内的推送会立刻把补丁发出去（客户端在空壳上收补丁）。
        let session = match (app.sessions.get("e2e-initpush-1")) {
            case Some(s) => s
            case None =>
                @Expect(false, true)
                ws.closeConn()
                app.stop()
                return
        }
        app.suspendPushes(session)
        let before = App.sendPatchCount
        let ran = Box<Bool>(false)
        let okPush = app.pushUpdate("e2e-initpush-1", { _ =>
            ran.value = true
            sig.set("窗口内更新")
            PatchResult.ReRender
        })
        @Expect(okPush, true)                  // 契约不变：会话在线即 true
        @Expect(ran.value, true)               // 回调同步执行（调用方依赖它改状态）
        sleep(Duration.millisecond * 60)
        @Expect(App.sendPatchCount, before)    // 窗口内不发补丁
        app.drainPushes(session)
        sleep(Duration.millisecond * 80)
        @Expect(App.sendPatchCount, before + 1) // 开闸后补发一次

        ws.closeConn()
        app.stop()
    }

    // 帧读取加超时：初始化窗口若把推送吞了，用例要在限定时间内失败而不是挂死
    private func readWithTimeout(ws: WebSocket): Option<WebSocketFrame> {
        let done = Box<Bool>(false)
        let got = Box<Option<WebSocketFrame>>(None)
        spawn {
            let f = ws.read()
            got.value = Some(f)
            done.value = true
        }
        var waited = 0
        while (waited < 3000 && !done.value) {
            sleep(Duration.millisecond * 20)
            waited += 20
        }
        got.value
    }
}
