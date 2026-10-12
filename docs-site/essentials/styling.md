# CSS 体系

## 一条通道：`App.addCSS`

cjxt 的样式只有**一条**供给通道 —— `App.addCSS(css)`：

```cangjie
public func addCSS(css: String): App {
    let hash = css.hashCode().toString()...
    this.cssBlobs.add(hash, css)   // 按内容 hash 存进 cssBlobs
    this
}
```

`cssBlobs` 是 `hash → CSS 全文` 的表。**渲染时按承载方式自动选择交付形式**：

| 承载 | 交付形式 |
|---|---|
| HTTP（浏览器） | 渲染成 `<link href="/_cjxt/css/{hash}.css">`，由内置路由 `serveEmbeddedCSS` 提供内容 |
| 无 HTTP（WebView `file://`、自包含页面） | 直接 `<style>` 内联进 HTML（`selfContainedShell`） |

所以**业务侧只负责"把 CSS 交给 App"，不需要关心它怎么送到页面** —— 两种承载自动都对。

## 两个来源，同一个通道

进 `cssBlobs` 的 CSS 有两个来源，都走 `addCSS`：

```cangjie
App()
  .UseComponent()      // ① 组件库（EP）样式：@EmbedString 编译期嵌入，内部调 addCSS
  .addCSS(siteCss())   // ② 本页样式模块：@importCSS / @defineCSS 的产物
```

### ① 组件库样式

EP 样式在编译期由 `@EmbedString("public/css/element-plus.css")` 嵌入二进制
（见 `src/frontend.cj`），`UseComponent()` 把它交给 `addCSS`。**不需要**任何磁盘文件或静态路由。

### ② 页面样式模块

`@defineCSS` / `@importCSS` 的返回值是一个 `CssModule`，里面同时带着两样东西：

```cangjie
let css = @importCSS("style.css")

css.get("card")    // → "card_8387104332281640942"（scoped 类名）
css.get("_css")    // → CSS 全文（宏额外塞的一条，见 macros/define_css.cj 的 addCssEntry）
```

**必须把全文也交给 App**，否则样式只存在于编译期写出的 `public/css/bundle.css` 里，
而那个文件框架不会自动读 —— 表现是元素都在、布局配色全丢：

```cangjie
// 声明样式模块的包导出一个取值函数（惯例名 siteCss）
let css = @importCSS("style.css")
public func cls(name: String): String { css.get(name) }
public func siteCss(): String { css.get("_css") }

// 入口处交给 App
App()
  .UseComponent()
  .addCSS(siteCss())
```

## 不要用 `cssBundle` / `componentsCss` + `serveStatic`

`AppConfig` 里有 `cssBundle` / `componentsCss` 两个字段，`html.cj` 会把它们渲染成
`<link rel="stylesheet" href="...">`。它们与 `addCSS` **重复**：

- 宏已经把各模块汇总写到 `public/css/bundle.css`，再用 `<link>` 引一次 = 同一份 CSS 两套通道；
- 这条通道**只在 HTTP 下成立**：页面以 `file://` 加载时，`/css/bundle.css` 这类绝对路径取不到，
  样式会**静默全丢**（不报错，只是页面没样式）。

因此新代码不要用它们。已有的 `serveStatic("/css", "public/css")` 只为这条过时通道存在，
一并去掉。

## 宏的执行流程

```text
@defineCSS / @importCSS
  ① 读入 CSS 或 SCSS（@defineCSS[sass] 会调系统 sass 编译）
  ② 给每个 class 名追加 hash 后缀（基于内容）
  ③ 把 hash 后的 CSS 追加写到 public/css/bundle.css（编译期汇总文件）
  ④ 返回 CssModule：{ 原类名 → scoped 类名 } + { "_css" → CSS 全文 }
```

③ 与 ④ 是**同一份内容的两个出口**：③ 供人查看/比对，④ 供 `addCSS` 使用。
框架只消费 ④。

```cangjie
// 内联 CSS
@defineCSS("""
.container { padding: 24px; }
""")
// 编译后：.container_4507100390487511585 { padding: 24px; }

// 内联 SCSS（需要系统安装 sass）
@defineCSS[sass]("""
$primary: #409eff;
.box { color: $primary; }
""")

// 引入外部 CSS 文件
@importCSS("demo/style.css")
```

> 宏按**正在编译的包**定位资源（从编译器 argv 的 `-p` 取包目录，再向上找 `cjpm.toml`），
> 不是按 `cwd`。因此 `@importCSS("style.css")` 里的相对路径是相对**包所在项目根**，
> 在 cjpm workspace 下也成立。

## `cssModule(...)` 的用法

`cssModule(...)` 在运行期手工构造映射，用于测试或动态类名：

```cangjie
let m = cssModule([
    ("container", "container_4507100390487511585"),
])

div([text("内容")],
    attrs: Some(HashMap<String, String>([("class", m.get("container"))])))
```

注意它**只构造映射，不提供 CSS 内容** —— 内容仍须由 `addCSS` 提供。

## Element Plus

EP SCSS 源文件在 `public/scss/element-plus/`，用 `scripts/build-css.sh` 编译到
`public/css/element-plus.css`（该产物被 `@EmbedString` 编译期读取，因此**必须先编译 SCSS 再编译仓颉**）。

EP 用全局 BEM 类名（`el-button`、`el-menu-item`），**不参与 CSS Module 哈希**，
所以可像上面那样在 `@defineCSS` 里直接写 `.el-xxx` 覆盖：

```scss
@use 'slider.scss';
@use 'custom/slider-range.scss';   // 覆盖/扩展原始 slider 样式
```

扩展样式可复用 EP CSS 变量：

```scss
@include b(slider) {
  input[type="range"] {
    height: getCssVar('slider-height');
    background: linear-gradient(
      to right,
      getCssVar('slider-main-bg-color') 0%,
      getCssVar('slider-main-bg-color') var(--pct, 0%),
      getCssVar('slider-runway-bg-color') var(--pct, 0%),
      getCssVar('slider-runway-bg-color') 100%
    );
  }
  input[type="range"]::-webkit-slider-thumb {
    width: getCssVar('slider-button-size');
    height: getCssVar('slider-button-size');
    border: 2px solid getCssVar('slider-main-bg-color');
  }
}
```

## 安装 sass

使用 `@defineCSS[sass]` 或编译 EP 的 SCSS 需要系统安装 sass：

```bash
# macOS
brew install sass/sass/sass

# Arch Linux
pacman -S dart-sass

# Windows
choco install sass          # 或 scoop install sass

# 通用（npm）
npm install -g sass

# 手动安装（所有平台）
# 从 https://github.com/sass/dart-sass/releases 下载对应平台的压缩包
# 解压后将 sass 可执行文件加入 PATH
```
