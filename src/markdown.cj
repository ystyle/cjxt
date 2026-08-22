package cjxt

import markit.*
import markit.bundles.*

// ============ Markdown 渲染（markit 解析 → HTML 字符串） ============

// 服务端把 markdown 文本渲染为 HTML 片段（供 Markdown 组件 innerHTML 输出）
// 用 GFM bundle：支持表格、任务列表、删除线、自动链接等扩展
public func renderMarkdown(text: String): String {
    if (text == "") { return "" }
    let parser = Markit().use(GFMBundle())
    let result = parser.parse(text)
    if (result.hasErrors()) {
        // 解析失败回退为转义纯文本，保证内容可见
        escapeHtmlText(text)
    } else {
        result.document.toHtml()
    }
}

// 将 HTML 特殊字符转义（回退用）
public func escapeHtmlText(text: String): String {
    var out = ""
    for (ch in text) {
        match (ch) {
            case '<' => out = "${out}&lt;"
            case '>' => out = "${out}&gt;"
            case '&' => out = "${out}&amp;"
            case '"' => out = "${out}&quot;"
            case _ => out = "${out}${ch}"
        }
    }
    out
}
