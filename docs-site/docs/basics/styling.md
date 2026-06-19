# CSS 体系

## CSS Modules

`@defineCSS` 将 class 名自动 hash，写入 `bundle.css`，避免全局污染：

```cangjie
@defineCSS("""
.card { padding: 16px; border-radius: 8px; }
""")
```

编译后：

```css
.card_4f8a2b1c { padding: 16px; border-radius: 8px; }
```

支持 SCSS（需要系统安装 sass）：

```cangjie
@defineCSS[sass]("""
$radius: 8px;
.card { padding: 16px; border-radius: $radius; }
""")
```

也支持引入外部文件（同样会 hash class 名）：

```cangjie
@importCSS("path/to/style.css")
@importCSS("path/to/style.scss")    // 自动识别并编译
```

## SCSS 支持

如果需要在样式中使用变量、嵌套、mixin 等，可以用 `@defineCSS[sass]`：

```cangjie
@defineCSS[sass]("""
$radius: 8px;
$primary: #409eff;

.card {
  padding: 16px;
  border-radius: $radius;
  background: $primary;
}
""")
```

使用 SCSS 需要在系统中安装 sass：

```bash
# macOS
brew install sass/sass/sass

# Arch Linux
pacman -S dart-sass

# Windows
choco install sass          # 或 scoop install sass

# 通用（npm）
npm install -g sass

# 手动：https://github.com/sass/dart-sass/releases
```

## Element Plus 组件库

cjxt 提供了对齐 Element Plus 的组件库（Button、Input、Select 等），这些组件依赖 Element Plus 的全局样式。

如需使用组件库，请查看[组件库](/docs/components/)章节的样式配置说明。
