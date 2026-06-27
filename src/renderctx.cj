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
                VNode(v._tag, expanded.toArray(), attrs: v._attrs, key: v._key, actions: v._actions, handlers: v._handlers)
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
