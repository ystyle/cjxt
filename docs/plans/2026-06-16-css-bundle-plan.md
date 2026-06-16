# CSS Bundle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement CSS Bundle system — macros write scoped CSS to `public/css/bundle.css` at compile time, loaded via `<link>` at runtime.

**Architecture:** `@defineCSS` (token 序列) 和 `@importCSS` (外部文件) 在编译期将 CSS 写入 bundle 文件，返回 class 名映射。运行时通过静态文件服务加载 bundle.css。宏输出不含 `{}`，规避 Cangjie 1.1.0 的 STRING_LITERAL 限制。

**Tech Stack:** Cangjie 1.1.0, Tang (HTTP/WS), Sass CLI

---

### Task 1: `define_css.cj` — 路径解析 + Bundle 写入

**Files:**
- Modify: `src/macros/define_css.cj`

**Step 1: Add `resolveCSSPath` function**

```cangjie
func resolveCSSPath(path: String): String {
    let candidates = [path, "src/${path}", "public/css/${path}", "public/sass/${path}"]
    for (c in candidates) {
        if (exists(c)) { return c }
    }
    diagReport(DiagReportLevel.ERROR, Tokens(), "CSS file not found: ${path}", "Searched: ${String.join(candidates, delimiter: ", ")}")
    ""
}
```

**Step 2: Add `writeCSSBundle` function**

```cangjie
let _bundleWritten = Box<Bool>(false)

func writeCSSBundle(content: String): Unit {
    if (!_bundleWritten.value) {
        ensureDir("public/css")
        _bundleWritten.value = true
    }
    File.appendTo("public/css/bundle.css", ("\n" + content).toArray())
}
```

**Step 3: Add `@defineCSS` non-attribute (pure CSS)**

```cangjie
public macro defineCSS(input: Tokens): Tokens {
    let css = input.toString()
    let processed = processCSS(compileIfSass(css, false))
    writeCSSBundle(extractCSSContent(processed))
    cssModuleTokens(extractMappings(processed))
}
```

**Step 4: Add `@defineCSS` attribute overload (Sass)**

```cangjie
public macro defineCSS(attr: Tokens, input: Tokens): Tokens {
    let css = input.toString()
    let processed = processCSS(compileIfSass(css, true))
    writeCSSBundle(extractCSSContent(processed))
    cssModuleTokens(extractMappings(processed))
}
```

**Step 5: Add `@importCSS`**

```cangjie
public macro importCSS(input: Tokens): Tokens {
    let path = resolveCSSPath(input[0].value)
    let raw = String.fromUtf8(File.readFrom(path))
    let isSass = path.endsWith(".scss") || path.endsWith(".sass")
    let content = if (isSass) { compile(raw) } else { raw }
    let processed = processCSS(content)
    writeCSSBundle(extractCSSContent(processed))
    cssModuleTokens(extractMappings(processed))
}
```

**Step 6: Build**

Run: `cjpm build`
Expected: success

### Task 2: `html.cj` — `<link>` 注入

**Files:**
- Modify: `src/html.cj`

**Step 1: Add `<link>` to HTML shell**

`generateHtmlShell` 中检查 `public/css/bundle.css` 是否存在，若存在则在 `<head>` 输出 `<link rel="stylesheet" href="/css/bundle.css">`。

### Task 3: `processCSS` 分离 — 返回内容而非 tokens

**Files:**
- Modify: `src/macros/define_css.cj`

当前 `processCSS` 返回 Tokens（`cssModule(...)`），但 bundle 方案需要：
- CSS 内容（写入 bundle 文件）
- class 映射（返回给调用者）

需要将 `processCSS` 拆为两部分，或新增一个返回 `(css, mappings)` 的函数。

### Task 4: 示例改造

**Files:**
- Modify: `examples/src/main.cj`
- Modify: `examples/src/entry.cj`

### Task 5: 验证

**Steps:**
1. `cjpm build` (root)
2. `cjpm build` (examples)
3. `ls examples/public/css/bundle.css`
4. 启动服务 → `curl /css/bundle.css`
5. `curl /` | grep bundle.css
6. `cjpm test` (root — 35 tests)
