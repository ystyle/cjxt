# CSS Bundle System Design

Date: 2026-06-16
Status: Draft

## Problem

Cangjie 1.1.0 的 tokenizer 在宏参数上下文 `()` / `[]` 中只识别 `STRING_LITERAL`，且 `STRING_LITERAL` 不允许 `{}` 字符（被当作插值语法起始）。CSS 规则必须含 `{}`，因此无法通过 `@defineCSS("...{...}")` 的方式将多行 CSS 传入宏。宏系统也无法生成含 `{}` 的 `STRING_LITERAL` token 输出。

## Solution

将 CSS 作为**编译期静态资源**处理，不经过 Cangjie 字符串系统。宏在编译期将 CSS 写入 `public/css/bundle.css` 文件，运行时通过 `<link>` 加载。仓颉代码只保留 class 名映射，不包含任何 CSS 文本。

## Architecture

```
┌─ 编译时（宏展开阶段）────────────────────────────────────┐
│                                                          │
│  @defineCSS( .card { color: red; } )                     │
│           ↓ input.toString()                             │
│  @importCSS("style.scss")                                │
│           ↓ File.readFrom + 后缀判断                     │
│                                                          │
│      ┌──── CSS 文本 ────┐                                │
│      │                  │                                │
│      │  有 .sass/.scss  │  无                             │
│      │  后缀?           │                                │
│      │   ↓ 是           │  ↓ 否                          │
│      │  compile()       │  processCSS                    │
│      │  (Sass 编译)     │  (作用域化)                     │
│      │   ↓              │  ↓                             │
│      │  processCSS      │                                │
│      │  (作用域化)      │                                │
│      │   ↓              │  ↓                             │
│      └───── 都走 ───────┘                                │
│                    ↓                                     │
│    ┌─ 追加写 public/css/bundle.css ──┐                    │
│    │  ↑ 文件输出，不经过 tokenizer    │                    │
│    └──────────────────────────────────┘                    │
│                    ↓                                     │
│    返回 cssModule([("card","card_HASH")])                 │
│    ↑ 不含 _css，不含 {}，STRING_LITERAL 畅通              │
│                                                          │
└──────────────────────────────────────────────────────────┘

┌─ 运行时 ──────────────────────────────────────────────┐
│  <link href="/css/bundle.css">  ← 静态文件服务           │
│  cls("card") → "card_HASH" 匹配 bundle.css 中的选择器   │
└────────────────────────────────────────────────────────┘
```

## Macros

### `@defineCSS(input: Tokens)` — 内联纯 CSS

```
@defineCSS( .card { color: red; } .container { max-width: 640px; } )
```

签名：非属性宏 `(input)`

流程：
1. `input.toString()` → 拼接 token 为 CSS 文本
2. `processCSS` → class 名作用域化（加 hash）
3. `writeCSSBundle` → 追加写入 `public/css/bundle.css`
4. 返回 `cssModule([("card", "card_HASH"), ("container", "container_HASH")])`

输入不带 `.sass`/`.scss` 后缀判断，只走纯 CSS 流程。

### `@defineCSS(attr: Tokens, input: Tokens)` — 内联 Sass (重载)

```
@defineCSS[sass]( $color: red; .card { color: $color; } )
```

签名：属性宏 `(attr, input)`

流程：
1. `input.toString()` → 拼接 token 为 Sass 文本
2. `compile()` → Sass 编译
3. `processCSS` → class 名作用域化
4. `writeCSSBundle` → 追加写入 `public/css/bundle.css`
5. 返回 `cssModule([("card", "card_HASH")])`

`attr` 内容为 `["sass"]`，用于区分两种模式。

### `@importCSS(input: Tokens)` — 外部文件

```
@importCSS("style.css")
@importCSS("theme.scss")
```

签名：非属性宏 `(input)`

流程：
1. `input[0].value` → 文件路径
2. `resolveCSSPath` → 按约定目录查找
3. `File.readFrom` → 读取文件内容
4. 按后缀决定：
   - `.css` → `processCSS`
   - `.scss` / `.sass` → `compile()` + `processCSS`
