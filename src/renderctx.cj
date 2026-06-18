package cjxt

import std.collection.ArrayList

func hasDirtyParent(c: BaseComponent, all: ArrayList<BaseComponent>): Bool {
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
    // 遍历并展开整棵组件树，为 BaseComponent 分配路径
    // 返回展开后的纯 VNode/TextNode/FragmentNode/EmptyNode 树
    public static func expandTree(c: Component, path: String): Component {
        match (c) {
            case v: VNode =>
                let expanded = ArrayList<Component>()
                for (i in 0..v._children.size) {
                    let cp = if (path == "") { "children/${i}" } else { "${path}/children/${i}" }
                    expanded.add(expandTree(v._children[i], cp))
                }
                VNode(v._tag, expanded.toArray(), attrs: v._attrs, key: v._key, actions: v._actions, handlers: v._handlers)
            case f: FragmentNode =>
                let expanded = ArrayList<Component>()
                for (i in 0..f._children.size) {
                    expanded.add(expandTree(f._children[i], path))
                }
                FragmentNode(expanded.toArray())
            case b: BaseComponent =>
                b.setPath(path)
                let rendered = b.renderWithScope(path)
                expandTree(rendered, path)
            case t: TextNode => t
            case e: EmptyNode => e
            case other =>
                expandTree(other.render(), path)
        }
    }

    // 收集脏组件（父覆盖子过滤：如果父组件也脏，子组件不单独处理）
    public static func collectDirty(): ArrayList<BaseComponent> {
        let all = SignalTracker.dirtyComponents
        let dirtyList = ArrayList<BaseComponent>()
        for (c in all) {
            if (c.isDirty()) {
                dirtyList.add(c)
            }
        }
        // 父覆盖子过滤
        let result = ArrayList<BaseComponent>()
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
