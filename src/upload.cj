package cjxt

import std.collection.ArrayList
import std.convert.*
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}

// ============ WS 二进制帧流式上传（纯逻辑，供 App.listenLoop 与单测共用） ============
//
// 协议（复用客户端已有 WS 连接，会话绑定、双工）：
//   1. 客户端发 {type:"upload_begin", id, name, size, action}（TextWebFrame JSON 文本帧）
//      其中 action 是 data-action-uploaded 的稳定 handler id（h:path:uploaded）
//   2. 客户端按 256KB 分块发 BinaryWebFrame（服务端负责拼接分段帧）
//   3. 服务端每收一块边写盘边回 {kind:"upload_progress", id, received}（块级 ack = 背压）
//   4. 收满 size → 关闭文件 → dispatch action(name, {name,url,size}) → 上传列表出现
//      （与 base64 通道的后端接入面完全一致：Upload 组件零改动）
//   5. 错误 → {kind:"upload_error", id, message}（客户端中止本次上传）
//
// 单流限制：binary 帧没有元数据，同一连接同一时刻只允许一个进行中的上传，
// 由客户端上传队列（串行 pump）保证。

public struct UploadBegin {
    public let id: String
    public let name: String
    public let size: Int64
    public let action: String

    public init(id: String, name: String, size: Int64, action: String) {
        this.id = id
        this.name = name
        this.size = size
        this.action = action
    }
}

// 上传进行中的状态（class：引用语义，uploadFeed 直接推进 received；
// Session.upload 持有同一实例，连接线程与清理路径共享）
public class UploadState {
    public let id: String
    public let name: String
    public let size: Int64
    public let action: String
    // 存储文件名（nextId()-name），完整路径 = uploadDir + "/" + stored
    public let stored: String
    public var received: Int64

    public init(id: String, name: String, size: Int64, action: String, stored: String) {
        this.id = id
        this.name = name
        this.size = size
        this.action = action
        this.stored = stored
        this.received = 0
    }
}

// 解析 upload_begin（客户端 JSON。size 是数字或字符串数字；id 兼容字符串/数字形）
public func parseUploadBegin(raw: String): Option<UploadBegin> {
    var id = jsonStrField(raw, "id")
    if (id == "") {
        id = jsonNumField(raw, "id")
    }
    let name = jsonStrField(raw, "name")
    let action = jsonStrField(raw, "action")
    if (id == "" || name == "" || action == "") {
        return None
    }
    let sizeStr = jsonNumField(raw, "size")
    if (sizeStr == "") {
        return None
    }
    Some(UploadBegin(id, name, Int64.parse(sizeStr, radix: 10), action))
}

// 追加一块字节：更新 received；返回 true = 已全部收完
public func uploadFeed(state: UploadState, n: Int64): Bool {
    state.received = state.received + n
    state.received >= state.size
}

// 块是否超过声明大小（客户端 bug / 恶意；超限应中止并删除半成品）
public func uploadWouldOverflow(state: UploadState, n: Int64): Bool {
    state.received + n > state.size
}

// 客户端上传进度确认（块级背压 ack）
public struct UploadProgressMsg <: JsonSerializable {
    public let kind: String
    public let id: String
    public let received: Int64

    public init(id: String, received: Int64) {
        this.kind = "upload_progress"
        this.id = id
        this.received = received
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue(this.kind)
        w.writeName("id").writeValue(this.id)
        w.writeName("received").writeValue(this.received)
        w.endObject()
    }
}

// 上传失败（无活跃流 / 超限 / 未配置目录 / 无进行中上传收到数据……）
public struct UploadErrorMsg <: JsonSerializable {
    public let kind: String
    public let id: String
    public let message: String

    public init(id: String, message: String) {
        this.kind = "upload_error"
        this.id = id
        this.message = message
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue(this.kind)
        w.writeName("id").writeValue(this.id)
        w.writeName("message").writeValue(this.message)
        w.endObject()
    }
}

// ============ JSON 字段提取（独立实现，避免依赖 app.cj 的私有 helper） ============

// 追加字节（分段帧拼接用；match arm 内不能写 for → 提取为独立函数）
public func appendBytes(data: ArrayList<UInt8>, bytes: Array<UInt8>): Unit {
    for (b in bytes) {
        data.add(b)
    }
}

// 字符串字段："field":"<值>"（到下一个引号为止）
func jsonStrField(raw: String, field: String): String {
    let mark = "\"${field}\":\""
    match (raw.indexOf(mark)) {
        case Some(idx) =>
            let from = idx + mark.size
            match (raw.indexOf("\"", from)) {
                case Some(end) => raw[from..end]
                case None => ""
            }
        case None => ""
    }
}

// 数字字段："field":<数字>（兼容 "field":"<数字>" 字符串形式）
func jsonNumField(raw: String, field: String): String {
    let mark = "\"${field}\":"
    match (raw.indexOf(mark)) {
        case Some(idx) =>
            var from = idx + mark.size
            if (from < raw.size && raw[from] == 34u8) {
                from += 1
            }
            var end = from
            while (end < raw.size && raw[end] >= 48u8 && raw[end] <= 57u8) {
                end += 1
            }
            if (end > from) { raw[from..end] } else { "" }
        case None => ""
    }
}
