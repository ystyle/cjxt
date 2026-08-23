package cjxt

import std.collection.{ArrayList, HashMap}
import std.convert.*
import std.io.{ByteBuffer, SeekPosition}
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable, JsonReader, JsonDeserializable}
import stdx.net.http.WebSocket

// ============ 回调式 DOM 事务（事件驱动版）：服务端发起 DOM 命令/查询 ============
//
// 事件驱动模型：
// - fire-and-forget 命令（focus/scrollIntoView/setProperty）：发 dom_command，前端执行，不等待。
// - 查询（getProperty 等）：注册续体到 Session.pendingTx（txId → 续体）+ 发 dom_command；
//   前端执行后回 dom_result，listenLoop 收到后按 txId 取续体，作为 mini-action 跑（锁内 + ReRender→sendPatch）。
// - 无阻塞、无协程魔法：就是"注册事件处理器 + WS 双工事件到达驱动"。
//
// 寻址用 ref（VNode.ref("name")）：服务端把 ref 解析为树路径（Session.refPaths），客户端仍用路径 navigateTo。
// 查询结果是字符串（客户端 String(value) 上报）：String 步骤直接给原始值；Int64 走 Int64.parse
// （JSON readValue<Int64> 对数字字符串会抛——虚拟滚动踩过的坑）。

let _domTxCounter = [0]

func nextDomTxId(): String {
    _domTxCounter[0] += 1
    "dom_${_domTxCounter[0]}"
}

public struct DomCommand <: JsonSerializable {
    public let cmd: String       // focus / scrollIntoView / setProperty / getProperty
    public let refName: String   // 目标 ref 名（DOM 事务寻址；DomApi 解析为 path）
    public let path: String      // 解析后的框架路径 children/N/...（客户端 navigateTo 用）
    public let property: String  // setProperty/getProperty 的属性名
    public let value: String     // setProperty/scrollIntoView 的值/behavior
    public let resultKey: String // getProperty 回填 key

    public init(cmd: String, refName: String, path: String, property: String, value: String, resultKey: String) {
        this.cmd = cmd
        this.refName = refName
        this.path = path
        this.property = property
        this.value = value
        this.resultKey = resultKey
    }

    // 解析 ref 后返回带路径的副本（refName 为空时直接用 path）
    public func resolved(path: String): DomCommand {
        DomCommand(this.cmd, this.refName, path, this.property, this.value, this.resultKey)
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("cmd").writeValue(this.cmd)
        w.writeName("refName").writeValue(this.refName)
        w.writeName("path").writeValue(this.path)
        w.writeName("property").writeValue(this.property)
        w.writeName("value").writeValue(this.value)
        w.writeName("resultKey").writeValue(this.resultKey)
        w.endObject()
    }
}

public func domFocus(refName: String): DomCommand {
    DomCommand("focus", refName, "", "", "", "")
}

public func domScrollIntoView(refName: String, behavior: String): DomCommand {
    DomCommand("scrollIntoView", refName, "", "", behavior, "")
}

public func domSetProperty(refName: String, property: String, value: String): DomCommand {
    DomCommand("setProperty", refName, "", property, value, "")
}

public func domGetProperty(refName: String, property: String, resultKey: String): DomCommand {
    DomCommand("getProperty", refName, "", property, "", resultKey)
}

// 服务端 → 前端：dom_command 消息
public struct DomCommandMsg <: JsonSerializable {
    let txId: String
    let commands: Array<DomCommand>
    let needResult: Bool

    public init(txId: String, commands: Array<DomCommand>, needResult: Bool) {
        this.txId = txId
        this.commands = commands
        this.needResult = needResult
    }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("dom_command")
        w.writeName("txId").writeValue(this.txId)
        w.writeName("commands").writeValue(this.commands)
        w.writeName("needResult").writeValue(this.needResult)
        w.endObject()
    }
}

// ActionContext.dom 的入口：持有 app + ws + session，负责发送 dom_command 与注册续体
public class DomApi {
    let app: App
    let ws: WebSocket
    let session: Session

    public init(app: App, ws: WebSocket, session: Session) {
        this.app = app
        this.ws = ws
        this.session = session
    }

    // fire-and-forget 命令：把每个命令的 ref 解析为路径，发命令，前端执行，不等待结果
    public func command(cmds: Array<DomCommand>): Unit {
        let resolved = ArrayList<DomCommand>()
        for (c in cmds) {
            let p = this.resolveRef(c)
            if (p != "") { resolved.add(c.resolved(p)) }
        }
        wsSendJson(this.ws, DomCommandMsg("", resolved.toArray(), false))
    }

