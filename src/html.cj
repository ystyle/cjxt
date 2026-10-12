package cjxt

import std.collection.HashMap

func headTags(config: AppConfig, extraCSS!: Array<String> = []): String {
    var html = ""
    html = "${html}    <title>${config.title}</title>\n"
    html = "${html}    <link rel=\"icon\" href=\"${config.favicon}\">\n"
    if (config.cssBundle != "") {
        html = "${html}    <link rel=\"stylesheet\" href=\"${config.cssBundle}\">\n"
    }
    if (config.componentsCss != "") {
        html = "${html}    <link rel=\"stylesheet\" href=\"${config.componentsCss}\">\n"
    }
    for ((rel, href) in config.links) {
        html = "${html}    <link rel=\"${rel}\" href=\"${href}\">\n"
    }
    for (url in extraCSS) {
        html = "${html}    <link rel=\"stylesheet\" href=\"${url}\">\n"
    }
    html
}

func scriptTags(config: AppConfig): String {
    var html = ""
    for (src in config.scripts) {
        html = "${html}    <script src=\"${src}\"></script>\n"
    }
    html
}

/**
 * 把一段文本安全嵌入 HTML 的内联 `<script>` 里。
 *
 * 浏览器在 `<script>` 内先按 HTML 规则扫描 `</script`，因此 JSON 里的 `</script>`
 * 会提前结束脚本块。同时 `<!--` 会进入"脚本数据转义"状态，可能吞掉后续内容。
 * 两者都必须在**文本层**转义（JSON 自身的 `\"` 转义对 HTML 解析器无效）。
 */
public func escapeInlineScript(text: String): String {
    text.replace("</", "<\\/").replace("<!--", "<\\!--")
}

func initialTreeScript(treeJson: String): String {
    if (treeJson == "") { return "" }
    let safe = escapeInlineScript(treeJson)
    return "    <script>\n        window.__CJXT_INITIAL_TREE__ = ${safe};\n    </script>\n"
}


public func generateHtmlShell(
    sessionId: String,
    config!: AppConfig = AppConfig(),
    extraCSS!: Array<String> = [],
    extraJS!: Array<String> = [],
    initialTree!: String = ""
): String {
    var jsHtml = ""
    for (url in extraJS) {
        jsHtml = "${jsHtml}        <script src=\"${url}\"></script>\n"
    }
    """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
${headTags(config, extraCSS: extraCSS)}    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: ${config.fontFamily}; }
    </style>
</head>
<body>
    <div id="app"></div>
${scriptTags(config)}${jsHtml}${initialTreeScript(initialTree)}    <script>
        var ui = new CangjieUI(document.getElementById('app'), "${sessionId}", window.__CJXT_INITIAL_TREE__ || null);
    </script>
</body>
</html>
"""
}

/**
 * 生成"整页自包含"的 HTML 壳：内嵌 CSS/JS 全部内联，不引用任何外部 URL。
 *
 * 供**无 HTTP 服务器**的承载使用（页面以 `file://` 打开时，`/css/x.css` 这类绝对
 * 路径取不到）。引导脚本由承载方以 `bootstrap` 传入——框架只负责把页面骨架、
 * 样式与运行时拼好，**不假定任何具体宿主协议**（桥对象名、方法名、信封格式都属
 * 承载方）。
 *
 * @param css      要内联的样式表内容
 * @param js       要内联的脚本内容（前端运行时，须先于 bootstrap 执行）
 * @param bootstrap 承载方的引导脚本，在运行时之后、`</body>` 之前执行
 * @param initialTree 首屏整树（JSON）。**必须内联**：它让首屏不依赖与宿主的往返——
 *        若只靠宿主下发，宿主一旦不可用（注入失败、应答被截断、进程没起来）页面就是
 *        全白，且没有任何可观察的错误。与 HTTP 承载的 `generateHtmlShell` 保持同一语义。
 */
public func generateSelfContainedShell(
    config!: AppConfig = AppConfig(),
    css!: Array<String> = [],
    js!: Array<String> = [],
    bootstrap!: String = "",
    initialTree!: String = "",
    csp!: String = ""
): String {
    var cssHtml = ""
    for (sheet in css) {
        cssHtml = "${cssHtml}    <style>\n${sheet}\n    </style>\n"
    }
    var jsHtml = ""
    for (script in js) {
        jsHtml = "${jsHtml}    <script>\n${escapeInlineScript(script)}\n    </script>\n"
    }
    var bootHtml = ""
    if (bootstrap != "") {
        bootHtml = "    <script>\n${escapeInlineScript(bootstrap)}\n    </script>\n"
    }
    """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
${cspMeta(csp)}    <title>${config.title}</title>
${cssHtml}    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: ${config.fontFamily}; }
    </style>
</head>
<body>
    <div id="app"></div>
${jsHtml}${initialTreeScript(initialTree)}${bootHtml}</body>
</html>
"""
}

/// CSP 的 `<meta>` 标签；未给 CSP 时为空串。
/// 生产构建（存在 HTML 门禁时）要求页面声明 Content-Security-Policy。
func cspMeta(csp: String): String {
    if (csp == "") { return "" }
    "    <meta http-equiv=\"Content-Security-Policy\" content=\"${csp}\">\n"
}
