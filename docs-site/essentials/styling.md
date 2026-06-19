# CSS 体系

## 双文件系统

```
bundle.css         ← CSS Module：@defineCSS / @importCSS 宏编译，hashed class
element-plus.css   ← Element Plus 全局样式：SCSS 编译生成，独立文件
```

HTML 加载两个 `<link>`：

```html
<link rel="stylesheet" href="/css/bundle.css?v=2">
<link rel="stylesheet" href="/css/element-plus.css?v=2">
```

配置方式：

```cangjie
App()
  .configure(AppConfig(
    cssBundle: "/css/bundle.css?v=2",
    componentsCss: "/css/element-plus.css?v=2",
  ))
  .serveStatic("/css", "public/css")
```

## 安装 sass

如果使用 Element Plus 组件或需要编译 SCSS，需要安装 sass：

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

## CSS Module（宏）

通过 `@defineCSS` / `@importCSS` 宏编译：

```cangjie
// 内联 CSS
@defineCSS("""
.container { padding: 24px; }
.title { font-size: 18px; font-weight: 600; }
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

宏执行流程：
1. 解析 CSS/SCSS
2. 每个 class 名追加 hash 后缀（基于文件路径和内容）
3. 将 hash 后的 CSS 写入 `bundle.css`
4. 返回 `CssModule` 映射

### CssModule 使用

```cangjie
let m = cssModule([
    ("container", "container_4507100390487511585"),
    ("title", "title_4507100390487511585"),
])

div([text("内容")],
    attrs: Some(HashMap<String, String>([
        ("class", m.get("container"))
    ]))
)
```

## Element Plus 样式

EP SCSS 源文件在 `public/scss/element-plus/`，通过 `scripts/build-css.sh` 编译。

全局 class（如 `el-button`、`el-menu-item`）直接写在 DOM 中，不受 CSS Module 哈希影响。

### 自定义扩展

放在 `public/scss/element-plus/custom/` 下，在 `element-plus.scss` 中 import：

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