    // 查询（事件驱动）：ref 解析为路径 → 注册续体到 session.pendingTx + 发 getProperty；
    // 前端回 dom_result 后 listenLoop 按 txId 调续体（真实值经 results 传入）。返回是否真正下发。
    public func query(refName: String, property: String, k: (HashMap<String, String>) -> PatchResult): Bool {
        let p = this.resolveRef(domGetProperty(refName, property, "r1"))
        if (p == "") { return false }
        let txId = nextDomTxId()
        this.session.pendingTx.add(txId, k)
        let cmd = domGetProperty(refName, property, "r1").resolved(p)
        wsSendJson(this.ws, DomCommandMsg(txId, [cmd], true))
        true
    }

    // 泛型查询：结果自动解析为 T（JsonDeserializable），续体直接拿类型化值（适合 String；数值用 queryInt64）。
    // 返回是否真正下发。
    public func queryAs<T>(refName: String, property: String, k: (T) -> PatchResult): Bool where T <: JsonDeserializable<T> {
        let p = this.resolveRef(domGetProperty(refName, property, "r1"))
        if (p == "") { return false }
        let txId = nextDomTxId()
        let wrapped: (HashMap<String, String>) -> PatchResult = { results =>
            let v = domParseResult<T>(results, "r1")
            k(v)
        }
        this.session.pendingTx.add(txId, wrapped)
        let cmd = domGetProperty(refName, property, "r1").resolved(p)
        wsSendJson(this.ws, DomCommandMsg(txId, [cmd], true))
        true
    }

    // 数值查询：DOM 值经 String(value) 上报，Int64 直接 parse（JSON readValue 对数字字符串会抛）。
    // 返回是否真正下发。
    public func queryInt64(refName: String, property: String, k: (Int64) -> PatchResult): Bool {
        let p = this.resolveRef(domGetProperty(refName, property, "r1"))
        if (p == "") { return false }
        let txId = nextDomTxId()
        let wrapped: (HashMap<String, String>) -> PatchResult = { results =>
            let raw = match (results.get("r1")) { case Some(v) => v case None => "0" }
            let v = if (raw == "") { 0 } else { Int64.parse(raw, radix: 10) }
            k(v)
        }
        this.session.pendingTx.add(txId, wrapped)
        let cmd = domGetProperty(refName, property, "r1").resolved(p)
        wsSendJson(this.ws, DomCommandMsg(txId, [cmd], true))
        true
    }

    // 启动一个顺序步骤序列（co-lite）：扁平化连续 await
    public func seq(): DomSeq {
        DomSeq(this)
    }

    private func resolveRef(c: DomCommand): String {
        if (c.refName != "") {
            match (this.session.refPaths.get(c.refName)) {
                case Some(p) => p
                case None => ""
            }
        } else {
            c.path
        }
    }
}

// 把 results[key]（字符串）按 T 的 JsonDeserializable 解析为类型化值（对齐 VNode.bind 的写法）
func domParseResult<T>(results: HashMap<String, String>, key: String): T where T <: JsonDeserializable<T> {
    let raw = match (results.get(key)) { case Some(v) => v case None => "" }
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    w.writeValue(raw)
    w.flush()
    buf.flush()
    buf.seek(SeekPosition.Begin(0))
    let reader = JsonReader(buf)
    reader.readValue<T>()
}

// 从展开树收集 data-ref → 路径（DOM 事务寻址；Session.refreshRefs 调用）
func collectRefsFromTree(node: IComponent, path: String, map: HashMap<String, String>): Unit {
    match (node) {
        case v: VNode =>
            match (v._attrs) {
                case Some(a) =>
                    match (a.get("data-ref")) {
                        case Some(name) => if (name != "") { map.add(name, path) }
                        case None => ()
                    }
                case None => ()
            }
            var i = 0
            for (c in v._children) {
                // 根节点 path="" 时首段无前导斜杠（客户端 split('/') 解析），后续段用 "/" 分隔
                let childPath = if (path == "") { "children/${i}" } else { "${path}/children/${i}" }
                collectRefsFromTree(c, childPath, map)
                i += 1
            }
        case _ => ()
    }
}

