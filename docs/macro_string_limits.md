# Cangjie 1.1.0 Macros 字符串语法限制报告

## 测试背景

项目 cjxt 的 `@defineCSS` 宏需要接收多行 CSS 字符串。测试了 Cangjie 1.1.0 中宏参数上下文 `()` / `[]` 内各种字符串写法的兼容性。

---

## 一、测试结果总表

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

## 二、核心原因

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

## 三、结论

Cangjie 1.1.0 中 **宏参数无法接收多行 CSS 字符串**。  
任何多行/原始字符串写法都会在 tokenizer 阶段失败，宏不会被执行。

### 当前方案

```cangjie
// 顶层多行原始字符串定义 CSS
let CSS = ###"
* { margin: 0; }
.container { max-width: 640px; }
.card { background: #fff; padding: 24px; }
"###

// cssStyle 注入
div([
    cssStyle(CSS),
    renderTabs(d, tab),
    tabContent,
])
```

- `###"..."###` 在顶层完美工作（非宏上下文）
- `cssStyle()` 接收 `String` 生成 `<style>` 节点
- `@defineCSS` 宏保留但仅支持 **单行无花括号 CSS**（作用有限）

### 推荐

后续仓颉版本若修复 tokenizer 对宏参数上下文的支持，可恢复 `@defineCSS` 的多行能力。  
关注点：`MULTILINE_RAW_STRING` 和 `MULTILINE_STRING` 在 `()` / `[]` 内的识别。
