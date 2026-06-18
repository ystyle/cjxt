package cjxt

import std.collection.ArrayList

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
}
