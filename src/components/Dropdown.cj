package cjxt.components

import cjxt.*
import std.collection.{ArrayList, HashMap}

// ============ Dropdown 下拉菜单（对齐 Element Plus，服务端驱动） ============
//
// 用法：
//   Dropdown(Button("更多")).menu([
//       DropdownItem().content("编辑").command("edit"),
//       DropdownItem().content("删除").command("del").divided(),
//   ]).onCommand { cmd => ... }
//
// 触发点击切换面板（内部 _open 信号，脏追踪自渲染）；菜单项点击 → 关面板 + onCommand(cmd)。

public class DropdownItem <: Component {
    var _content: String = ""
    var _command: String = ""
    var _disabled: Bool = false
    var _divided: Bool = false

    public func content(v: String): DropdownItem { this._content = v; this }
    public func command(v: String): DropdownItem { this._command = v; this }
    public func disabled(v: Bool): DropdownItem { this._disabled = v; this }
    public func divided(): DropdownItem { this._divided = true; this }

    public func render(): IComponent {
        div([]) // 数据载体
    }
}

public class Dropdown <: Component {
    let _trigger: IComponent
    var _items: Array<IComponent> = []
    var _onCommand: Option<(String) -> Unit> = None
    var _open = Signal<Bool>(false)

    public init(trigger: IComponent) {
        this._trigger = trigger
    }

    public func menu(items: Array<IComponent>): Dropdown {
        this._items = items
        this
    }

    public func onCommand(h: (String) -> Unit): Dropdown {
        this._onCommand = Some(h)
        this
    }

    public func render(): IComponent {
        let items = this.collectItems()
        let toggle: ActionHandler = { ctx =>
            this._open.set(!this._open.get())
            PatchResult.ReRender
        }
        // trigger
        let triggerSpan = VNode("span", [this._trigger], attrs: Some(HashMap<String, String>([("class", "el-dropdown__trigger")]))).onClick(toggle)
        // popper + menu
        let menuItems = ArrayList<IComponent>()
        for (item in items) {
            if (item._divided) {
                menuItems.add(VNode("li", [], attrs: Some(HashMap<String, String>([("class", "el-dropdown__menu__item--divided"), ("role", "separator")]))))
            }
            let itemH: ActionHandler = { ctx =>
                this._open.set(false)
                match (this._onCommand) {
                    case Some(cb) => if (!item._disabled) { cb(item._command) }
                    case None => ()
                }
                PatchResult.ReRender
            }
            var liCls = "el-dropdown__menu__item"
            if (item._disabled) { liCls = "${liCls} is-disabled" }
            let li = VNode("li", [text(item._content)], attrs: Some(HashMap<String, String>([("class", liCls)]))).onClick(itemH)
            menuItems.add(li)
        }
        let menuUl = VNode("ul", menuItems.toArray(), attrs: Some(HashMap<String, String>([("class", "el-dropdown__menu")])))
        let open = this._open.get()
        let popperStyle = "position:absolute;top:100%;left:0;z-index:2000;margin-top:4px${if (open) { "" } else { ";display:none" }}"
        let popper = VNode("div", [menuUl], attrs: Some(HashMap<String, String>([("class", "el-dropdown__popper el-popper"), ("style", popperStyle)])))
        // container
        VNode("div", [triggerSpan, popper], attrs: Some(HashMap<String, String>([("class", "el-dropdown")])))
    }

    func collectItems(): ArrayList<DropdownItem> {
        let result = ArrayList<DropdownItem>()
        for (c in this._items) {
            match (c) {
                case item: DropdownItem => result.add(item)
                case _ => ()
            }
        }
        result
    }
}
