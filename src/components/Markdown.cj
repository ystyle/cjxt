package cjxt.components

import cjxt.*
import std.collection.HashMap

// ============ Markdown 渲染组件（服务端 markit 解析 → HTML，innerHTML 输出） ============

public class Markdown <: Component {
    var _content: String = ""

    public func content(v: String): Markdown { this._content = v; this }
    // bind 接受 Readable<String>：Signal（可写）或 Computed（派生）皆可驱动内容
    public func bind(src: Readable<String>): Markdown { this._src = Some(src); this }

    var _src: Option<Readable<String>> = None

    public func render(): IComponent {
        let text = match (this._src) {
            case Some(s) => s.get()
            case None => this._content
        }
        let html = renderMarkdown(text)
        VNode("div", [], attrs: Some(HashMap<String, String>([("class", "el-markdown"), ("innerhtml", html)])))
    }
}
