package cjxt

public class Store<S> {
    let signal: Signal<S>

    public init(initial: S) {
        this.signal = Signal<S>(initial)
    }

    public func get(): S {
        this.signal.get()
    }

    public func set(updater: (S) -> S): Unit {
        this.signal.update(updater)
    }

    public func subscribe(fn: () -> Unit): Unit {
        this.signal.subscribe(fn)
    }
}
