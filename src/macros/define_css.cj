macro package cjxt.macros

import std.ast.*
import std.collection.{HashMap, ArrayList}
import std.fs.{File, Directory, OpenMode, exists, removeIfExists}
import std.process.executeWithOutput

let CACHE = "target/.css-cache"
let _bundleInited = [false]

func ensureCache(): Unit {
    if (!exists(CACHE)) {
        Directory.create(CACHE, recursive: true)
    }
}

func ensureDir(path: String): Unit {
    if (!exists(path)) { Directory.create(path, recursive: true) }
}

func contentHash(s: String): String {
    s.hashCode().toString().replace("-", "0")
}

func isIdent(b: UInt8): Bool {
    (b >= 97u8 && b <= 122u8) || (b >= 65u8 && b <= 90u8) || (b >= 48u8 && b <= 57u8) || b == 45u8 || b == 95u8
}

func isClassNameStart(b: UInt8): Bool {
    (b >= 97u8 && b <= 122u8) || (b >= 65u8 && b <= 90u8) || b == 45u8 || b == 95u8
}

func cssModuleTokens(entries: Array<(String, String)>): Tokens {
    var t = Tokens()
    t = t + Token(TokenKind.IDENTIFIER, "cssModule")
    t = t + Token(TokenKind.LPAREN)
    t = t + Token(TokenKind.LSQUARE)
    for ((k, v) in entries) {
        t = t + Token(TokenKind.LPAREN)
        t = t + Token(TokenKind.STRING_LITERAL, k)
        t = t + Token(TokenKind.COMMA)
        t = t + Token(TokenKind.STRING_LITERAL, v)
        t = t + Token(TokenKind.RPAREN)
        t = t + Token(TokenKind.COMMA)
    }
    t = t + Token(TokenKind.RSQUARE)
    t = t + Token(TokenKind.RPAREN)
    t
}

func processCSSGet(raw: String): (String, Array<(String, String)>) {
    let hash = contentHash(raw)
    let map = HashMap<String, String>()
    let parts = ArrayList<String>()
    let bytes = raw.toArray()
    var i: Int64 = 0

    while (i < bytes.size) {
        if (bytes[i] == 46u8 && i + 1 < bytes.size && isClassNameStart(bytes[i + 1])) {
            var j = i + 1
            while (j < bytes.size && isIdent(bytes[j])) { j++ }
            let name = raw[i + 1..j]
            let scoped = "${name}_${hash}"
            map.add(name, scoped)
            parts.add(".${scoped}")
            i = j
        } else {
            parts.add(String.fromUtf8([bytes[i]]))
            i++
        }
    }

    let css = String.join(parts.toArray(), delimiter: "")
    let entries = ArrayList<(String, String)>()
    for ((k, v) in map) { entries.add((k, v)) }
    (css, entries.toArray())
}

func processCSS(raw: String): Tokens {
    let (css, entries) = processCSSGet(raw)
    cssModuleTokens(addCssEntry(entries, css))
}

func addCssEntry(entries: Array<(String, String)>, css: String): Array<(String, String)> {
    let list = ArrayList<(String, String)>()
    for (e in entries) { list.add(e) }
    list.add(("_css", css))
    list.toArray()
}

func compile(content: String): String {
    let hash = contentHash(content)
    let scssPath = "${CACHE}/${hash}.scss"
    let cssPath = "${CACHE}/${hash}.css"

    ensureCache()
    File.writeTo(scssPath, content.toArray())

    if (!exists(cssPath)) {
        let (code, _, _) = executeWithOutput("sass", [scssPath, cssPath])
        if (code == 0) {
            String.fromUtf8(File.readFrom(cssPath))
        } else {
            removeIfExists(cssPath)
            content
        }
    } else {
        String.fromUtf8(File.readFrom(cssPath))
    }
}

func resolveCSSPath(path: String): String {
    let candidates = ArrayList<String>()
    candidates.add(path)
    candidates.add("src/${path}")
    candidates.add("public/css/${path}")
    candidates.add("public/sass/${path}")
    for (c in candidates) {
        if (exists(c)) { return c }
    }
    diagReport(DiagReportLevel.ERROR, Tokens(), "CSS file not found: ${path}",
        "Searched: ${String.join(candidates.toArray(), delimiter: ", ")}")
    ""
}

func writeCSSBundle(content: String): Unit {
    let dir = "public/css"
    let bundle = "${dir}/bundle.css"
    if (!_bundleInited[0]) {
        ensureDir(dir)
        File.writeTo(bundle, "".toArray())
        _bundleInited[0] = true
    }
    let file = File(bundle, OpenMode.Append)
    file.write(content.toArray())
}

func mappingToArray(map: HashMap<String, String>): Array<(String, String)> {
    let entries = ArrayList<(String, String)>()
    for ((k, v) in map) { entries.add((k, v)) }
    entries.toArray()
}

// ---- Macros ----

// @defineCSS( .card { color: red; } ) — inline pure CSS
// Note: CSS syntax is NOT valid Cangjie token sequences.
// Only extremely simple CSS (no rgba, no #hex, no vendor prefixes) may work.
// For real CSS, use @importCSS("file.css") instead.
public macro defineCSS(input: Tokens): Tokens {
    let raw = input.toString()
    if (raw == "") { return Tokens() }
    let (css, entries) = processCSSGet(raw)
    writeCSSBundle(css)
    cssModuleTokens(entries)
}

// @defineCSS[sass]( .card { $c: red; color: $c; } ) — inline Sass (same limitation)
public macro defineCSS(attr: Tokens, input: Tokens): Tokens {
    let raw = input.toString()
    if (raw == "") { return Tokens() }
    let compiled = compile(raw)
    let (css, entries) = processCSSGet(compiled)
    writeCSSBundle(css)
    cssModuleTokens(entries)
}

// @importCSS("style.css") or @importCSS("style.scss") — file-based
public macro importCSS(input: Tokens): Tokens {
    if (input.size < 1) {
        diagReport(DiagReportLevel.ERROR, input, "@importCSS requires a file path", "")
        return Tokens()
    }
    let path = resolveCSSPath(input[0].value)
    let raw = String.fromUtf8(File.readFrom(path))
    let isSass = path.endsWith(".scss") || path.endsWith(".sass")
    let content = if (isSass) { compile(raw) } else { raw }
    let (css, entries) = processCSSGet(content)
    writeCSSBundle(css)
    cssModuleTokens(entries)
}
