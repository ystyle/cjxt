# Cangjie Macros 字符串语法限制报告（已更新）

> **2026-09-09 更新**：本报告最初的结论仅针对 **Cangjie 1.1.0**。该限制在 **Cangjie 1.1.3 已解除**——现在 `@defineCSS("""...""")` 可以在宏参数上下文中内联多行真实 CSS（含 `{}`、`#hex`、`rgba()`），`cjxt-consumer-test` 已实证。以下保留原始测试记录备查，并在末尾给出**当前结论**。

## 原始测试背景

项目 cjxt 的 `@defineCSS` 宏需要接收多行 CSS 字符串。最初在 Cangjie 1.1.0 中测试了宏参数上下文 `()` / `[]` 内各种字符串写法的兼容性。

---

## 一、原始测试结果总表（Cangjie 1.1.0）

| 写法 | 位置 | 结果 | 原因 |
|------|------|------|------|
| `"..."` (不含 `{`) | 非属性宏 `()` | ✅ | 纯 `STRING_LITERAL`，`input[0].value` 可取 |
| `"..."` (含 `{}`) | 非属性宏 `()` | ❌ | `{` 被认作插值起始，报 "unterminated string" |
| `"""..."""` | 非属性宏 `()` | ❌ | `"""` 不识别，`"` 被当成单行字符串起始 |
| `#"..."#` | 非属性宏 `()` | ❌ | `#` 被认成 HASH 运算符 |
| `##"..."##` | 非属性宏 `()` | ❌ | 同上 |
| `#"..."#` | 属性宏 `[]` (顶层) | ❌ | `#` 仍被认成 HASH |
| `#"..."#` | 属性宏 `[]` (内层) | ✅ | `@DataEntity` 内部可工作 (corm 验证) |
| `###"..."###` | 顶层语句 | ✅ | 顶层 `MULTILINE_RAW_STRING` 正常 |
| `"""..."""` | 顶层语句 | ✅ | 顶层 `MULTILINE_STRING` 正常 |

## 二、原始核心原因（1.1.0，已过时）

### 2.1 Tokenizer 在宏参数上下文的限制

Cangjie 1.1.0 的 tokenizer 在宏 `()` 和 `[]` 内部只识别以下 token：
- `STRING_LITERAL` — 单行双引号字符串 `"..."`
- 普通 token（标识符、运算符、关键字等）

**不识别：**
- `MULTILINE_STRING`（`""".."""`）— 被分解为三个空字符串 `""` + `""` + `""`
- `MULTILINE_RAW_STRING`（`#"..."#` / `###"..."###`）— `#` 被 tokenize 为 HASH 运算符

### 2.2 `STRING_LITERAL` 不支持 `{`

Cangjie 字符串插值语法为 `"${expr}"`，但 tokenizer 将 `{`（即使无 `$` 前缀）视为插值起始：
```cangjie
"a{b}"   // ❌ "unterminated single-line string"
"{}"     // ❌ 同上
"a"      // ✅
```

CSS 所有规则都含花括号 `{...}`，因此无法通过 `"..."` 传入宏。

### 2.3 `#"..."#` 仅在特定上下文工作

corm 库的 `@Query[#"<script>..."#]` 在内层宏（`@DataEntity` 内部）可工作。
顶层属性宏 `@Name[#"..."#]` 不认此语法。

---

## 三、当前结论（Cangjie 1.1.3）

- **限制已解除**：`@defineCSS("""...""")` 现可在宏参数上下文内联多行真实 CSS（含 `{}`、`#hex`、`rgba()`），class 名会被正确 scoped 并写入 `public/css/bundle.css`，返回 `CssModule` 映射。`cjxt-consumer-test/src/main.cj` 即此类用法。
- **`@importCSS` 与 `@defineCSS` 等价**：两者都是编译期 CSS Module 的入口——hash class 名、追加写入 `bundle.css`、返回 `CssModule` 映射。区别在于 CSS 源码位置：
  - `@defineCSS("""...""")`：CSS 内联在 `.cj` 源码中。
  - `@importCSS("style.css")`：CSS 放在外部 `.css`/`.scss` 文件，宏经路径读取。

### 产物洁净度差异（重要）

- `@importCSS` 读取的是**文件路径**（`input[0].value`），`bundle.css` 产物干净。examples 用 `@importCSS("style.css")` 生成的 `bundle.css` 首行即 `.xxx { ... }`，无多余字符。
- `@defineCSS` 内联此前经 `input.toString()` 拼合，会把 raw string 定界符 `"""` 一起泄入产物（如 `"\n.row_8645 { ... }\n"`）。**该问题已修复**：`src/macros/define_css.cj` 新增 `inlineCssRaw()`，对字符串字面量（含 `"""..."""`）取 `token.value`（不含定界符），仅对旧式 token 序列回退 `toString()`。现在 `@defineCSS` 与 `@importCSS` 的产物同样干净。

### 推荐用法

- **大型共享样式表 / 全站级样式**：用 `@importCSS("file.css")`，产物干净、便于独立编辑与版本管理（如 examples 的 `style.css`）。
- **小段页面/组件局部样式**：用 `@defineCSS("""...""")` 内联。

## 修复记录

- `@defineCSS` 内联路径残留 `"""` 定界符 —— 已修复（`inlineCssRaw()` 改用 `token.value`）。回归用例：`src/css_define_inline_test.cj`（`testInlineCssHasNoRawStringDelimiters` / `testInlineSassWorksAndNoDelimiters`）。
