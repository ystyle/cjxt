# 表单与数据绑定

## 文本输入绑定

使用 `bind()` 将 `<input>` 的值与 Signal 绑定：

```cangjie
input().bind(this.state.username)              // 文本
input().attr("type", "password").bind(...)     // 密码
input().attr("type", "number").bind(...)       // 数字
input().attr("placeholder", "请输入").bind(...)
```

Signal 类型决定 JSON 反序列化方式：
- `Signal<String>` → bind 文本值
- `Signal<Int64>` → bind 数字值（如 `<input type="range">`、`<input type="number">`）

## 滑块

```cangjie
input().attr("type", "range")
    .attr("min", "0")
    .attr("max", "100")
    .bind(this.state.volume)
```

## 手动事件处理

对于 `bind()` 不覆盖的场景（如 checkbox、radio），通过 `onClick` 手动更新 Signal：

```cangjie
input().attr("type", "checkbox").onClick({ ctx =>
    let checked = /* 从 ctx.params 判断是否选中 */
    PatchResult.ReRender
})
```

## 表单提交

```cangjie
form([
    input().attr("type", "text").attr("placeholder", "用户名"),
    input().attr("type", "password").attr("placeholder", "密码"),
    button(text("登录")).onClick({ ctx =>
        PatchResult.ReRender
    }),
])
```
