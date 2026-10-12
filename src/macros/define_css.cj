macro package cjxt.macros

import std.ast.*
import std.collection.{HashMap, ArrayList}
import std.fs.{File, Directory, OpenMode, Path, exists, removeIfExists}
import std.process.executeWithOutput
import cjxt.pathres.*

let _bundleInited = [false]

// 缓存目录按"当前包所在项目"定位：宏在同一 cjc 进程里可能被多个包先后展开，
// 按 cwd 相对写会随工作目录漂移（workspace 下尤其明显）。
func cacheDir(): String {
    let base = match (resolveProjectDir()) {
        case Some(p) => p
        case None => "."
    }
    Path(base).join("target").join(".css-cache").toString()
}

func ensureCache(): Unit {
    let dir = cacheDir()
    if (!exists(dir)) {
        Directory.create(dir, recursive: true)
    }
}

func ensureDir(path: String): Unit {
    if (!exists(path)) { Directory.create(path, recursive: true) }
}

func contentHash(s: String): String {
    s.hashCode().toString().replace("-", "0")
}

// 类名字符判断（按 Rune 处理：CSS 中允许出现中文注释等非 ASCII 字符，
// 逐字节处理会把多字节 UTF-8 拆散导致 String.fromUtf8 抛异常）
func isIdent(r: Rune): Bool {
    let v = UInt32(r)
    (v >= 97 && v <= 122) || (v >= 65 && v <= 90) || (v >= 48 && v <= 57) || v == 45 || v == 95
}

func isClassNameStart(r: Rune): Bool {
    let v = UInt32(r)
    (v >= 97 && v <= 122) || (v >= 65 && v <= 90) || v == 45 || v == 95
}

func runesToString(rs: Array<Rune>): String {
    let sb = StringBuilder()
    for (r in rs) {
        sb.append(r.toString())
    }
    sb.toString()
}

// 字符串字面量 token 值转义：宏生成的 STRING_LITERAL 会被重新词法解析，
// 值里的裸换行/引号/反斜杠必须转义为转义序列
func escapeString(s: String): String {
    s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
}

