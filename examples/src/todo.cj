package examples

import cjxt.*
import cjxt.macros.*
import std.collection.{ArrayList, HashMap}

class TodoState <: AppState {
    var todoInput = Signal<String>("")
    var todoItems = Signal<ArrayList<String>>(ArrayList<String>())
}

@Page["/todo"]
class TodoPage <: Component {
    var data: Option<TodoState> = None

    public func onMount(ctx: LifecycleContext): Unit {
        this.data = Some(ctx.getState<TodoState>())
    }

    public func render(): IComponent {
        let st = match (this.data) {
            case Some(s) => s
            case None => TodoState()
        }
        let items = st.todoItems.get()
        let attrCard = HashMap<String, String>([("class", cls("card"))])
        let attrRow = HashMap<String, String>([("class", cls("row"))])
        div([
            renderTabs("/todo"),
            div([
                div([
                    div([text("添加待办")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
                    div([
                        todoInput(st.todoInput),
                        button([text("添加")]).className(cls("btn") + " " + cls("btn-primary")).onClick(addHandler),
                    ], attrs: Some(attrRow)),
                ], attrs: Some(attrCard)),
                div([
                    div([text("待办列表 (${items.size})")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
                    renderTodoList(items, st),
                ], attrs: Some(attrCard)),
            ]),
            div([text("cjxt v0.1")], attrs: Some(HashMap<String, String>([("class", cls("footer"))]))),
        ], attrs: Some(HashMap<String, String>([("class", cls("container"))])))
    }
}

func addHandler(ctx: ActionContext): PatchResult {
    let s = ctx.getState<TodoState>()
    let text = s.todoInput.get()
    if (text != "") {
        s.todoItems.update({ list => list.add(text); list })
        s.todoInput.set("")
    }
    PatchResult.ReRender
}

// 完整按键事件模型：通过 ctx.keyEvent 区分按键
// 回车 → 添加待办；Escape → 清空输入框
func keyHandler(ctx: ActionContext): PatchResult {
    match (ctx.keyEvent) {
        case Some(ke) =>
            if (ke.isEnter()) {
                return addHandler(ctx)
            } else if (ke.isEscape()) {
                let s = ctx.getState<TodoState>()
                s.todoInput.set("")
            }
        case None => ()
    }
    PatchResult.ReRender
}

func todoInput(signal: Signal<String>): IComponent {
    let a = HashMap<String, String>()
    a["class"] = cls("input")
    a["placeholder"] = "输入待办事项...（回车添加 / Esc 清空）"
    input(attrs: Some(a)).bind(signal).on("keydown", keyHandler)
}

func renderTodoList(items: ArrayList<String>, st: TodoState): IComponent {
    if (items.size == 0) {
        return div([text("还没有待办事项 :)")], attrs: Some(HashMap<String, String>([("class", cls("todo-empty"))])))
    }
    let children = ArrayList<IComponent>()
    for (i in 0..items.size) {
        let item = items[i]
        let idx = i
        children.add(
            div([
                span([text(item)]).className(cls("todo-text")),
                button([text("删除")]).className(cls("btn") + " " + cls("btn-sm") + " " + cls("btn-danger")).onClick({ ctx =>
                    let s = ctx.getState<TodoState>()
                    s.todoItems.update({ list => list.remove(idx..idx + 1); list })
                    PatchResult.ReRender
                }),
            ]).className(cls("todo-item"))
        )
    }
    div(children.toArray())
}
