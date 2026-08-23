package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ============ Cascader 级联选择器（对齐 Element Plus，服务端驱动 v1） ============
//
// 用法：
//   Cascader(regions, st.cascaderSelected)
//   regions: ArrayList<CascaderNode>（label/value/children）
//   selected: Signal<ArrayList<String>>（外部，选中的各级 value）
//
// 点击输入框开/关面板；面板按 activePath 渲染多列；点父节点追加一层列；点叶子选中并关闭。

public class Cascader <: Component {
    let _options: ArrayList<CascaderNode>
    var _selected: Signal<ArrayList<String>>
    var _open = Signal<Bool>(false)
    var _activePath = Signal<ArrayList<String>>(ArrayList<String>())
    var _onChange: Option<(ArrayList<String>) -> Unit> = None

    public init(options: ArrayList<CascaderNode>, selected: Signal<ArrayList<String>>) {
        this._options = options
        this._selected = selected
    }

    public func onChange(h: (ArrayList<String>) -> Unit): Cascader {
        this._onChange = Some(h)
        this
    }

    public func render(): IComponent {
        let open = this._open.get()
        let selected = this._selected.get()
        let labels = cascaderPathLabels(this._options, selected)
        var display = "请选择"
        var di = 0
        for (l in labels) {
            if (di == 0) { display = l } else { display = "${display} / ${l}" }
            di += 1
        }

        let toggle: ActionHandler = { ctx =>
            this._open.set(!this._open.get())
            this._activePath.set(ArrayList<String>())
            PatchResult.ReRender
        }
        // 输入框（只读显示路径）
        let inputInner = VNode("input", [], attrs: Some(HashMap<String, String>([("type", "text"), ("readonly", "readonly"), ("placeholder", "请选择"), ("value", display), ("class", "el-input__inner")])))
        let wrapper = VNode("div", [inputInner], attrs: Some(HashMap<String, String>([("class", "el-input__wrapper")])))
        let input = VNode("div", [wrapper], attrs: Some(HashMap<String, String>([("class", "el-input el-cascader__input")]))).onClick(toggle)

        let parts = ArrayList<IComponent>()
        parts.add(input)
        if (open) {
            let panel = this.buildPanel()
            let popper = VNode("div", [panel], attrs: Some(HashMap<String, String>([("class", "el-cascader__dropdown"), ("style", "position:absolute;top:100%;left:0;z-index:2000;margin-top:4px")])))
            parts.add(popper)
        }
        VNode("div", parts.toArray(), attrs: Some(HashMap<String, String>([("class", "el-cascader")])))
    }

    func buildPanel(): IComponent {
        let activePath = this._activePath.get()
        let columns = cascaderColumns(this._options, activePath)
        let menus = ArrayList<IComponent>()
        for (col in columns) {
            menus.add(this.buildMenu(col))
        }
        VNode("div", menus.toArray(), attrs: Some(HashMap<String, String>([("class", "el-cascader-panel")])))
    }

    func buildMenu(nodes: ArrayList<CascaderNode>): IComponent {
        let list = ArrayList<IComponent>()
        for (n in nodes) {
            list.add(this.buildNode(n))
        }
        let wrap = VNode("div", list.toArray(), attrs: Some(HashMap<String, String>([("class", "el-cascader-menu__list")])))
        VNode("div", [wrap], attrs: Some(HashMap<String, String>([("class", "el-cascader-menu")])))
    }

    func buildNode(node: CascaderNode): IComponent {
        let activePath = this._activePath.get()
        let selected = this._selected.get()
        let isLeaf = node.isLeaf()
        // in-active-path：活动路径（正在导航经过）；is-active：最终选中路径的某层
        var inPath = activePath.contains(node.value)
        var isActive = selected.contains(node.value)
        var nodeCls = "el-cascader-node"
        if (inPath) { nodeCls = "${nodeCls} in-active-path" }
        if (isActive) { nodeCls = "${nodeCls} is-active" }
        if (isLeaf) { nodeCls = "${nodeCls} is-leaf" }

        let h: ActionHandler = { ctx =>
            if (node.isLeaf()) {
                // 选中：selected = activePath + [value]
                let next = cascaderAppend(activePath, node.value)
                this._selected.set(next)
                match (this._onChange) {
                    case Some(cb) => cb(next)
                    case None => ()
                }
                this._open.set(false)
            } else {
                this._activePath.set(cascaderAppend(activePath, node.value))
            }
            PatchResult.ReRender
        }
        let label = VNode("span", [text(node.label)], attrs: Some(HashMap<String, String>([("class", "el-cascader-node__label")])))
        let parts = ArrayList<IComponent>()
        parts.add(label)
        if (!isLeaf) {
            parts.add(VNode("span", [text("❯")], attrs: Some(HashMap<String, String>([("class", "el-cascader-node__postfix")]))))
        }
        let nodeEl = VNode("div", parts.toArray(), attrs: Some(HashMap<String, String>([("class", nodeCls)])))
        nodeEl.onClick(h)
    }
}
