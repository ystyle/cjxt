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

    public func render(): ComponentNode {
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
                        button([text("添加")]).className(cls("btn") + " " + cls("btn-primary")).onClick({ ctx =>
                            let s = ctx.getState<TodoState>()
                            let text = s.todoInput.get()
                            if (text != "") {
                                s.todoItems.update({ list => list.add(text); list })
                                s.todoInput.set("")
                            }
                            PatchResult.ReRender
                        }),
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

func todoInput(signal: Signal<String>): ComponentNode {
    let a = HashMap<String, String>()
    a["class"] = cls("input")
    a["placeholder"] = "输入待办事项..."
    input(attrs: Some(a)).bind(signal)
}

func renderTodoList(items: ArrayList<String>, st: TodoState): ComponentNode {
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
                    let s = ctx.getState<TodoState>()
                    s.todoItems.update({ list => list.remove(idx..idx + 1); list })
                    PatchResult.ReRender
                }),
            ]).className(cls("todo-item"))
        )
    }
    div(children.toArray())
}
