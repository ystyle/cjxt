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
/// 守卫函数：None = 放行；Some(path) = 拒绝访问并跳转到 path。
/// 跳转目标由应用自己的守卫决定（不同页面/场景可返回不同路径），框架不感知业务。
public type GuardFn = (HashMap<String, String>) -> Option<String>

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
    let guards = HashMap<String, GuardFn>()
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

    /**
     * 注册路由。同路径重复注册时**替换**旧条目（后注册者生效）——
     * 保持与 `titles/guards/layouts` 的覆盖语义一致，避免全局单例
     * 在多处注册同一路径时残留陈旧工厂（如测试间复用 / 路由）。
     */
    public func register(path: String, factory: RouteFactory): Unit {
        this.removeEntry(path)
        entries.add((RouteEntry(path), factory))
    }

    public func register(path: String, factory: RouteFactory, title: String): Unit {
        this.removeEntry(path)
        entries.add((RouteEntry(path), factory))
        titles.add(path, title)
    }

    public func register(path: String, factory: RouteFactory, title: String, guard: GuardFn): Unit {
        this.removeEntry(path)
        entries.add((RouteEntry(path), factory))
        titles.add(path, title)
        guards.add(path, guard)
    }

    public func register(path: String, factory: RouteFactory, title: String, guard: GuardFn, layout: LayoutFn): Unit {
        this.removeEntry(path)
        entries.add((RouteEntry(path), factory))
        titles.add(path, title)
        guards.add(path, guard)
        layouts.add(path, layout)
    }

    /** 移除已注册的同路径条目（entries 是 ArrayList，倒序删除避免索引失效） */
    private func removeEntry(path: String): Unit {
        var i = entries.size - 1
        while (i >= 0) {
            let (entry, _) = entries[i]
            if (entry.path == path) {
                entries.remove(at: i)
            }
            i = i - 1
        }
    }

    /** 已注册路由条目数（含同路径去重后的结果） */
    public func entriesSize(): Int64 {
        entries.size
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

    /**
     * 执行路径守卫：None = 放行；Some(path) = 拒绝访问并跳转到守卫指定的路径。
     * 守卫的跳转目标由应用自己决定（可因页面/场景而异），框架不感知业务。
     */
    public func resolveGuard(path: String, ctx: HashMap<String, String>): Option<String> {
        for (p in guards.keys()) {
            let entry = RouteEntry(p)
            match (entry.doMatch(path)) {
                case Some(_) => match (guards.get(p)) {
                    case Some(fn) => return fn(ctx)
                    case None => return None
                }
                case None => ()
            }
        }
        None
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