func cssModuleTokens(entries: Array<(String, String)>): Tokens {
    var t = Tokens()
    t = t + Token(TokenKind.IDENTIFIER, "cssModule")
    t = t + Token(TokenKind.LPAREN)
    t = t + Token(TokenKind.LSQUARE)
    for ((k, v) in entries) {
        t = t + Token(TokenKind.LPAREN)
        t = t + Token(TokenKind.STRING_LITERAL, escapeString(k))
        t = t + Token(TokenKind.COMMA)
        t = t + Token(TokenKind.STRING_LITERAL, escapeString(v))
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
    // 按 Rune 遍历：类名识别基于字符，其余内容（含中文注释）按字符原样保留
    let runes = raw.toRuneArray()
    var i: Int64 = 0

    while (i < runes.size) {
        if (runes[i] == r'.' && i + 1 < runes.size && isClassNameStart(runes[i + 1])) {
            var j = i + 1
            while (j < runes.size && isIdent(runes[j])) { j++ }
            let name = runesToString(runes[i + 1..j])
            let scoped = "${name}_${hash}"
            map.add(name, scoped)
            parts.add(".${scoped}")
            i = j
        } else {
            parts.add(runes[i].toString())
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
    let cache = cacheDir()
    let scssPath = Path(cache).join("${hash}.scss").toString()
    let cssPath = Path(cache).join("${hash}.css").toString()

    ensureCache()
    File.writeTo(scssPath, content.toArray())

    if (!exists(cssPath)) {
        // sass 不可执行时 executeWithOutput 会**抛异常**（不是返回非零码）。
        // 必须在这里兜住并降级返回原文：否则"没装 sass"会让整个编译失败，
        // 而 SCSS 只是本框架的可选增强，不该变成硬依赖。
        let compiled: Option<String> = try {
            let (code, _, _) = executeWithOutput("sass", [scssPath, cssPath])
            if (code == 0) {
                Some(String.fromUtf8(File.readFrom(cssPath)))
            } else {
                Option<String>.None
            }
        } catch (e: Exception) {
            diagReport(DiagReportLevel.WARNING, Tokens(),
                "sass 执行失败，@defineCSS[sass] / @importCSS(.scss) 将按原文输出",
                "${e.message}；请安装 sass（见文档「CSS 体系」的安装章节）")
            Option<String>.None
        }
        match (compiled) {
            case Some(css) => css
            case None =>
                removeIfExists(cssPath)
                content
        }
    } else {
        String.fromUtf8(File.readFrom(cssPath))
    }
}

// 以"当前正在编译的包"为基准解析资源路径（见 cjxt.pathres 的说明）。
// 不能只用 cwd：cjpm workspace 下逐成员编译时 cwd 常是 workspace 根，
// 按相对路径写死的资源会找不到。
func resolveCSSPath(path: String): String {
    let resolved = resolveResource(path)
    if (resolved != "") { return resolved }
    let base = match (resolveProjectDir()) {
        case Some(p) => p
        case None => "."
    }
    let shown = ArrayList<String>()
    for (c in resourceCandidates(path)) {
        shown.add(Path(base).join(c).toString())
    }
    diagReport(DiagReportLevel.ERROR, Tokens(), "CSS file not found: ${path}",
        "Searched under ${base}: ${String.join(shown.toArray(), delimiter: ", ")}")
    ""
}

// CSS 模块汇总写到"当前包所在项目目录"的 public/css/bundle.css。
// 与 resolveCSSPath 同理：不能按 cwd 写，否则 workspace 下会落到 workspace 根。
func writeCSSBundle(content: String): Unit {
    let dir = bundleDir()
    let bundle = Path(dir).join("bundle.css").toString()
    if (!_bundleInited[0]) {
        ensureDir(dir)
        File.writeTo(bundle, "".toArray())
        _bundleInited[0] = true
    }
    let file = File(bundle, OpenMode.Append)
    file.write(content.toArray())
}

func bundleDir(): String {
    let base = match (resolveProjectDir()) {
        case Some(p) => p
        case None => "."
    }
    Path(base).join("public").join("css").toString()
}

func mappingToArray(map: HashMap<String, String>): Array<(String, String)> {
    let entries = ArrayList<(String, String)>()
    for ((k, v) in map) { entries.add((k, v)) }
    entries.toArray()
}

// ---- Macros ----

// 提取内联 CSS 原文：
// - 字符串字面量（含 `"..."`、`"""..."""` 多行字符串、`#"..."#` raw string）→ 取 token.value，
//   它不含定界符（`@defineCSS("""...""")` 的 input.toString() 会带 `"""` 泄入 bundle，这里避免）
// - 其他（如旧式 token 序列 `@defineCSS(.card {})`）→ 回退 toString() 拼合
func inlineCssRaw(input: Tokens): String {
    if (input.size >= 1) {
        let k = input[0].kind
        if (k == TokenKind.STRING_LITERAL || k == TokenKind.MULTILINE_STRING ||
            k == TokenKind.MULTILINE_RAW_STRING || k == TokenKind.SINGLE_QUOTED_STRING_LITERAL ||
            k == TokenKind.JSTRING_LITERAL) {
            return input[0].value
        }
    }
    input.toString()
}

// @defineCSS("""...""") — 内联纯 CSS；支持多行真实 CSS（含 {}、#hex、rgba()）
public macro defineCSS(input: Tokens): Tokens {
    let raw = inlineCssRaw(input)
    if (raw == "") { return Tokens() }
    let (css, entries) = processCSSGet(raw)
    writeCSSBundle(css)
    cssModuleTokens(addCssEntry(entries, css))
}

// @defineCSS[sass]("""...""") — 内联 Sass（需系统安装 sass）
public macro defineCSS(attr: Tokens, input: Tokens): Tokens {
    let raw = inlineCssRaw(input)
    if (raw == "") { return Tokens() }
    let compiled = compile(raw)
    let (css, entries) = processCSSGet(compiled)
    writeCSSBundle(css)
    cssModuleTokens(addCssEntry(entries, css))
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
    cssModuleTokens(addCssEntry(entries, css))
}

