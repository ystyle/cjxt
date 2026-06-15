package cjxt

import std.collection.{HashMap, ArrayList}

// ---- 路由条目 ----

public struct RouteEntry {
    let path: String
    let paramNames: Array<String>

    public init(path: String) {
        this.path = path
        this.paramNames = extractParamNames(path)
    }

    public func doMatch(requestPath: String): Option<HashMap<String, String>> {
        if (path == requestPath) {
            return Some(HashMap<String, String>())
        }
        let parts = requestPath.split("/")
        let pattern = path.split("/")
        if (parts.size != pattern.size) {
            return None
        }
        let params = HashMap<String, String>()
        for (i in 0..parts.size) {
            if (pattern[i].startsWith("[") && pattern[i].endsWith("]")) {
                let name = pattern[i][1..pattern[i].size - 1]
                params.add(name, parts[i])
            } else if (pattern[i] != parts[i]) {
                return None
            }
        }
        Some(params)
    }
}

private func extractParamNames(path: String): Array<String> {
    let names = ArrayList<String>()
    for (segment in path.split("/")) {
        if (segment.startsWith("[") && segment.endsWith("]")) {
            names.add(segment[1..segment.size - 1])
        }
    }
    names.toArray()
}

// ---- 全局路由注册表 ----

public type RouteFactory = () -> Component

public class RouteRegistry {
    let entries = HashMap<String, RouteFactory>()

    private static var inst: Option<RouteRegistry> = None

    public static func global(): RouteRegistry {
        match (inst) {
            case Some(r) => r
            case None => createGlobal()
        }
    }

    private static func createGlobal(): RouteRegistry {
        let r = RouteRegistry()
        inst = Some(r)
        r
    }

    public func register(path: String, factory: RouteFactory): Unit {
        entries.add(path, factory)
    }

    public func create(path: String): Option<Component> {
        match (entries.get(path)) {
            case Some(f) => Some(f())
            case None => None
        }
    }
}
