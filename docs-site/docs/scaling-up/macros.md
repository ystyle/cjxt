# 宏系统

## @Page — 页面路由注册

```cangjie
@Page("/path", "标题", guard, layout)
class MyPage <: Component { ... }
```

编译期展开为 `RouteRegistry.global().register("/path", { => MyPage() }, "标题", guard, layout)`。

## @defineCSS — 内联 CSS Module

```cangjie
// 纯 CSS
@defineCSS("""
.card { padding: 16px; border-radius: 8px; }
""")

// SCSS（需要系统安装 sass）
@defineCSS[sass]("""
$radius: 8px;
.card { padding: 16px; border-radius: $radius; }
""")
```

## @importCSS — 引入外部 CSS

```cangjie
@importCSS("path/to/style.css")
```

三者执行流程一致：
1. 解析输入（文件读取或内联解析）
2. 对每个 class 名追加 hash 后缀（基于文件路径和内容）
3. hash 后的 CSS 写入 `public/css/bundle.css`
4. 返回 `CssModule` 映射供组件使用
