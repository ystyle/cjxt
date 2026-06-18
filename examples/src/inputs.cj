package examples

import cjxt.*
import cjxt.macros.*
import std.collection.HashMap

class InputsState <: AppState {
    var inputText = Signal<String>("")
    var inputEmail = Signal<String>("")
    var inputSearch = Signal<String>("")
}

@Page["/inputs"]
class InputsPage <: Component {
    var data: Option<InputsState> = None

    public func onMount(ctx: LifecycleContext): Unit {
        this.data = Some(ctx.getState<InputsState>())
    }

    public func render(): IComponent {
        let st = match (this.data) {
            case Some(s) => s
            case None => InputsState()
        }
        let attrCard = HashMap<String, String>([("class", cls("card"))])
        div([
            renderTabs("/inputs"),
            div([
                inputCard("文本输入", st.inputText, "输入任意文字...", "实时回显: ${st.inputText.get()}"),
                inputCard("Email", st.inputEmail, "name@example.com", "值: ${st.inputEmail.get()}"),
                inputCard("搜索", st.inputSearch, "搜索...", "内容: ${st.inputSearch.get()}"),
                div([
                    div([text("多行文本")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
                    div([text("Textarea 待框架扩展 tag 支持")]),
                ], attrs: Some(attrCard)),
            ], attrs: Some(attrCard)),
            div([text("cjxt v0.1")], attrs: Some(HashMap<String, String>([("class", cls("footer"))]))),
        ], attrs: Some(HashMap<String, String>([("class", cls("container"))])))
    }
}

func inputCard(title: String, signal: Signal<String>, placeholder: String, desc: String): IComponent {
    let attrCard = HashMap<String, String>([("class", cls("card"))])
    div([
        div([text(title)], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
        inputGroup(signal, placeholder),
        div([text(desc)], attrs: Some(HashMap<String, String>([("class", cls("desc"))]))),
    ], attrs: Some(attrCard))
}

func inputGroup(signal: Signal<String>, placeholder: String): IComponent {
    let a = HashMap<String, String>()
    a["class"] = cls("input")
    a["placeholder"] = placeholder
    div([
        input(attrs: Some(a)).bind(signal),
    ], attrs: Some(HashMap<String, String>([("class", cls("input-group"))])))
}
