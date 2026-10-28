package cjxt

import std.collection.ArrayList
import std.sync.Mutex

// ============================================================================
// 全特性响应式核心：Signal（可写源）/ Computed（派生）/ Effect（副作用）
// + batch（批量原子更新）/ untracked（不追踪读取）/ 相等性 / 生命周期订阅管理
// ============================================================================

// 订阅条目：id 用于精确退订（避免依赖闭包相等性）
public struct SubEntry {
    let id: Int64
    let fn: () -> Unit
    public init(id: Int64, fn: () -> Unit) {
        this.id = id
        this.fn = fn
    }
}

// 依赖条目：source 上的第 id 个订阅（供 computed/effect 退订）
public struct DepEntry {
    let source: ReactiveNode
    let id: Int64
    public init(source: ReactiveNode, id: Int64) {
        this.source = source
        this.id = id
    }
}

// 可订阅节点基类：Signal / Computed 共享订阅管理
//
// ⚠️ 订阅表是**跨线程共享**的：cjxt 每条 WS 连接一个线程，同一个 Signal 被
// 多个会话同时读写。以下三方会并发访问 `subs`，故全部加锁：
//   · subscribe   —— `render()` 里 `get()` 时订阅
//   · unsubscribe —— 组件 dispose / 重渲前退订
//   · notify      —— `set()` 时通知全部订阅者
//
// 不加锁的后果是**进程 SIGSEGV**（ArrayList 内部结构被并发改坏），不是可捕获异常。
// 见 `concurrency_race_test.cj`。
public open class ReactiveNode {
    var subs = ArrayList<SubEntry>()
    var nextSubId: Int64 = 1
    // 批量模式去重标记
    public var _pending: Bool = false
    // 保护 subs / nextSubId（见类注释）
    let subsLock = Mutex()

    public func subscribe(fn: () -> Unit): Int64 {
        subsLock.lock()
        try {
            let id = this.nextSubId
            this.nextSubId += 1
            this.subs.add(SubEntry(id, fn))
            id
        } finally {
            subsLock.unlock()
        }
    }

    public func unsubscribe(id: Int64): Unit {
        subsLock.lock()
        try {
            var i = 0
            for (s in this.subs) {
                if (s.id == id) {
                    this.subs.remove(i..i + 1)
                    return
                }
                i += 1
            }
        } finally {
            subsLock.unlock()
        }
    }

    public func clearSubs(): Unit {
        subsLock.lock()
        try {
            this.subs.clear()
        } finally {
            subsLock.unlock()
        }
    }

    public func notify(): Unit {
        // 快照在锁内取（拷贝期间不允许别人改 subs），遍历/回调在锁外执行 ——
        // 回调里会再进来 subscribe/unsubscribe（如 effect 重跑、组件重渲），
        // 持锁回调会自锁。
        let snapshot = copySubs()
        for (s in snapshot) {
            s.fn()
        }
    }

    public func clearPendingFlag(): Unit {
        this._pending = false
    }

    // 取订阅表快照（供 notify 与测试读数量）
    func copySubs(): ArrayList<SubEntry> {
        subsLock.lock()
        try {
            ArrayList<SubEntry>(this.subs)
        } finally {
            subsLock.unlock()
        }
    }

    // 当前订阅数（测试/诊断用）
    public func subCount(): Int64 {
        subsLock.lock()
        try {
            this.subs.size
        } finally {
            subsLock.unlock()
        }
    }
}

// 可读响应式值：Signal（可写源）与 Computed（派生）的公共只读接口
// 组件/框架的只读输入统一接受 Readable<T>——调用方可传 Signal 或 Computed
public interface Readable<T> {
    func get(): T
}

