package cjxt

import stdx.net.http.{WebSocket, WebSocketFrameType}

public func wsSendText(ws: WebSocket, text: String): Unit {
    ws.write(WebSocketFrameType.TextWebFrame, text.toArray())
}

public func wsReadText(ws: WebSocket): String {
    let frame = ws.read()
    let bytes = frame.payload
    String.fromUtf8(bytes)
}

public func wsClose(ws: WebSocket): Unit {
    ws.writeCloseFrame()
}
