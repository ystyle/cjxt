package cjxt

import std.fs.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.kit.*
import stdx.encoding.url.URL
import stdx.net.http.{Client, ClientBuilder, WebSocket, WebSocketFrameType}
import std.collection.ArrayList

// 端到端：WS 二进制帧流式上传
//   1) upload_begin → 二进制分块（两个 message）→ upload_progress ack → 文件落盘 & 内容一致
//   2) 没有开始帧直接发二进制 → upload_error("no active upload")
//   3) begin 后发超限字节 → upload_error("size exceeded") + 半成品文件被删除
// 需要真实 WS 客户端（upgradeFromClient → SHA1 digest），依赖 target 级 link-option。

@Test
public class UploadE2ETest {
    static var port: UInt16 = 18124

    // 读一个文本帧（跳过控制帧；Ping 回 Pong）
    func readText(ws: WebSocket): String {
        let f = ws.read()
        match (f.frameType) {
            case TextWebFrame => String.fromUtf8(f.payload)
            case PingWebFrame =>
                ws.writePongFrame(ArrayList<UInt8>().toArray())
                this.readText(ws)
            case _ => this.readText(ws)
        }
    }

    @TestCase
    public func testBinaryUploadFullFlow(): Unit {
        let dir = Directory.createTemp("/tmp")
        let dirStr = dir.toString()
        RouteRegistry.global().register("/", { => div([text("upload-e2e")]) })
        let app = App().host("127.0.0.1").port(UploadE2ETest.port).serveUpload("/_cjxt/up", dirStr)
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
                println("[UPLOAD-E2E] serve error: ${e.message}")
                return
            case None => ()
        }

        // 连接 WS → 建会话
        var ws: WebSocket
        try {
            let client = ClientBuilder().build()
            let (w, _) = WebSocket.upgradeFromClient(client, URL.parse("ws://127.0.0.1:${UploadE2ETest.port}/ws"))
            ws = w
        } catch (e: Exception) {
            println("[UPLOAD-E2E] upgrade failed: ${e.message}")
            app.stop()
            @Expect(false, true) // 连接失败
            return
        }
        ws.write(WebSocketFrameType.TextWebFrame, "{\"sessionId\":\"up-e2e-1\"}".toArray())
        let _c = this.readText(ws) // connected
        let _t = this.readText(ws) // full tree

        // ============ 场景 2：没有开始帧直接发二进制 → error ============
        ws.write(WebSocketFrameType.BinaryWebFrame, "hello".toArray())
        let e1 = this.readText(ws)
        @Expect(e1.contains("\"no active upload\""), true)

        // ============ 场景 3：begin 后超限 → error + 半成品删除 ============
        ws.write(WebSocketFrameType.TextWebFrame, "{\"type\":\"upload_begin\",\"id\":\"u3\",\"name\":\"over.txt\",\"size\":5,\"action\":\"h:e2e:uploaded\"}".toArray())
        ws.write(WebSocketFrameType.BinaryWebFrame, "0123456789".toArray())
        let e2 = this.readText(ws)
        @Expect(e2.contains("\"size exceeded\""), true)
        @Expect(e2.contains("\"u3\""), true)
        @Expect(Directory.isEmpty(dirStr), true) // 半成品已删除

        // ============ 场景 1：完整流式上传（两块 message） ============
        ws.write(WebSocketFrameType.TextWebFrame, "{\"type\":\"upload_begin\",\"id\":\"u1\",\"name\":\"z.txt\",\"size\":11,\"action\":\"h:e2e:uploaded\"}".toArray())
        ws.write(WebSocketFrameType.BinaryWebFrame, "hello ".toArray())
        let p1 = this.readText(ws)
        @Expect(p1.contains("\"upload_progress\""), true)
        @Expect(p1.contains("\"received\":6"), true)
        ws.write(WebSocketFrameType.BinaryWebFrame, "world".toArray())
        let p2 = this.readText(ws)
        @Expect(p2.contains("\"received\":11"), true)

        // 文件落盘 & 内容一致（nextId()-z.txt）
        let infos = Directory.readFrom(dirStr)
        @Expect(infos.size, 1)
        let fname = infos[0].name
        @Expect(fname.endsWith("z.txt"), true)
        let bytes = File.readFrom("${dirStr}/${fname}")
        @Expect(bytes.size, 11)
        @Expect(String.fromUtf8(bytes), "hello world")

        // 服务端 dispatch action（h:e2e:uploaded 无 handler → no-op，不崩溃）
        // 完成帧之后再收不到 upload_progress/upload_error（上传已结束）

        ws.closeConn()
        app.stop()
        // 清理临时目录
        try {
            removeIfExists(dir, recursive: true)
        } catch (e: Exception) {
            ()
        }
    }
}
