package cjxt

import std.collection.ArrayList
import std.io.ByteBuffer
import std.overflow.*
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}
import stdx.net.http.{WebSocket, WebSocketFrameType}

/**
 * 页面出站通道（服务端 → 页面）。
 *
 * 框架原先把 `WebSocket` 硬编码进会话与全部下发路径，于是"页面怎么收到数据包"
 * 被绑死在一条 WS 连接上：没有监听端口就没有页面，也没法把同一套渲染结果交给
 * 别的宿主（WebView 绑定、静态内联、测试替身）。
 *
 * 抽象成 sink 之后，会话只认"能把文本/二进制交给页面"这件事：
 * - `WebSocketSink`：浏览器场景，写 WS 文本/二进制帧；
 * - `BufferSink`：无连接场景（宿主绑定 / 静态内联 / 单测），把出站包攒起来，
 *   由宿主在它自己的通道上取走（见 `App.drainSessionOutbox`）。
 */
public interface PageSink {
    func sendText(text: String): Unit
    func sendBinary(bytes: Array<UInt8>): Unit
    func close(): Unit
}

/** WS 承载：把出站包写成 WebSocket 文本/二进制帧 */
public class WebSocketSink <: PageSink {
    let ws: WebSocket

    public init(ws: WebSocket) {
        this.ws = ws
    }

    public func sendText(text: String): Unit {
        this.ws.write(WebSocketFrameType.TextWebFrame, text.toArray())
    }

    public func sendBinary(bytes: Array<UInt8>): Unit {
        this.ws.write(WebSocketFrameType.BinaryWebFrame, bytes)
    }

    public func close(): Unit {
        this.ws.writeCloseFrame()
    }

    /** 底层连接（WS 专用的读取/心跳路径使用；其它 sink 没有连接） */
    public func underlying(): WebSocket {
        this.ws
    }
}

/**
 * 无连接承载：出站包按顺序攒在内存里，等宿主取走。
 *
 * 用途：① 页面由宿主（如 WebView 绑定）驱动时，宿主在页面→宿主的请求里顺带取走
 * 积压包；② 静态渲染/单测里断言"服务端本该下发什么"。
 */
public class BufferSink <: PageSink {
    let outbox: ArrayList<String> = ArrayList<String>()
    var closed: Bool = false

    public init() {}

    public func sendText(text: String): Unit {
        this.outbox.add(text)
    }

    public func sendBinary(bytes: Array<UInt8>): Unit {
        // 二进制只出现在上传回执路径（WS 专属）；缓冲承载下不做静默丢弃，
        // 以一条可诊断的文本包记录，避免宿主侧"什么都没收到"却查不到原因。
        this.outbox.add("{\"kind\":\"unsupported_frame\",\"reason\":\"binary_frame_requires_websocket\"}")
    }

    public func close(): Unit {
        this.closed = true
    }

    public func isClosed(): Bool {
        this.closed
    }

    /** 取走全部积压包并清空（宿主在每次交互后调用） */
    public func drain(): Array<String> {
        let items = this.outbox.toArray()
        this.outbox.clear()
        items
    }

    public func pendingCount(): Int64 {
        this.outbox.size
    }
}

/** 序列化一条 JsonSerializable 消息为文本（与 wsSendJson 的线格式逐字节一致） */
public func jsonMessage<T>(msg: T): String where T <: JsonSerializable {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    msg.toJson(w)
    w.flush()
    buf.flush()
    String.fromUtf8(buf.bytes())
}

/** 向任意 sink 下发一条强类型消息 */
public func sinkSendJson<T>(sink: PageSink, msg: T): Unit where T <: JsonSerializable {
    sink.sendText(jsonMessage(msg))
}

/**
 * 树指纹：判断"客户端手上的树"与"服务端待发的树"是否同一形态。
 *
 * 用长度 + FNV-1a 64 位散列，而不是把两棵树都留在内存里对比——帧内容可能很大
 * （长列表/流式文本），指纹只需 O(1) 存储。散列碰撞在此用途下可接受：漏掉一次
 * 下发的后果是"客户端保持在等价树上"，不是数据错误。
 */
public func treeFingerprint(json: String): String {
    var hash: UInt64 = 0xcbf29ce484222325
    // 必须用回绕乘法：仓颉整数运算默认溢出即抛 OverflowException，
    // 而散列的本质就是让乘积自然回绕（OrdinaryMul 会在这里中断请求）。
    for (b in json.toArray()) {
        hash = (hash ^ UInt64(b)).wrappingMul(0x100000001b3)
    }
    "${json.size}:${hash}"
}
