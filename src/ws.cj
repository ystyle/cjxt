package cjxt

import std.io.ByteBuffer
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}
import stdx.net.http.{WebSocket, WebSocketFrameType}

public func wsSendText(ws: WebSocket, text: String): Unit {
    ws.write(WebSocketFrameType.TextWebFrame, text.toArray())
}

public func wsSendJson<T>(ws: WebSocket, msg: T): Unit where T <: JsonSerializable {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    msg.toJson(w)
    w.flush()
    buf.flush()
    ws.write(WebSocketFrameType.TextWebFrame, buf.bytes())
}

public func wsClose(ws: WebSocket): Unit {
    ws.writeCloseFrame()
}
