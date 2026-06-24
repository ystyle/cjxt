# 架构总览

## 服务端驱动模型

cjxt 的应用模型和传统 SPA 不同：

```
传统 SPA：  前端组件 ←→ API ←→ 服务端
cjxt：     服务端组件 → JSON → 前端渲染层
```

所有组件逻辑、状态管理、路由在服务端完成。前端只做两件事：
1. 接收服务端推送的 JSON，渲染 DOM
2. 用户操作通过 WebSocket 转发回服务端

## 组件树渲染流程

```
render() 返回 IComponent 树
        ↓
expandTree() 展开 Component → 纯 VNode 树
        ↓
serializeSubtree() → JSON
        ↓
WebSocket → 前端 CangjieUI 渲染 DOM
```

- `render()`：组件返回 `IComponent` 树（`VNode`/`TextNode`/`FragmentNode`）
- `expandTree()`：递归展开 `Component` 节点，触发 `renderWithScope` 收集 Signal 依赖
- `serializeSubtree()`：纯 VNode 树序列化为 JSON
- 前端 `CangjieUI.renderTree()`：根据 JSON 创建 DOM

## 响应式更新

```
Signal.set(value)
        ↓
订阅的回调触发 → Component.markDirty() → 加入脏组件列表
        ↓
sendPatch → 只重渲脏组件 → serialize → push 到前端
        ↓
前端 applyTreePatches → 按 path 替换子树
```

- `Signal.get()` 在 `renderWithScope` 中自动注册依赖
- 只重渲标记为脏的组件，不是整棵组件树
- 但 handler 映射需要整棵树刷新（保持新老 ID 一致），所以 `renderWithScope` 全量执行，仅序列化脏组件

## 事件处理

```
用户点击带 data-action-click 的元素
        ↓
前端事件委托 → WS → dispatchAction
        ↓
ActionHandler(ctx) → PatchResult
        ↓
PatchResult.ReRender → sendPatch
```

- 所有事件走 `data-action-click` 属性委托
- `bind` 走 `data-bind-id` + 300ms debounce
- Action handler 通过 `ctx.params` 获取请求参数
- 通过 `ctx.getState<T>()` 访问共享状态

## 路由导航

```
@Page["/path"] 宏注册路由
        ↓
routerPush(path) → 服务端创建新页面
        ↓
旧页面 onUnmount → 新页面 onMount
        ↓
新页面 renderWithScope → fullTree 推送前端
```

- 路由由宏在编译期注册
- 支持 `:param` 参数捕获和 `*` 通配符
- 支持守卫和布局函数

## CSS 隔离策略

- **CSS Module**：`@defineCSS`/`@importCSS` 宏在编译期 hash class 名，写入 `bundle.css`
- **Element Plus 全局样式**：EP SCSS 编译后通过 `@EmbedString` 嵌入二进制，运行时由 `/_cjxt/css/{hash}.css` 提供服务
- **前端 JS**：`CangjieUI` 客户端类使用 `@EmbedString` 嵌入二进制，运行时由 `/_cjxt/js/{hash}.js` 提供服务
- 两个文件独立加载，互不影响
