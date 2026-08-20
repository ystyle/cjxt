package cjxt

import std.collection.{ArrayList, HashMap}
import std.convert.*

func doReplace(c: IComponent, parts: Array<String>, idx: Int64, newSubtree: IComponent): IComponent {
    if (idx >= parts.size) { return newSubtree }
    let childIdx = Int64.parse(parts[idx + 1], radix: 10)
    match (c) {
        case v: VNode =>
            let newChildren = ArrayList<IComponent>()
            for (i in 0..v._children.size) {
                if (i == childIdx) {
                    newChildren.add(doReplace(v._children[i], parts, idx + 2, newSubtree))
                } else {
                    newChildren.add(v._children[i])
                }
            }
            VNode(v._tag, newChildren.toArray(), attrs: v._attrs, key: v._key, actions: v._actions, handlers: v._handlers)
        case f: FragmentNode =>
            let newChildren = ArrayList<IComponent>()
            for (i in 0..f._children.size) {
                if (i == childIdx) {
                    newChildren.add(doReplace(f._children[i], parts, idx + 2, newSubtree))
                } else {
                    newChildren.add(f._children[i])
                }
            }
            FragmentNode(newChildren.toArray())
        case _ => newSubtree
    }
}

func doCollectMap(m: HashMap<String, ActionHandler>, out: HashMap<String, ActionHandler>): Unit {
    for ((k, v) in m) { out.add(k, v) }
}

// 把 VNode 的 handler id 从「全局计数」稳定化为「节点路径 + 事件」派生。
// 服务端每次重渲染都会重新调用 render()/nextHid() 生成全新 id，若前端 DOM
// 上的 data-action-* 属性持有旧 id，事件（点击/按键）就会因 handler 查不到而失效。
// 稳定 id 使重渲染后 id 不变，前端属性无需同步也不会过期。
func stabilizeVNodeHandlers(v: VNode, path: String): VNode {
    var newActions: Option<ActionMap> = None
    var newAttrs: Option<Attributes> = None
    let newHandlers = HashMap<String, ActionHandler>()
    // 记录已被稳定化重映射的原始 id（重映射后原始 id 不再保留）
    let consumed = ArrayList<String>()

    // 1) 重映射 actions：仅当该值在 _handlers 中存在（真 handler id）才稳定化；
    //    字面量命名 action（button(actions: {"click": "submit"})）保持原样。
    match (v._actions) {
        case Some(a) =>
            let na = HashMap<String, String>()
            for ((ev, val) in a) {
                match (v._handlers) {
                    case Some(h) => match (h.get(val)) {
                        case Some(fn) =>
                            let stable = makeStableHandlerId(path, ev)
                            na[ev] = stable
                            newHandlers[stable] = fn
                            consumed.add(val)
                        case None => na[ev] = val
                    }
                    case None => na[ev] = val
                }
            }
            newActions = Some(na)
        case None => ()
    }

    // 2) 重映射 bind handler：data-bind-id → "${path}:bind"
    match (v._attrs) {
        case Some(m) => match (m.get("data-bind-id")) {
            case Some(oldBid) =>
                match (v._handlers) {
                    case Some(h) => match (h.get(oldBid)) {
                        case Some(fn) =>
                            let stable = makeStableBindId(path)
                            newHandlers[stable] = fn
                            consumed.add(oldBid)
                            let na = doCloneAttrMap(m)
                            na["data-bind-id"] = stable
                            newAttrs = Some(na)
                        case None => newAttrs = Some(m)
                    }
                    case None => newAttrs = Some(m)
                }
            case None => newAttrs = Some(m)
        }
        case None => ()
    }

    // 3) 保留未被 actions/bind 引用的其他 handler（防御性，一般不存在）
    match (v._handlers) {
        case Some(h) =>
            for ((id, fn) in h) {
                if (!consumed.contains(id)) { newHandlers[id] = fn }
            }
        case None => ()
    }

    let finalHandlers = if (newHandlers.size > 0) { Some(newHandlers) } else { v._handlers }
    VNode(v._tag, v._children, attrs: newAttrs, key: v._key, actions: newActions, handlers: finalHandlers)
}