5. `writeCSSBundle` → 追加写入 `public/css/bundle.css`
6. 返回 `cssModule([("card", "card_HASH")])`

### 宏签名对比

| 写法 | 签名 | 处理 |
|------|------|------|
| `@defineCSS( .card {} )` | `(input)` | 纯 CSS，processCSS |
| `@defineCSS[sass]( .card {} )` | `(attr, input)` | Sass 编译 + processCSS |
| `@importCSS("style.css")` | `(input)` | 文件 `.css` → processCSS |
| `@importCSS("style.scss")` | `(input)` | 文件 `.scss` → compile + processCSS |

## Path Resolution

`@importCSS` 按序查找文件：

```
@importCSS("style.css")
  → ./style.css
  → ./src/style.css
  → ./public/css/style.css
  → ./public/sass/style.css
  → 都找不到 → diagReport(ERROR)
```

`@defineCSS` 不涉及路径解析。

## Bundle Output

### 输出路径

`public/css/bundle.css`

所有 `@defineCSS` 和 `@importCSS` 的 CSS 内容合并写入同一文件。

### 写入策略

```cangjie
func writeCSSBundle(content: String): Unit {
    ensureDir("public/css")
    // 追加模式
    File.appendTo("public/css/bundle.css", content.toArray())
}
```

编译开始时清理 bundle 文件，然后各宏调用时依次追加。

### 空 CSS 处理

若无任何 `@defineCSS` / `@importCSS` 调用，不生成 bundle.css。`<link>` 不应输出或输出空文件。

## Runtime

### HTML Shell

```cangjie
// html.cj — generateHtmlShell
// 自动在 <head> 输出 <link>
public func generateHtmlShell(sessionId: String): String {
    let link = bundleExists()
        ? "<link rel=\"stylesheet\" href=\"/css/bundle.css\">"
        : ""
    // ...
}
```

### 静态文件服务

```cangjie
// entry.cj
main() {
    App()
        .static("/css", "public/css")
        .host("0.0.0.0").port(8080).serve()
}
```

### class 映射

```cangjie
let css = @defineCSS( .card { color: red; } )
// css 是 CssModule (HashMap<String, String>)
// css.get("card") → "card_a1b2c3"
// cls("card") → css.get("card")

// bundle.css 内容：
// .card_a1b2c3 { color: red; }
```

## CssModule

不需要新增结构体。当前 `CssModule` 基于 `HashMap<String, String>`：

```cangjie
// css.cj
public func cssModule(pairs: Array<(String, String)>): CssModule {
    CssModule(HashMap(pairs))
}
```

宏输出中**不含 `_css` 条目**（CSS 走 bundle 文件，不经过字符串 token）。class 映射值不含 `{}`，用 `STRING_LITERAL` 输出畅通。

## Files to Change

| File | Change |
|------|--------|
| `src/macros/define_css.cj` | `resolveCSSPath()`, `writeCSSBundle()`, `@defineCSS` 重载, `@importCSS` |
| `src/html.cj` | `generateHtmlShell` 加 `<link>` 输出 |
| `examples/src/main.cj` | 改为 `@defineCSS` token 序列写法 + `cls()` |
| `examples/src/entry.cj` | 加 `.static("/css", "public/css")` |

## Removed

- **embed 模式**：不需要，统一 bundle
- **`_css` 条目**：CSS 走文件，不经过 token
- **`MULTILINE_RAW_STRING` 修复**：无需修复，class 映射不含 `{}`

## Open Questions

1. bundle.css 编译开始时清理：如何确保只清理一次（多个宏调用时）？
2. `<link>` 是否默认输出，还是需要配置开关？
3. `@defineCSS` 的 `input.toString()` 拼合结果去空格/格式化的程度？

## Implementation Plan

1. `define_css.cj`: 路径解析 + bundle 写入 + 宏重载 + @importCSS
2. `html.cj`: `<link>` 输出
3. 示例改造
4. 验证构建 + 运行
