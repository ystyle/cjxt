package cjxt

import std.collection.ArrayList

// 服务端推送合并器：多个 pushUpdate（流式 token）合并为一次 flush（sendPatch）
//
// 语义：第一个 pushUpdate 标记会话并"武装"一个 flush（返回 true，调用方应启动
// flush 线程）；窗口内后续 pushUpdate 只追加待 flush 会话（去重），不重复武装。
// flush 线程在窗口到期后 beginFlush() 取走全部会话统一下发。
//
// 线程安全由外部调用方保证：mark/beginFlush 均在 SignalTracker.execMutex 内访问。
public class PushCoalescer {
    var pending = ArrayList<String>()
    var armed: Bool = false

    public init() {}

    // 标记一个需要 flush 的会话；返回 true 表示这是本 burst 第一次（调用方需启动 flush 线程）
    public func mark(sid: String): Bool {
        if (!this.contains(this.pending, sid)) {
            this.pending.add(sid)
        }
        if (this.armed) {
            return false
        }
        this.armed = true
        true
    }

    // flush 开始时调用：解除武装并取走待 flush 会话列表（随后清空 pending）
    public func beginFlush(): ArrayList<String> {
        this.armed = false
        let out = this.pending
        this.pending = ArrayList<String>()
        out
    }

    public func isArmed(): Bool {
        this.armed
    }

    public func pendingCount(): Int64 {
        this.pending.size
    }

    func contains(list: ArrayList<String>, s: String): Bool {
        for (x in list) {
            if (x == s) {
                return true
            }
        }
        false
    }
}