// 追踪上下文
//
// 并发约定见 `docs/concurrency-model.md`（总表）：
//   · 渲染上下文（scope/collector/batch/untracked）→ **A 类**，ThreadLocal
//   · dirtyComponents 脏队列                      → **B 类**，Mutex 保护
//
// A 类用线程局部的原因：这些栈是「我这一轮在渲染什么」，曾被放进进程级静态变量，
// 导致 A 执行体 enterScope 后、B 执行体 exitScope 弹掉 A 的栈帧 → 组件登记到
// 错误的会话 → `notify` 调空指针 → SIGSEGV。
public class SignalTracker {
    // ── 线程局部：渲染上下文 ──────────────────────────────────
    static let scopeStackTL = ThreadLocal<ArrayList<() -> Unit>>()
    // computed/effect 重算时的依赖收集器：收到 (源, 订阅id) 以支持退订
    static let collectorStackTL = ThreadLocal<ArrayList<(ReactiveNode, Int64) -> Unit>>()
    // 批量模式：变更延迟到 batch 结束一次性通知
    static let batchDepthTL = ThreadLocal<Int64>()
    static let batchChangedTL = ThreadLocal<ArrayList<ReactiveNode>>()
    // untracked 读取深度：>0 时 get() 不订阅
    static let untrackedDepthTL = ThreadLocal<Int64>()

    // ── 跨线程共享：脏组件队列（加锁保护） ──────────────────────
    static var dirtyComponents = ArrayList<Component>()
    static let dirtyLock = Mutex()

    // 供 uiState 等兼容访问（测试也用）——读写一律走下面的受控方法
    public static func scopeStack(): ArrayList<() -> Unit> {
        match (scopeStackTL.get()) {
            case Some(v) => v
            case None =>
                let v = ArrayList<() -> Unit>()
                scopeStackTL.set(v)
                v
        }
    }

    static func collectorStack(): ArrayList<(ReactiveNode, Int64) -> Unit> {
        match (collectorStackTL.get()) {
            case Some(v) => v
            case None =>
                let v = ArrayList<(ReactiveNode, Int64) -> Unit>()
                collectorStackTL.set(v)
                v
        }
    }

    static func batchChanged(): ArrayList<ReactiveNode> {
        match (batchChangedTL.get()) {
            case Some(v) => v
            case None =>
                let v = ArrayList<ReactiveNode>()
                batchChangedTL.set(v)
                v
        }
    }

    public static func batchDepth(): Int64 {
        match (batchDepthTL.get()) {
            case Some(v) => v
            case None => 0
        }
    }

    public static func setBatchDepth(v: Int64): Unit {
        batchDepthTL.set(v)
    }

    public static func untrackedDepth(): Int64 {
        match (untrackedDepthTL.get()) {
            case Some(v) => v
            case None => 0
        }
    }

    public static func setUntrackedDepth(v: Int64): Unit {
        untrackedDepthTL.set(v)
    }

    // ── 脏组件队列：受控访问 ──────────────────────────────────
    public static func addDirty(c: Component): Unit {
        dirtyLock.lock()
        try {
            dirtyComponents.add(c)
        } finally {
            dirtyLock.unlock()
        }
    }

    // 取走全部脏组件并清空（原子：谁取谁负责处理）
    static func drainDirtyAll(): ArrayList<Component> {
        dirtyLock.lock()
        try {
            let all = ArrayList<Component>(dirtyComponents)
            dirtyComponents = ArrayList<Component>()
            all
        } finally {
            dirtyLock.unlock()
        }
    }

    // 查看脏组件（不清空）。会先处理"组件已清脏则移出队列"。
    public static func snapshotDirty(): ArrayList<Component> {
        dirtyLock.lock()
        try {
            ArrayList<Component>(dirtyComponents)
        } finally {
            dirtyLock.unlock()
        }
    }

    // 放回队列（别的会话的组件留给它自己处理）
    static func putBackDirty(list: ArrayList<Component>): Unit {
        dirtyLock.lock()
        try {
            for (c in list) {
                dirtyComponents.add(c)
            }
        } finally {
            dirtyLock.unlock()
        }
    }

