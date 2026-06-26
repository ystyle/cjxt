# Drawer 抽屉组件设计

## 概述

基于 Element Plus Drawer，从屏幕边缘滑出的面板，支持四个方向（ltr/rtl/ttb/btt）。
与 Dialog 共享遮罩层结构和 props 命名风格。

## Props

| 方法 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `visible(signal)` | `Signal<Bool>` | — | 显示/隐藏（外置信号） |
| `title(v)` | `String` | `""` | 标题 |
| `direction(v)` | `DrawerDirection` | `RTL` | 弹出方向 |
| `size(v)` | `String` | `"30%"` | 抽屉尺寸（横向=宽度，纵向=高度） |
| `showClose(v)` | `Bool` | `true` | 显示关闭按钮 |
| `closeOnClickModal(v)` | `Bool` | `true` | 点击遮罩层关闭 |
| `closeOnPressEscape(v)` | `Bool` | `true` | ESC 关闭 |
| `modal(v)` | `Bool` | `true` | 显示遮罩层 |
| `withHeader(v)` | `Bool` | `true` | 显示 header 区域 |
| `destroyOnClose()` | `Bool` | `false` | 关闭时销毁 |
| `beforeClose(h)` | `ActionHandler` | `None` | 关闭前回调 |
| `header(v)` | `Array<IComponent>` | `[]` | 自定义 header 内容 |
| `footer(v)` | `Array<IComponent>` | `[]` | 自定义 footer 内容 |

## 枚举

```cangjie
public enum DrawerDirection {
    LTR | RTL | TTB | BTT
}
```

## DOM 结构

```
el-overlay-root
├── el-overlay（遮罩层，点击关闭）
└── el-overlay-dialog（position:fixed; overflow:auto; z-index:2001）
    └── el-drawer.{方向class}（position:absolute; role:dialog）
        ├── el-drawer__header
        │   ├── el-drawer__title（标题文字 或 header slot）
        │   └── el-drawer__close-btn（关闭按钮，showClose 时）
        ├── el-drawer__body（children）
        └── el-drawer__footer（footer slot）
```

- 遮罩层和 dialog wrapper 是兄弟节点，解决点击事件冒泡（同 Dialog）
- 方向 class 使用 `.ltr` / `.rtl` / `.ttb` / `.btt`，与 EP 一致
- size 通过 CSS 变量 `--el-drawer-size` 控制，横向设为 width，纵向设为 height

## CSS

- 复制 `packages/theme-chalk/src/drawer.scss` 到 `public/scss/element-plus/drawer.scss`
- 在 `element-plus.scss` 中补充 `@use 'drawer'`
- 重构时嵌入，无需额外引用

## 不实现的特性

- 动画 transition（等 #4 DOM 事务统一处理）
- 拖拽调整大小（resizable — 需要前端 mousedown/mousemove 事件系统）
- focus-trap（当前框架无此能力）
- 点击遮罩层不冒泡时关闭（overlay 的事件目前通过 onClick server action 处理）

## 实现文件

- `src/components/Drawer.cj` — 组件实现
- `public/scss/element-plus/drawer.scss` — EP 样式
- `examples/src/showcase.cj` — 演示（基础用法 + 方向切换）
