package cjxt

import std.collection.ArrayList
import std.sync.Mutex

public class SignalTracker {
    static var scopeStack = ArrayList<() -> Unit>()
    public static var pendingRender: Bool = false
    public static var execMutex = Mutex()

    public static func enterScope(cb: () -> Unit): Unit {
        scopeStack.add(cb)
    }

    public static func exitScope(): Unit {
        scopeStack.remove(scopeStack.size - 1..scopeStack.size)
    }

    public static func currentSub(): Option<() -> Unit> {
        if (scopeStack.size > 0) { Some(scopeStack[scopeStack.size - 1]) } else { None }
    }
}

public class Signal<T> {
    var value: T
    let subs = ArrayList<() -> Unit>()

    public init(value: T) {
        this.value = value
    }

    public func get(): T {
        match (SignalTracker.currentSub()) {
            case Some(cb) => subs.add(cb)
            case None => ()
        }
        this.value
    }

    public func set(v: T): Unit {
        this.value = v
        for (fn in subs) { fn() }
    }

    public func update(fn: (T) -> T): Unit {
        this.set(fn(this.value))
    }

    public func subscribe(fn: () -> Unit): Unit {
        subs.add(fn)
    }

    public func clearSubs(): Unit {
        subs.clear()
    }
}