    // 全量替换（保留未下发的）
    static func replaceDirty(list: ArrayList<Component>): Unit {
        dirtyLock.lock()
        try {
            dirtyComponents = ArrayList<Component>(list)
        } finally {
            dirtyLock.unlock()
        }
    }

    public static func clearDirty(): Unit {
        dirtyLock.lock()
        try {
            dirtyComponents.clear()
        } finally {
            dirtyLock.unlock()
        }
    }

    public static func dirtyCount(): Int64 {
        dirtyLock.lock()
        try {
            dirtyComponents.size
        } finally {
            dirtyLock.unlock()
        }
    }

    public static func enterScope(cb: () -> Unit): Unit {
        scopeStack().add(cb)
    }

    public static func exitScope(): Unit {
        let st = scopeStack()
        if (st.size > 0) {
            st.remove(st.size - 1..st.size)
        }
    }

    // 把组件移出脏队列（组件离树后不再参与补丁）。
    // 按 uid 比对：语言层没有引用相等算子，不能拿组件实例直接比较。
    public static func removeDirty(c: Component): Unit {
        dirtyLock.lock()
        try {
            var i = 0
            while (i < dirtyComponents.size) {
                if (dirtyComponents[i].uid() == c.uid()) {
                    dirtyComponents.remove(i..i + 1)
                } else {
                    i += 1
                }
            }
        } finally {
            dirtyLock.unlock()
        }
    }

    public static func currentSub(): Option<() -> Unit> {
        let st = scopeStack()
        if (st.size > 0) { Some(st[st.size - 1]) } else { None }
    }

    public static func pushCollector(cb: (ReactiveNode, Int64) -> Unit): Unit {
        collectorStack().add(cb)
    }

    public static func popCollector(): Unit {
        let st = collectorStack()
        if (st.size > 0) {
            st.remove(st.size - 1..st.size)
        }
    }

    public static func topCollector(): Option<(ReactiveNode, Int64) -> Unit> {
        let st = collectorStack()
        if (st.size > 0) { Some(st[st.size - 1]) } else { None }
    }

    public static func isUntracked(): Bool {
        untrackedDepth() > 0
    }

    public static func flushBatch(): Unit {
        let nodes = batchChanged()
        batchChangedTL.set(ArrayList<ReactiveNode>())
        for (n in nodes) {
            n.clearPendingFlag()
            n.notify()
        }
    }
}

// 批量原子更新：batch 内多次 set 只触发一次通知（流式/多字段更新的地基）
public func batch<T>(fn: () -> T): T {
    SignalTracker.setBatchDepth(SignalTracker.batchDepth() + 1)
    try {
        fn()
    } finally {
        SignalTracker.setBatchDepth(SignalTracker.batchDepth() - 1)
        if (SignalTracker.batchDepth() == 0) {
            SignalTracker.flushBatch()
        }
    }
}

// 不追踪读取：作用域内 get() 不建立订阅（处理器里读取但不触发重渲染时用）
public func untracked<T>(fn: () -> T): T {
    SignalTracker.setUntrackedDepth(SignalTracker.untrackedDepth() + 1)
    try {
        fn()
    } finally {
        SignalTracker.setUntrackedDepth(SignalTracker.untrackedDepth() - 1)
    }
}

// ============================================================================
// Signal<T>：可写响应式状态源
// ============================================================================
public class Signal<T> <: ReactiveNode & Readable<T> {
    var value: T
    // 可选相等性函数：set 相同值时不通知（防无限循环/多余重渲染）
    var compare: Option<(T, T) -> Bool> = None

    public init(value: T, compare!: Option<(T, T) -> Bool> = None) {
        this.value = value
        this.compare = compare
    }

    // 读取：若在追踪作用域内则建立订阅（untracked 时跳过）
    public func get(): T {
        if (!SignalTracker.isUntracked()) {
            match (SignalTracker.currentSub()) {
                case Some(cb) =>
                    let id = this.subscribe(cb)
                    // 若在 computed/effect 重算中，记录依赖（支持退订）
                    match (SignalTracker.topCollector()) {
                        case Some(col) => col(this, id)
                        case None => ()
                    }
                case None => ()
            }
        }
        this.value
    }

