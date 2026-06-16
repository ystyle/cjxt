package examples

import cjxt.*
import cjxt.macros.*
import std.collection.{ArrayList, HashMap}

let css = @importCSS("style.css")
func cls(name: String): String { css.get(name) }

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
        div([
            renderTabs(d, tab),
            tabContent,
            div([text("cjxt v0.1")], attrs: Some(HashMap<String, String>([("class", cls("footer"))]))),
        ], attrs: Some(HashMap<String, String>([("class", cls("container"))])))
    }
}

func renderTabs(d: TabState, active: String): ComponentNode {
    div([
        renderTab("counter", "Counter", active == "counter", d),
        renderTab("inputs", "Inputs", active == "inputs", d),
        renderTab("todo", "Todo", active == "todo", d),
    ], attrs: Some(HashMap<String, String>([("class", cls("tabs"))])))
}

func renderTab(key: String, title: String, isActive: Bool, d: TabState): ComponentNode {
    let clsName = if (isActive) { cls("tab") + " " + cls("active") } else { cls("tab") }
    button(
        [text(title)],
        attrs: Some(HashMap<String, String>([("class", clsName)]))
    ).onClick({ ctx =>
        d.active.set(key)
        PatchResult.ReRender
    })
}

func renderCounter(d: TabState): ComponentNode {
    let attrCard = HashMap<String, String>([("class", cls("card"))])
    let attrRow = HashMap<String, String>([("class", cls("row"))])
    div([
        div([
            div([text("Global Counter")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
            div([text("${d.globalCount.get()}")], attrs: Some(HashMap<String, String>([("class", cls("counter-value"))]))),
            div([
                btn("-5", "btn-outline", { ctx => d.globalCount.set({ v => v - 5 }); PatchResult.ReRender }),
                btn("-1", "btn-outline", { ctx => d.globalCount.set({ v => v - 1 }); PatchResult.ReRender }),
                btn("+1", "btn-primary", { ctx => d.globalCount.set({ v => v + 1 }); PatchResult.ReRender }),
                btn("+5", "btn-primary", { ctx => d.globalCount.set({ v => v + 5 }); PatchResult.ReRender }),
            ], attrs: Some(attrRow)),
            div([text("所有 session 共享")], attrs: Some(HashMap<String, String>([("class", cls("desc"))]))),
        ], attrs: Some(attrCard)),
        div([
            div([text("关于 cjxt")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
            div([text("切换到 Inputs / Todo 标签页")], attrs: Some(HashMap<String, String>([("class", cls("desc"))]))),
        ], attrs: Some(attrCard)),
    ])
}

func btn(label: String, style: String, action: ActionHandler): ComponentNode {
    button([text(label)]).className(cls("btn") + " " + cls(style)).onClick(action)
}

func renderInputs(d: TabState): ComponentNode {
    let attrCard = HashMap<String, String>([("class", cls("card"))])
    div([
        inputCard("文本输入", d.inputText, "输入任意文字...", "实时回显: ${d.inputText.get()}"),
        inputCard("Email", d.inputEmail, "name@example.com", "值: ${d.inputEmail.get()}"),
        inputCard("搜索", d.inputSearch, "搜索...", "内容: ${d.inputSearch.get()}"),
        div([
            div([text("多行文本")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
            div([text("Textarea 待框架扩展 tag 支持")]),
        ], attrs: Some(attrCard)),
    ])
}

func inputCard(title: String, signal: Signal<String>, placeholder: String, desc: String): ComponentNode {
    let attrCard = HashMap<String, String>([("class", cls("card"))])
    div([
        div([text(title)], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
        inputGroup(signal, placeholder),
        div([text(desc)], attrs: Some(HashMap<String, String>([("class", cls("desc"))]))),
    ], attrs: Some(attrCard))
}

func inputGroup(signal: Signal<String>, placeholder: String): ComponentNode {
    let a = HashMap<String, String>()
    a["class"] = cls("input")
    a["placeholder"] = placeholder
    div([
        input(attrs: Some(a)).bind(signal),
    ], attrs: Some(HashMap<String, String>([("class", cls("input-group"))])))
}

func renderTodo(d: TabState): ComponentNode {
    let items = d.todoItems.get()
    let attrCard = HashMap<String, String>([("class", cls("card"))])
    let attrRow = HashMap<String, String>([("class", cls("row"))])
    div([
        div([
            div([text("添加待办")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
            div([
                todoInput(d.todoInput),
                button([text("添加")]).className(cls("btn") + " " + cls("btn-primary")).onClick({ ctx =>
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
            div([text("待办列表 (${items.size})")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
            renderTodoList(items, d, attrCard),
        ], attrs: Some(attrCard)),
    ])
}

func todoInput(signal: Signal<String>): ComponentNode {
    let a = HashMap<String, String>()
    a["class"] = cls("input")
    a["placeholder"] = "输入待办事项..."
    input(attrs: Some(a)).bind(signal)
}

func renderTodoList(items: ArrayList<String>, d: TabState, attrCard: HashMap<String, String>): ComponentNode {
    if (items.size == 0) {
        return div([text("还没有待办事项 :)")], attrs: Some(HashMap<String, String>([("class", cls("todo-empty"))])))
    }
    let children = ArrayList<ComponentNode>()
    for (i in 0..items.size) {
        let item = items[i]
        let idx = i
        children.add(
            div([
                span([text(item)]).className(cls("todo-text")),
                button([text("删除")]).className(cls("btn") + " " + cls("btn-sm") + " " + cls("btn-danger")).onClick({ ctx =>
                    d.todoItems.update({ list => list.remove(idx..idx + 1); list })
                    PatchResult.ReRender
                }),
            ]).className(cls("todo-item"))
        )
    }
    div(children.toArray())
}
