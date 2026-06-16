package examples

import cjxt.*
import cjxt.macros.*
import std.collection.{ArrayList, HashMap}

let CSS = ###"
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif; background: #f0f2f5; color: #333; min-height: 100vh; }
.container { max-width: 640px; margin: 0 auto; padding: 24px 16px; }
.tabs { display: flex; background: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.08); margin-bottom: 20px; }
.tab { flex: 1; padding: 14px 20px; text-align: center; border: none; background: transparent; font-size: 15px; font-weight: 500; cursor: pointer; color: #666; }
.tab.active { color: #4f46e5; background: #f5f3ff; box-shadow: inset 0 -2px 0 #4f46e5; }
.card { background: #fff; border-radius: 12px; padding: 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); margin-bottom: 16px; }
.card-title { font-size: 16px; font-weight: 600; color: #111; margin-bottom: 16px; }
.counter-value { font-size: 48px; font-weight: 700; color: #4f46e5; text-align: center; padding: 20px 0; }
.row { display: flex; gap: 8px; flex-wrap: wrap; align-items: end; }
.btn { padding: 10px 20px; border: none; border-radius: 8px; font-size: 14px; font-weight: 500; cursor: pointer; }
.btn-primary { background: #4f46e5; color: #fff; }
.btn-outline { background: transparent; border: 1px solid #d1d5db; color: #374151; }
.btn-sm { padding: 6px 12px; font-size: 13px; }
.btn-danger { background: #fee2e2; color: #dc2626; }
.input { flex: 1; padding: 10px 14px; border: 1px solid #d1d5db; border-radius: 8px; font-size: 14px; outline: none; min-width: 120px; }
.input:focus { border-color: #4f46e5; box-shadow: 0 0 0 3px rgba(79,70,229,0.1); }
.label { font-size: 13px; font-weight: 500; color: #6b7280; margin-bottom: 6px; }
.desc { font-size: 13px; color: #9ca3af; margin-top: 4px; }
.todo-item { display: flex; align-items: center; gap: 12px; padding: 10px 0; border-bottom: 1px solid #f3f4f6; }
.todo-text { flex: 1; font-size: 14px; color: #333; }
.todo-empty { text-align: center; color: #9ca3af; padding: 40px 0; font-size: 14px; }
.footer { text-align: center; font-size: 12px; color: #d1d5db; margin-top: 24px; }
.input-group { margin-bottom: 14px; }
select.input { appearance: auto; }
"###

class TabState <: AppState {
    var active = Signal<String>("counter")
    var globalCount = Store<Int64>(0)
    var inputText = Signal<String>("")
    var inputEmail = Signal<String>("")
    var inputSearch = Signal<String>("")
    var todoInput = Signal<String>("")
    var todoItems = Signal<ArrayList<String>>(ArrayList<String>())
}

@Page["/"]
class ExampleApp <: Component {
    var data: Option<TabState> = None

    public func onMount(ctx: LifecycleContext): Unit {
        this.data = Some(ctx.getState<TabState>())
    }

    public func render(): ComponentNode {
        let d = match (this.data) {
            case Some(dd) => dd
            case None => TabState()
        }
        let tab = d.active.get()
        let tabContent = match (tab) {
            case "inputs" => renderInputs(d)
            case "todo" => renderTodo(d)
            case _ => renderCounter(d)
        }
        let attrContainer = HashMap<String, String>([("class", "container")])
        div([
            cssStyle(CSS),
            renderTabs(d, tab),
            tabContent,
            div([text("cjxt v0.1")], attrs: Some(HashMap<String, String>([("class", "footer")]))),
        ], attrs: Some(attrContainer))
    }
}

func renderTabs(d: TabState, active: String): ComponentNode {
    div([
        renderTab("counter", "Counter", active == "counter", d),
        renderTab("inputs", "Inputs", active == "inputs", d),
        renderTab("todo", "Todo", active == "todo", d),
    ], attrs: Some(HashMap<String, String>([("class", "tabs")])))
}

func renderTab(key: String, title: String, isActive: Bool, d: TabState): ComponentNode {
    let clsName = if (isActive) { "tab active" } else { "tab" }
    button(
        [text(title)],
        attrs: Some(HashMap<String, String>([("class", clsName)]))
    ).onClick({ ctx =>
        d.active.set(key)
        PatchResult.ReRender
    })
}

func renderCounter(d: TabState): ComponentNode {
    let attrCard = HashMap<String, String>([("class", "card")])
    let attrRow = HashMap<String, String>([("class", "row")])
    div([
        div([
            div([text("Global Counter")], attrs: Some(HashMap<String, String>([("class", "card-title")]))),
            div([text("${d.globalCount.get()}")], attrs: Some(HashMap<String, String>([("class", "counter-value")]))),
            div([
                btn("-5", "btn-outline", { ctx => d.globalCount.set({ v => v - 5 }); PatchResult.ReRender }),
                btn("-1", "btn-outline", { ctx => d.globalCount.set({ v => v - 1 }); PatchResult.ReRender }),
                btn("+1", "btn-primary", { ctx => d.globalCount.set({ v => v + 1 }); PatchResult.ReRender }),
                btn("+5", "btn-primary", { ctx => d.globalCount.set({ v => v + 5 }); PatchResult.ReRender }),
            ], attrs: Some(attrRow)),
            div([text("所有 session 共享")], attrs: Some(HashMap<String, String>([("class", "desc")]))),
        ], attrs: Some(attrCard)),
        div([
            div([text("关于 cjxt")], attrs: Some(HashMap<String, String>([("class", "card-title")]))),
            div([text("切换到 Inputs / Todo 标签页")], attrs: Some(HashMap<String, String>([("class", "desc")]))),
        ], attrs: Some(attrCard)),
    ])
}

func btn(label: String, style: String, action: ActionHandler): ComponentNode {
    button([text(label)]).className("btn ${style}").onClick(action)
}

func renderInputs(d: TabState): ComponentNode {
    let attrCard = HashMap<String, String>([("class", "card")])
    div([
        inputCard("文本输入", d.inputText, "输入任意文字...", "实时回显: ${d.inputText.get()}"),
        inputCard("Email", d.inputEmail, "name@example.com", "值: ${d.inputEmail.get()}"),
        inputCard("搜索", d.inputSearch, "搜索...", "内容: ${d.inputSearch.get()}"),
        div([
            div([text("多行文本")], attrs: Some(HashMap<String, String>([("class", "card-title")]))),
            div([text("Textarea 待框架扩展 tag 支持")]),
        ], attrs: Some(attrCard)),
    ])
}

func inputCard(title: String, signal: Signal<String>, placeholder: String, desc: String): ComponentNode {
    let attrCard = HashMap<String, String>([("class", "card")])
    div([
        div([text(title)], attrs: Some(HashMap<String, String>([("class", "card-title")]))),
        inputGroup(signal, placeholder),
        div([text(desc)], attrs: Some(HashMap<String, String>([("class", "desc")]))),
    ], attrs: Some(attrCard))
}

func inputGroup(signal: Signal<String>, placeholder: String): ComponentNode {
    let a = HashMap<String, String>()
    a["class"] = "input"
    a["placeholder"] = placeholder
    div([
        input(attrs: Some(a)).bind(signal),
    ], attrs: Some(HashMap<String, String>([("class", "input-group")])))
}

func renderTodo(d: TabState): ComponentNode {
    let items = d.todoItems.get()
    let attrCard = HashMap<String, String>([("class", "card")])
    let attrRow = HashMap<String, String>([("class", "row")])
    div([
        div([
            div([text("添加待办")], attrs: Some(HashMap<String, String>([("class", "card-title")]))),
            div([
                todoInput(d.todoInput),
                button([text("添加")]).className("btn btn-primary").onClick({ ctx =>
                    let text = d.todoInput.get()
                    if (text != "") {
                        d.todoItems.update({ list => list.add(text); list })
                        d.todoInput.set("")
                    }
                    PatchResult.ReRender
                }),
            ], attrs: Some(attrRow)),
        ], attrs: Some(attrCard)),
        div([
            div([text("待办列表 (${items.size})")], attrs: Some(HashMap<String, String>([("class", "card-title")]))),
            renderTodoList(items, d, attrCard),
        ], attrs: Some(attrCard)),
    ])
}

func todoInput(signal: Signal<String>): ComponentNode {
    let a = HashMap<String, String>()
    a["class"] = "input"
    a["placeholder"] = "输入待办事项..."
    input(attrs: Some(a)).bind(signal)
}

func renderTodoList(items: ArrayList<String>, d: TabState, attrCard: HashMap<String, String>): ComponentNode {
    if (items.size == 0) {
        return div([text("还没有待办事项 :)")], attrs: Some(HashMap<String, String>([("class", "todo-empty")])))
    }
    let children = ArrayList<ComponentNode>()
    for (i in 0..items.size) {
        let item = items[i]
        let idx = i
        children.add(
            div([
                span([text(item)]).className("todo-text"),
                button([text("删除")]).className("btn btn-sm btn-danger").onClick({ ctx =>
                    d.todoItems.update({ list => list.remove(idx..idx + 1); list })
                    PatchResult.ReRender
                }),
            ]).className("todo-item")
        )
    }
    div(children.toArray())
}
