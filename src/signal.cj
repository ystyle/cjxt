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
public open class ReactiveNode {
    var subs = ArrayList<SubEntry>()
    var nextSubId: Int64 = 1
    // 批量模式去重标记
    public var _pending: Bool = false

    public func subscribe(fn: () -> Unit): Int64 {
        let id = this.nextSubId
        this.nextSubId += 1
        this.subs.add(SubEntry(id, fn))
        id
    }

    public func unsubscribe(id: Int64): Unit {
        var i = 0
        for (s in this.subs) {
            if (s.id == id) {
                this.subs.remove(i..i + 1)
                return
            }
            i += 1
        }
    }

    public func clearSubs(): Unit {
        this.subs.clear()
    }

    public func notify(): Unit {
        // 迭代快照：通知期间若订阅者退订/改订阅（如 effect 重跑），不破坏迭代
        let snapshot = ArrayList<SubEntry>(this.subs)
        for (s in snapshot) {
            s.fn()
        }
    }

    public func clearPendingFlag(): Unit {
        this._pending = false
    }
}

// 追踪上下文：scope 栈（自动追踪）+ collector 栈（computed 依赖收集）+ batch/untracked 深度
public class SignalTracker {
    static var scopeStack = ArrayList<() -> Unit>()
    // computed/effect 重算时的依赖收集器：收到 (源, 订阅id) 以支持退订
    static var collectorStack = ArrayList<(ReactiveNode, Int64) -> Unit>()

    public static var pendingRender: Bool = false
    public static var execMutex = Mutex()
    public static var dirtyComponents = ArrayList<Component>()

    // 批量模式：变更延迟到 batch 结束一次性通知
    public static var batchDepth: Int64 = 0
    public static var batchChanged = ArrayList<ReactiveNode>()
    // untracked 读取深度：>0 时 get() 不订阅
    public static var untrackedDepth: Int64 = 0

    public static func enterScope(cb: () -> Unit): Unit {
        scopeStack.add(cb)
    }

    public static func exitScope(): Unit {
        scopeStack.remove(scopeStack.size - 1..scopeStack.size)
    }

    public static func currentSub(): Option<() -> Unit> {
        if (scopeStack.size > 0) { Some(scopeStack[scopeStack.size - 1]) } else { None }
    }

    public static func pushCollector(cb: (ReactiveNode, Int64) -> Unit): Unit {
        collectorStack.add(cb)
    }

    public static func popCollector(): Unit {
        collectorStack.remove(collectorStack.size - 1..collectorStack.size)
    }

    public static func topCollector(): Option<(ReactiveNode, Int64) -> Unit> {
        if (collectorStack.size > 0) { Some(collectorStack[collectorStack.size - 1]) } else { None }
    }

    public static func isUntracked(): Bool {
        untrackedDepth > 0
    }

    public static func flushBatch(): Unit {
        let nodes = batchChanged
        batchChanged = ArrayList<ReactiveNode>()
        for (n in nodes) {
            n.clearPendingFlag()
            n.notify()
        }
    }
}

// 批量原子更新：batch 内多次 set 只触发一次通知（流式/多字段更新的地基）
public func batch<T>(fn: () -> T): T {
    SignalTracker.batchDepth += 1
    try {
        fn()
    } finally {
        SignalTracker.batchDepth -= 1
        if (SignalTracker.batchDepth == 0) {
            SignalTracker.flushBatch()
        }
    }
}

// 不追踪读取：作用域内 get() 不建立订阅（处理器里读取但不触发重渲染时用）
public func untracked<T>(fn: () -> T): T {
    SignalTracker.untrackedDepth += 1
    try {
        fn()
    } finally {
        SignalTracker.untrackedDepth -= 1
    }
}

// ============================================================================
// Signal<T>：可写响应式状态源
// ============================================================================
public class Signal<T> <: ReactiveNode {
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
        if (SignalTracker.batchDepth > 0) {
            if (!this._pending) {
                this._pending = true
                SignalTracker.batchChanged.add(this)
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
public class Computed<T> <: ReactiveNode {
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

    public init(fn: () -> Unit) {
        this.fn = fn
        this.run()
    }

    func run(): Unit {
        this.unsubscribeDeps()
        SignalTracker.enterScope({ => this.rerun() })
        SignalTracker.pushCollector({ src, id => this.depIds.add(DepEntry(src, id)) })
        try {
            this.fn()
        } finally {
            SignalTracker.popCollector()
            SignalTracker.exitScope()
        }
    }

    func rerun(): Unit {
        if (!this.disposed) {
            this.run()
        }
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
