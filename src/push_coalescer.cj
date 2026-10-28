package cjxt

import std.collection.ArrayList
import std.sync.Mutex

// 服务端推送合并器：多个 pushUpdate（流式 token）合并为一次 flush（sendPatch）
//
// 语义：第一个 pushUpdate 标记会话并"武装"一个 flush（返回 true，调用方应启动
// flush 线程）；窗口内后续 pushUpdate 只追加待 flush 会话（去重），不重复武装。
// flush 线程在窗口到期后 beginFlush() 取走全部会话统一下发。
//
// 分类：**B 类**（共享可变状态，见 `docs/concurrency-model.md`）。
// mark 会被任意 pushUpdate 调用方并发进入，beginFlush 由 flush 协程调用；
// 早期靠外部一把全局执行锁串行化，那把锁已拆成每会话（D 类），
// 故并发保护收回本类内部。
public class PushCoalescer {
    var pending = ArrayList<String>()
    var armed: Bool = false
    let lock = Mutex()

    public init() {}

    // 标记一个需要 flush 的会话；返回 true 表示这是本 burst 第一次（调用方需启动 flush 线程）
    public func mark(sid: String): Bool {
        lock.lock()
        try {
            return this.doMark(sid)
        } finally {
            lock.unlock()
        }
    }

    // 调用方必须持有 lock（Cangjie 没有私有方法级注解，命名前缀 do* 表示"需持锁"）
    func doMark(sid: String): Bool {
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
        lock.lock()
        try {
            return this.doBeginFlush()
        } finally {
            lock.unlock()
        }
    }

    func doBeginFlush(): ArrayList<String> {
        this.armed = false
        let out = this.pending
        this.pending = ArrayList<String>()
        out
    }

    public func isArmed(): Bool {
        lock.lock()
        try {
            this.armed
        } finally {
            lock.unlock()
        }
    }

    public func pendingCount(): Int64 {
        lock.lock()
        try {
            Int64(this.pending.size)
        } finally {
            lock.unlock()
        }
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
