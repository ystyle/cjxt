package cjxt

import std.collection.ArrayList

public class SignalTracker {
    public static var pendingSub: Option<() -> Unit> = None
}

public class Signal<T> {
    var value: T
    let subs = ArrayList<() -> Unit>()

    public init(value: T) {
        this.value = value
    }

    public func get(): T {
        match (SignalTracker.pendingSub) {
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
}
