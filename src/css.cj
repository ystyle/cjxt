package cjxt

import std.collection.HashMap

public struct CssModule {
    let map: HashMap<String, String>

    public init(map: HashMap<String, String>) {
        this.map = map
    }

    public func get(name: String): String {
        match (this.map.get(name)) {
            case Some(v) => v
            case None => ""
        }
    }
}

public func cssModule(pairs: Array<(String, String)>): CssModule {
    let m = HashMap<String, String>()
    for ((k, v) in pairs) { m.add(k, v) }
    CssModule(m)
}
