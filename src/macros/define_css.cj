macro package cjxt.macros

import std.ast.*
import std.fs.{File, Directory, exists, removeIfExists}
import std.process.executeWithOutput

let CACHE = "target/.css-cache"

func cacheDir(): Unit {
    if (!exists(CACHE)) {
        Directory.create(CACHE, recursive: true)
    }
}

func contentHash(s: String): String {
    s.hashCode().toString()
}

public macro defineCSS(input: Tokens): Tokens {
    input
}

public macro sass(input: Tokens): Tokens {
    let content = input[0].value
    let hash = contentHash(content).replace("-", "0")
    let scssPath = "${CACHE}/${hash}.scss"
    let cssPath = "${CACHE}/${hash}.css"

    cacheDir()
    File.writeTo(scssPath, content.toArray())

    if (!exists(cssPath)) {
        let (code, _, _) = executeWithOutput("sass", [scssPath, cssPath])
        if (code != 0) {
            removeIfExists(cssPath)
            diagReport(DiagReportLevel.ERROR, input,
                "sass 编译失败",
                "请检查 Sass 语法，确保已安装 sass CLI: npm install -g sass")
        }
    }

    let css = String.fromUtf8(File.readFrom(cssPath))
    quote( $(css) )
}
