# VNode 与 DSL

使用标签函数构建 UI 树：

```cangjie
div(text("容器"))              // <div>
span(text("行内文本"))         // <span>
button(text("按钮"))           // <button>
input()                          // <input>
p(text("段落"))                // <p>
h1(text("标题"))               // <h1>
a(text("链接"))                // <a>
text("纯文本")                   // 文本节点
```

## 属性

```cangjie
div(text("框"), attrs: Some(HashMap<String, String>([
    ("class", "container"),
    ("id", "main"),
])))
```

## 空节点与片段

```cangjie
Empty()           // 不渲染任何内容
Fragment([...])   // 片段，不产生额外 DOM 节点
```
