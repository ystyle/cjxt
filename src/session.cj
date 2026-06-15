package cjxt

import std.collection.HashMap
import std.time.{DateTime, TimeZone}
import opencj::ulid.*

public enum WsState {
    | Connecting | Connected | Disconnected
}

public class Session {
    let id: String
    var page: Component
    var tree: ComponentNode
    var path: String
    var wsState: WsState
    var createdAt: Int64
    var lastActiveAt: Int64
    let context: HashMap<String, String>

    public init(id: String, page: Component, tree: ComponentNode) {
        this.id = id
        this.page = page
        this.tree = tree
        this.path = "/"
        this.wsState = WsState.Connecting
        this.createdAt = nowMillis()
        this.lastActiveAt = nowMillis()
        this.context = HashMap<String, String>()
    }

    public func touch(): Unit {
        this.lastActiveAt = nowMillis()
    }

    public func updatePage(page: Component, tree: ComponentNode): Unit {
        this.page = page
        this.tree = tree
        this.touch()
    }

    public func isExpired(ttlMillis: Int64): Bool {
        nowMillis() - this.lastActiveAt > ttlMillis
    }
}

public class SessionManager {
    let sessions = HashMap<String, Session>()
    let ttlMillis: Int64

    public init(ttlMillis: Int64) {
        this.ttlMillis = ttlMillis
    }

    public func create(page: Component, tree: ComponentNode): Session {
        let id = this.generateId()
        let session = Session(id, page, tree)
        sessions.add(id, session)
        session
    }

    public func save(id: String, page: Component, tree: ComponentNode): Session {
        let session = Session(id, page, tree)
        sessions.add(id, session)
        session
    }

    public func get(id: String): Option<Session> {
        sessions.get(id)
    }

    public func remove(id: String): Unit {
        sessions.remove(id)
    }

    public func cleanup(): Unit {
        for ((id, session) in sessions) {
            if (session.isExpired(ttlMillis)) {
                sessions.remove(id)
            }
        }
    }

    public func generateId(): String {
        nextId()
    }
}

func nowMillis(): Int64 {
    DateTime.nowUTC().toUnixTimeStamp().toMilliseconds()
}
