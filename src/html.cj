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

public func generateHtmlShell(sessionId: String, config!: AppConfig = AppConfig(), extraCSS!: Array<String> = [], extraJS!: Array<String> = []): String {
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
${scriptTags(config)}${jsHtml}    <script>
        var ui = new CangjieUI(document.getElementById('app'), "${sessionId}", null);
    </script>
</body>
</html>
"""
}