    public func set(v: T): Unit {
        match (this.compare) {
            case Some(cmp) => if (cmp(v, this.value)) { return }
            case None => ()
        }
        this.value = v
        if (SignalTracker.batchDepth() > 0) {
            if (!this._pending) {
                this._pending = true
                SignalTracker.batchChanged().add(this)
            }
        } else {
            this.notify()
        }
    }

    public func update(fn: (T) -> T): Unit {
        this.set(fn(this.value))
    }
}

// ============================================================================
// Computed<T>：惰性派生值（缓存 + 依赖变化自动失效）
// ============================================================================
public class Computed<T> <: ReactiveNode & Readable<T> {
    var computeFn: () -> T
    var cached: Option<T> = None
    var dirty: Bool = true
    var disposed: Bool = false
    var depIds = ArrayList<DepEntry>()

    public init(compute: () -> T) {
        this.computeFn = compute
    }

    // 读取：订阅下游 + 惰性重算
    public func get(): T {
        if (!SignalTracker.isUntracked()) {
            match (SignalTracker.currentSub()) {
                case Some(cb) =>
                    let id = this.subscribe(cb)
                    match (SignalTracker.topCollector()) {
                        case Some(col) => col(this, id)
                        case None => ()
                    }
                case None => ()
            }
        }
        if (this.dirty) {
            this.recompute()
        }
        match (this.cached) {
            case Some(v) => v
            case None => throw Exception("Computed: 重算后无缓存值")
        }
    }

    func recompute(): Unit {
        this.unsubscribeDeps()
        SignalTracker.enterScope({ => this.invalidate() })
        SignalTracker.pushCollector({ src, id => this.depIds.add(DepEntry(src, id)) })
        let v = try {
            this.computeFn()
        } finally {
            SignalTracker.popCollector()
            SignalTracker.exitScope()
        }
        this.cached = Some(v)
        this.dirty = false
    }

    // 依赖变化 → 标脏 + 通知下游
    public func invalidate(): Unit {
        if (!this.dirty) {
            this.dirty = true
            this.notify()
        }
    }

    func unsubscribeDeps(): Unit {
        for (d in this.depIds) {
            d.source.unsubscribe(d.id)
        }
        this.depIds.clear()
    }

    public func dispose(): Unit {
        this.disposed = true
        this.unsubscribeDeps()
        this.clearSubs()
    }
}

// ============================================================================
// Effect：自动运行的副作用（依赖变化时重新执行）
// ============================================================================
public class Effect {
    var fn: () -> Unit
    var disposed: Bool = false
    var depIds = ArrayList<DepEntry>()
    var running: Bool = false
    var pending: Bool = false

    public init(fn: () -> Unit) {
        this.fn = fn
        this.run()
    }

    func run(): Unit {
        this.unsubscribeDeps()
        this.running = true
        this.pending = false
        SignalTracker.enterScope({ => this.rerun() })
        SignalTracker.pushCollector({ src, id => this.depIds.add(DepEntry(src, id)) })
        try {
            this.fn()
        } finally {
            SignalTracker.popCollector()
            SignalTracker.exitScope()
            this.running = false
        }
        // 运行期间发生的依赖变更（重入）推迟到本次结束后统一再跑一次，避免递归栈溢出
        if (this.pending && !this.disposed) {
            this.rerun()
        }
    }

    func rerun(): Unit {
        if (this.disposed) {
            return
        }
        if (this.running) {
            // 重入保护：effect 执行中依赖又变 → 标记 pending，等本次结束再跑
            this.pending = true
            return
        }
        this.run()
    }

    public func dispose(): Unit {
        this.disposed = true
        this.unsubscribeDeps()
    }

    func unsubscribeDeps(): Unit {
        for (d in this.depIds) {
            d.source.unsubscribe(d.id)
        }
        this.depIds.clear()
    }
}
