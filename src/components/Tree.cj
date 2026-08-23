package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ============ Tree 树形控件（对齐 Element Plus） ============

public class TreeNode {
    public let label: String
    public let children: ArrayList<TreeNode>
    public let disabled: Bool

    public init(label: String, children: ArrayList<TreeNode>, disabled: Bool) {
        this.label = label
        this.children = children
        this.disabled = disabled
    }

    public init(label: String) {
        this.label = label
        this.children = ArrayList<TreeNode>()
        this.disabled = false
    }

    public init(label: String, children: ArrayList<TreeNode>) {
        this.label = label
        this.children = children
        this.disabled = false
    }
}

public class Tree <: Component {
    let _data: ArrayList<TreeNode>
    var _expanded = Signal<HashMap<String, Bool>>(HashMap<String, Bool>())
    var _currentKey = Signal<String>("")          // 当前选中路径（外部可读/写）
    var _onNodeClick: Option<(String, String) -> Unit> = None

    public init(data: ArrayList<TreeNode>) {
        this._data = data
    }

    // 展开状态外置：父重渲染会 new 新 Tree 实例，内部信号丢失 → 需外部持有（Table 经验）
    public func expanded(v: Signal<HashMap<String, Bool>>): Tree {
        this._expanded = v
        this
    }

    // 当前选中路径外置（外部可传入信号做受控，或读当前值）
    public func currentKey(v: Signal<String>): Tree {
        this._currentKey = v
        this
    }

    public func onNodeClick(h: (String, String) -> Unit): Tree {
        this._onNodeClick = Some(h)
        this
    }

    public func render(): IComponent {
        let children = ArrayList<IComponent>()
        var i = 0
        for (node in this._data) {
            children.add(this.renderNode(node, "", i))
            i += 1
        }
        VNode("div", children.toArray(), attrs: Some(HashMap<String, String>([("class", "el-tree el-tree--highlight-current")])))
    }

    func renderNode(node: TreeNode, parentPath: String, idx: Int64): IComponent {
        let path = treeChildPath(parentPath, idx)
        let expanded = treeIsExpanded(this._expanded.get(), path)
        let isLeaf = node.children.size == 0
        let isCurrent = this._currentKey.get() == path

        // 展开图标
        var iconCls = "el-tree-node__expand-icon"
        if (expanded) { iconCls = "${iconCls} expanded" }
        if (isLeaf) { iconCls = "${iconCls} is-leaf" }
        let toggleH: ActionHandler = { ctx =>
            if (!isLeaf) {
                this._expanded.set(treeToggle(this._expanded.get(), path))
            }
            PatchResult.ReRender
        }
        let icon = VNode("span", [text("❯")], attrs: Some(HashMap<String, String>([("class", iconCls)]))).onClick(toggleH)

        // label
        let labelH: ActionHandler = { ctx =>
            this._currentKey.set(path)
            match (this._onNodeClick) {
                case Some(cb) => cb(path, node.label)
                case None => ()
            }
            PatchResult.ReRender
        }
        let label = VNode("span", [text(node.label)], attrs: Some(HashMap<String, String>([("class", "el-tree-node__label")]))).onClick(labelH)

        let content = VNode("div", [icon, label], attrs: Some(HashMap<String, String>([("class", "el-tree-node__content")])))

        // 根节点类
        var nodeCls = "el-tree-node"
        if (expanded) { nodeCls = "${nodeCls} is-expanded" }
        if (isCurrent) { nodeCls = "${nodeCls} is-current" }
        if (isLeaf) { nodeCls = "${nodeCls} is-leaf" }

        let parts = ArrayList<IComponent>()
        parts.add(content)
        if (!isLeaf && expanded) {
            let childParts = ArrayList<IComponent>()
            var ci = 0
            for (c in node.children) {
                childParts.add(this.renderNode(c, path, ci))
                ci += 1
            }
            parts.add(VNode("div", childParts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-tree-node__children")]))))
        }
        VNode("div", parts.toArray(), attrs: Some(HashMap<String, String>([("class", nodeCls)])))
    }
}