// 路径中的分隔符对 JS 属性名/服务端 map key 都是安全的（含 / : 字符）
func makeStableHandlerId(path: String, ev: String): String {
    if (path == "") { "h:${ev}" } else { "h:${path}:${ev}" }
}

func makeStableBindId(path: String): String {
    if (path == "") { "b:bind" } else { "b:${path}:bind" }
}

func doCloneAttrMap(m: HashMap<String, String>): HashMap<String, String> {
    let c = HashMap<String, String>()
    for ((k, v) in m) { c[k] = v }
    c
}

func hasDirtyParent(c: IComponent, all: ArrayList<IComponent>): Bool {
    let cp = c.getPath()
    for (other in all) {
        let op = other.getPath()
        if (op != "" && cp.indexOf("${op}/") == Some(0)) {
            return true
        }
    }
    false
}

public class RenderContext {
    // 遍历并展开整棵组件树，为 IComponent 分配路径
    // 返回展开后的纯 VNode/TextNode/FragmentNode/EmptyNode 树
    // 注意：该函数会调用 IComponent.renderWithScope()，适合用于初始展开
    public static func expandTree(c: IComponent, path: String): IComponent {
        match (c) {
            case v: VNode =>
                let expanded = ArrayList<IComponent>()
                for (i in 0..v._children.size) {
                    let cp = if (path == "") { "children/${i}" } else { "${path}/children/${i}" }
                    expanded.add(expandTree(v._children[i], cp))
                }
                // 稳定 handler id：重渲染后事件 id 不变，前端 DOM 不失效
                let stable = stabilizeVNodeHandlers(v, path)
                stable.children(expanded.toArray())
            case f: FragmentNode =>
                let expanded = ArrayList<IComponent>()
                for (i in 0..f._children.size) {
                    expanded.add(expandTree(f._children[i], path))
                }
                FragmentNode(expanded.toArray())
            case b: Component =>
                b.setPath(path)
                let rendered = b.renderWithScope(path)
                expandTree(rendered, path)
            case t: TextNode => t
            case e: EmptyNode => e
            case cc: ClientComponentNode => cc
            case other =>
                expandTree(other.render(), path)
        }
    }

    // 在展开树中替换指定路径的子树（不调用 render）
    // 用于增量更新 session.tree
    public static func replaceTreeAtPath(tree: IComponent, path: String, newSubtree: IComponent): IComponent {
        if (path == "") { return newSubtree }
        let parts = path.split("/")
        doReplace(tree, parts, 0, newSubtree)
    }

    // 从展开树重建 handler 映射
    public static func collectHandlersFromTree(c: IComponent, out: HashMap<String, ActionHandler>): Unit {
        match (c) {
            case v: VNode =>
                match (v._handlers) {
                    case Some(m) => doCollectMap(m, out)
                    case None => ()
                }
                for (child in v._children) {
                    collectHandlersFromTree(child, out)
                }
            case f: FragmentNode =>
                for (child in f._children) {
                    collectHandlersFromTree(child, out)
                }
            case cc: ClientComponentNode =>
                cc.collectHandlers(out)
            case _ => ()
        }
    }

    // 收集脏组件（父覆盖子过滤：如果父组件也脏，子组件不单独处理）
    public static func collectDirty(): ArrayList<IComponent> {
        let all = SignalTracker.dirtyComponents
        let dirtyList = ArrayList<IComponent>()
        for (c in all) {
            if (c.isDirty()) {
                dirtyList.add(c)
            }
        }
        // 父覆盖子过滤
        let result = ArrayList<IComponent>()
        for (c in dirtyList) {
            if (!hasDirtyParent(c, dirtyList)) {
                result.add(c)
            }
        }
        result
    }

    // 清理所有脏标记
    public static func clearDirty(): Unit {
        for (c in SignalTracker.dirtyComponents) {
            c.clearDirty()
        }
        SignalTracker.dirtyComponents.clear()
    }
}
