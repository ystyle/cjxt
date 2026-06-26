# Drawer 抽屉

基于 Element Plus Drawer，从屏幕边缘滑出的面板，支持四个方向。

## 基础用法

```cangjie
let visible = Signal<Bool>(false)

let d = Drawer([text("这是一个抽屉内容。")])
    .visible(visible)
    .title("抽屉标题")
    .direction(DrawerDirection.RTL)
    .footer([
        Button("取消").onClick({ ctx => visible.set(false); PatchResult.ReRender }),
        Button("确认").kind(ButtonKind.Primary).onClick({ ctx => visible.set(false); PatchResult.ReRender }),
    ])
```

## Drawer 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `visible(signal)` | `Signal<Bool>` | 显示/隐藏抽屉（外置信号） |
| `title(v)` | `String` | 抽屉标题 |
| `direction(v)` | `DrawerDirection` | 弹出方向：`LTR | RTL | TTB | BTT`（默认 RTL） |
| `size(v)` | `String` (默认 `"30%"`) | 抽屉尺寸（横向=宽度，纵向=高度） |
| `showClose(v)` | `Bool` (默认 `true`) | 显示关闭按钮 |
| `closeOnClickModal(v)` | `Bool` (默认 `true`) | 点击遮罩层关闭 |
| `closeOnPressEscape(v)` | `Bool` (默认 `true`) | 按 ESC 键关闭 |
| `modal(v)` | `Bool` (默认 `true`) | 显示遮罩层 |
| `withHeader(v)` | `Bool` (默认 `true`) | 显示头部区域 |
| `destroyOnClose()` | `Bool` | 关闭时销毁组件 |
| `beforeClose(h)` | `ActionHandler` | 关闭前回调 |
| `header(v)` | `Array<IComponent>` | 自定义标题区域 |
| `footer(v)` | `Array<IComponent>` | 自定义底部按钮区域 |

## Slots

| Slot | 方法 | 说明 |
|------|------|------|
| 默认 | constructor `children` | 抽屉主体内容 |
| Header | `header(v)` | 自定义标题区域 |
| Footer | `footer(v)` | 自定义底部区域 |

## 方向

```cangjie
public enum DrawerDirection {
    LTR   // 从左向右弹出
    RTL   // 从右向左弹出（默认）
    TTB   // 从上向下弹出
    BTT   // 从下向上弹出
}
```
