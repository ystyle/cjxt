package cjxt

import std.collection.{HashMap, ArrayList}

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
        if (paramNames.size == 0) { return None }
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

public type RouteFactory = () -> IComponent
public type LayoutFn = (IComponent) -> IComponent

public struct RouteMatch {
    let component: IComponent
    let params: HashMap<String, String>

    public init(component: IComponent, params: HashMap<String, String>) {
        this.component = component
        this.params = params
    }
}

public class RouteRegistry {
    let entries = ArrayList<(RouteEntry, RouteFactory)>()
    let titles = HashMap<String, String>()
    let guards = HashMap<String, (HashMap<String, String>) -> Bool>()
    let layouts = HashMap<String, LayoutFn>()

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
        entries.add((RouteEntry(path), factory))
    }

    public func register(path: String, factory: RouteFactory, title: String): Unit {
        entries.add((RouteEntry(path), factory))
        titles.add(path, title)
    }

    public func register(path: String, factory: RouteFactory, title: String, guard: (HashMap<String, String>) -> Bool): Unit {
        entries.add((RouteEntry(path), factory))
        titles.add(path, title)
        guards.add(path, guard)
    }

    public func register(path: String, factory: RouteFactory, title: String, guard: (HashMap<String, String>) -> Bool, layout: LayoutFn): Unit {
        entries.add((RouteEntry(path), factory))
        titles.add(path, title)
        guards.add(path, guard)
        layouts.add(path, layout)
    }

    public func resolve(path: String): Option<RouteMatch> {
        for ((entry, factory) in entries) {
            match (entry.doMatch(path)) {
                case Some(params) => return Some(RouteMatch(factory(), params))
                case None => ()
            }
        }
        None
    }

    public func create(path: String): Option<IComponent> {
        match (this.resolve(path)) {
            case Some(m) => Some(m.component)
            case None => None
        }
    }

    public func getTitle(path: String): Option<String> {
        for (p in titles.keys()) {
            let entry = RouteEntry(p)
            match (entry.doMatch(path)) {
                case Some(_) => return titles.get(p)
                case None => ()
            }
        }
        None
    }

    public func checkGuard(path: String, ctx: HashMap<String, String>): Bool {
        for (p in guards.keys()) {
            let entry = RouteEntry(p)
            match (entry.doMatch(path)) {
                case Some(_) => match (guards.get(p)) {
                    case Some(fn) => return fn(ctx)
                    case None => return true
                }
                case None => ()
            }
        }
        true
    }

    public func getLayout(path: String): Option<LayoutFn> {
        for (p in layouts.keys()) {
            let entry = RouteEntry(p)
            match (entry.doMatch(path)) {
                case Some(_) => return layouts.get(p)
                case None => ()
            }
        }
        None
    }
}