// ============ DomSeq：co-lite 顺序步骤（事件驱动状态机，扁平化连续 await） ============
//
// 用法：
//   let seq = ctx.dom.seq()
//   seq.query("a", "offsetHeight") { h => seq.command([domFocus("b")]) }   // 中间步骤（h: String）
//   seq.thenInt64("c", "offsetWidth") { w => ... PatchResult }             // 末步（w: Int64）
//
// 每个 query 的续体（值到达后）跑 k；k 里可继续 seq.query/seq.command 链式推进；
// then/thenInt64 是"末步"——等所有中间查询完成才发出，其续体返回 PatchResult 触发补丁。
// 关键：pending 只在 api 真正下发查询时递增（ref 找不到时 api 返回 false，不卡住状态机）。
public class DomSeq {
    let api: DomApi
    var pending: Int64 = 0
    var deferredThen: Option<() -> Unit> = None
    var finished: Bool = false

    public init(api: DomApi) {
        this.api = api
    }

    // 中间查询步骤（String 原始值）
    public func query(refName: String, property: String, k: (String) -> Unit): DomSeq {
        let self = this
        if (self.api.query(refName, property) { results =>
            self.pending -= 1
            let v = match (results.get("r1")) { case Some(x) => x case None => "" }
            k(v)
            self.maybeFireThen()
            PatchResult.Patch(Array<PatchEntry>())
        }) {
            self.pending += 1
        }
        this
    }

    // 中间查询步骤（Int64）
    public func queryInt64(refName: String, property: String, k: (Int64) -> Unit): DomSeq {
        let self = this
        if (self.api.queryInt64(refName, property) { v =>
            self.pending -= 1
            k(v)
            self.maybeFireThen()
            PatchResult.Patch(Array<PatchEntry>())
        }) {
            self.pending += 1
        }
        this
    }

    // 中间命令步骤：fire-and-forget
    public func command(cmds: Array<DomCommand>): DomSeq {
        this.api.command(cmds)
        this
    }

    // 末步（String）
    public func then(refName: String, property: String, k: (String) -> PatchResult): DomSeq {
        let self = this
        self.deferredThen = Some<() -> Unit>({ =>
            self.pending += 1
            self.api.query(refName, property) { results =>
                self.pending -= 1
                self.maybeFireThen()
                let v = match (results.get("r1")) { case Some(x) => x case None => "" }
                k(v)
            }
        })
        self.maybeFireThen()
        this
    }

    // 末步（Int64）
    public func thenInt64(refName: String, property: String, k: (Int64) -> PatchResult): DomSeq {
        let self = this
        self.deferredThen = Some<() -> Unit>({ =>
            self.pending += 1
            self.api.queryInt64(refName, property) { v =>
                self.pending -= 1
                self.maybeFireThen()
                k(v)
            }
        })
        self.maybeFireThen()
        this
    }

    // 超时兜底：ms 毫秒后若序列还没完成，把 onTimeout 作为续体跑（复用 dispatchDomResult 的
    // ReRender→sendPatch 链路）。pendingTx 条目到点由 dispatchDomResult 移除；正常完成时
    // 该条目已被消费，超时线程 dispatch 时查不到 → 忽略。
    public func timeout(ms: Int64, onTimeout: () -> PatchResult): DomSeq {
        let self = this
        let txId = nextDomTxId()
        let wrapped: (HashMap<String, String>) -> PatchResult = { _ => onTimeout() }
        self.api.session.pendingTx.add(txId, wrapped)
        let app = self.api.app
        let session = self.api.session
        spawn {
            sleep(Duration.millisecond * ms)
            // 走 dispatchDomResult：若该 tx 仍 pending 则跑 onTimeout，否则（已正常完成）忽略
            let _ = app.dispatchDomTimeout(session, txId)
        }
        this
    }

    // 取消：立即把 onCancel 作为结果跑（等价于 timeout 0）
    public func cancel(onCancel: () -> PatchResult): DomSeq {
        let txId = nextDomTxId()
        let wrapped: (HashMap<String, String>) -> PatchResult = { _ => onCancel() }
        this.api.session.pendingTx.add(txId, wrapped)
        let app = this.api.app
        let session = this.api.session
        let _ = app.dispatchDomTimeout(session, txId)
        this
    }

    func maybeFireThen(): Unit {
        if (this.finished) { return }
        if (this.pending == 0) {
            match (this.deferredThen) {
                case Some(f) =>
                    this.deferredThen = None
                    this.finished = true
                    f()
                case None => ()
            }
        }
    }
}
