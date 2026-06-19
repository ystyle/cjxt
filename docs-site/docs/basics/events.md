# 事件处理

## 点击事件

```cangjie
button(text("提交")).onClick({ ctx =>
    PatchResult.ReRender
})
```

## 其他事件

```cangjie
input().on("focus", { ctx => PatchResult.ReRender })
input().on("blur", { ctx => PatchResult.ReRender })
div().on("mouseenter", { ctx => PatchResult.ReRender })
```

## ActionContext

事件回调接收 `ActionContext`，可通过它访问共享状态和导航：

```cangjie
button(text("跳转")).onClick({ ctx =>
    let st = ctx.getState<MyState>()
    ctx.navigate("/other-page")
    PatchResult.ReRender
})
```

## PatchResult

| 枚举值 | 行为 |
|--------|------|
| `ReRender` | 触发脏组件重渲，发送增量 patch |
