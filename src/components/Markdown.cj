package cjxt.components

import cjxt.*
import std.collection.HashMap

// ============ Markdown 渲染组件（服务端 markit 解析 → HTML，innerHTML 输出） ============

public class Markdown <: Component {
    var _content: String = ""

    public func content(v: String): Markdown { this._content = v; this }
    public func bind(signal: Signal<String>): Markdown { this._signal = Some(signal); this }

    var _signal: Option<Signal<String>> = None

    public func render(): IComponent {
        let text = match (this._signal) {
            case Some(s) => s.get()
            case None => this._content
        }
        let html = renderMarkdown(text)
        VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-markdown"), ("innerhtml", html)])))
    }
}
