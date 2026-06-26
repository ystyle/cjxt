# Dialog 对话框

基于 Element Plus Dialog，模态框弹出层，支持自定义 header/body/footer。

## 基础用法

```cangjie
let visible = Signal<Bool>(false)

let dlg = Dialog([text("这是一个对话框内容。")])
    .visible(visible)
    .title("提示")
    .width("420px")
    .closeOnClickModal(false)
    .footer([
        Button("取消").onClick({ ctx =>
            visible.set(false)
            PatchResult.ReRender
        }),
        Button("确认").kind(ButtonKind.Primary).onClick({ ctx =>
            visible.set(false)
            PatchResult.ReRender
        }),
    ])
```

## Dialog 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `visible(signal)` | `Signal<Bool>` | 显示/隐藏弹窗（外置信号） |
| `title(v)` | `String` | 对话框标题 |
| `width(v)` | `String` (默认 `"50%"`) | 对话框宽度（CSS 值） |
| `top(v)` | `String` (默认 `"15vh"`) | 距视口顶部距离 |
| `showClose(v)` | `Bool` (默认 `true`) | 显示关闭按钮 |
| `closeOnClickModal(v)` | `Bool` (默认 `true`) | 点击遮罩层关闭 |
| `closeOnPressEscape(v)` | `Bool` (默认 `true`) | 按 ESC 键关闭 |
| `modal(v)` | `Bool` (默认 `true`) | 显示遮罩层 |
| `center()` | `Bool` | 内容居中对齐 |
| `alignCenter()` | `Bool` | 弹窗整体居中（覆盖 `top`） |
| `fullscreen()` | `Bool` | 全屏模式 |
| `destroyOnClose()` | `Bool` | 关闭时销毁组件 |
| `beforeClose(h)` | `ActionHandler` | 关闭前回调，调用 `ctx` 可阻止关闭 |

## Slots

| Slot | 方法 | 说明 |
|------|------|------|
| 默认 | constructor `children` | 对话框主体内容 |
| Header | `header(v)` | 自定义标题区域（传入 `Array<IComponent>`） |
| Footer | `footer(v)` | 自定义底部按钮区域（传入 `Array<IComponent>`） |

### 自定义 Header 示例

```cangjie
Dialog([text("内容")])
    .visible(visible)
    .header([
        text("自定义标题"),
        Icon("close").onClick(closeHandler),
    ])
```

### 自定义 Footer 示例

```cangjie
Dialog([text("确认删除这条记录吗？")])
    .visible(visible)
    .title("删除确认")
    .width("360px")
    .footer([
        Button("取消").onClick(closeHandler),
        Button("确认删除").kind(ButtonKind.Danger).onClick(confirmHandler),
    ])
```

## 关闭行为

- 点击关闭按钮 → `visible` 设为 `false`
- 点击遮罩层 → 当 `closeOnClickModal(true)` 时关闭
- 按 ESC 键 → 当 `closeOnPressEscape(true)` 时关闭
- `beforeClose` 回调：设置后需在回调中手动调用 `visible.set(false)`，可用于二次确认

```cangjie
Dialog([text("关闭前确认")])
    .visible(visible)
    .beforeClose({ ctx =>
        // 在回调中决定是否关闭
        visible.set(false)
        PatchResult.ReRender
    })
```

## 状态持久化

`visible` 使用外置 `Signal<Bool>`，Dialog 组件实例在父组件重渲染时会被重建，但 Signal 引用不变，因此弹窗状态跨渲染保持。
