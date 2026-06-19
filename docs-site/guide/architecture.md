# 架构与核心概念

## 架构总览

cjxt 采用**服务端驱动 UI** 架构：组件在仓颉服务端渲染为 `ComponentNode`（JSON 结构树），通过 WebSocket 增量推送到前端，前端 CangjieUI 类直接操作 DOM。

```
用户操作 → 前端事件委托 → WebSocket → 服务端 ActionHandler
                                              ↓
                                        更新 Signal
                                              ↓
                                        脏组件重渲 → ComponentNode JSON
                                              ↓
                                        WebSocket ← 增量 patch
                                              ↓
                                        前端 DOM 更新
```

### 核心循环

1. **初次渲染**：服务端构建完整 ComponentNode 树 → 序列化为 JSON → 发送 `fullTree` → 前端一次性渲染
2. **用户交互**：点击/输入 → 前端事件委托 → WS 发送 action/bind → 服务端执行 handler
3. **增量更新**：`Signal.set()` 标记脏组件 → `sendPatch` 只序列化脏组件 → WS 发送 `push` 消息 → 前端子树替换
4. **导航**：`routerPush` → 服务端创建新页面 → `fullTree` 替换全部 DOM

## Signal 响应式系统

### Signal<T\>

`Signal<T>` 是 cjxt 的核心响应式原语，提供 get/set/subscribe：

```cangjie
// 创建信号
let count = Signal<Int64>(0)

// 读取值（自动注册依赖）
let val = count.get()

// 更新值（触发订阅者 + 脏标记）
count.set(42)

// 基于当前值计算新值
count.update(fn: { v => v + 1 })

// 手动订阅
count.subscribe({ v => println("count: ${v}") })
```

### SignalTracker 自动依赖追踪

`SignalTracker` 维护一个作用域栈，实现依赖的自动收集：

```cangjie
SignalTracker.enterScope()
count.get()       // 注册当前作用域为 count 的依赖
name.get()        // 注册当前作用域为 name 的依赖
let current = SignalTracker.exitScope()
// current 包含 [count, name] 两个 Signal
```

在组件渲染时，`renderWithScope` 自动包裹追踪，组件对 render 中访问的所有 Signal 建立依赖。当其中任意 Signal 变化时，组件被标记为脏。

### 脏标记与选择性重渲

- `Component.markDirty()` 将组件 ID 注册到 `dirtyRegistry`
- `sendPatch` 遍历 `dirtyRegistry`，只序列化脏组件
- 完整 ComponentNode 树仍会重新 `renderWithScope` 以产生正确的 handler 映射，但只发送脏组件的子树 JSON 到前端

```cangjie
// app.cj 中的核心逻辑
private func sendPatch(ws, state, session): Unit {
    let patches = ArrayList<PatchEntryMsg>()
    for (id, _dirty in state.dirtyRegistry._map) {
        let component = session.getComponent(id)
        match (component) {
            case Some(c) =>
                c.markClean()
                patches.add(PatchEntryMsg(id, c.serializeSubtree()))
            case None => ()
        }
    }
    state.dirtyRegistry.clear()
    // 全量重渲以刷新 handler 映射
    let tree = state.page.renderWithScope()
    state.refreshFromTree(tree)
    wsSendJson(ws, PushMsg(patches.toArray()))
}
```

### Store

`Store<S>` 基于 Signal 实现的状态管理，用于跨组件共享状态：

```cangjie
class AppState <: AppState {
    var count = Signal<Int64>(0)
}

// 在组件中获取共享状态
let state = ctx.getState<AppState>()
state.count.set(state.count.get() + 1)
```

## Component

### Component 接口

所有组件实现 `Component` 接口：

```cangjie
public interface Component <: IComponent {
    func render(): IComponent
    func onMount(ctx: LifecycleContext): Unit { () }
    func onUnmount(ctx: LifecycleContext): Unit { () }
    func onUpdate(ctx: LifecycleContext): Unit { () }
    func onError(ctx: ErrorContext): Unit { () }
}
```

### 组件实现示例

```cangjie
public class Counter <: Component {
    var count = Signal<Int64>(0)

    public func render(): IComponent {
        div([
            text("计数: ${this.count.get()}"),
            Button("+1").onClick({ ctx =>
                this.count.update(fn: { v => v + 1 })
                PatchResult.ReRender
            }),
        ])
    }
}
```

### 生命周期

| 钩子 | 触发时机 |
|------|----------|
| `onMount` | 页面首次渲染或导航后 |
| `onUnmount` | 页面离开时 |
| `onUpdate` | 每次 WS patch 推送后（服务端调用的 update） |
| `onError` | Action/Bind handler 抛出异常时 |

## VNode / DSL

### 虚拟节点

`VNode` 是构建 UI 树的基本单元：

```cangjie
public struct VNode {
    let tag: String
    let children: Array<IComponent>
    let attrs: Option<Attributes>
    let actions: HashMap<String, String>   // data-action-* 属性
    let handlers: HashMap<String, ActionHandler>  // handler 映射
}
```

### 标签辅助函数

```cangjie
div([text("内容")], attrs: Some(HashMap<String, String>([("class", "container")])))
span([text("行内文本")])
button([text("点击")])
input(attrs: Some(HashMap<String, String>([("type", "text")])))
```

### 事件绑定

```cangjie
// onClick — 事件委托到容器，WS 发送 action
Button("提交").onClick({ ctx =>
    PatchResult.ReRender
})

// bind — 双向数据绑定，自动监听 input 事件
Input().bind(this.state.username)  // Signal<String>
Slider().bind(this.state.volume)   // Signal<Int64>
Switch().bind(this.state.enabled)  // Signal<Bool>
```

bind 自动处理：
- 输入防抖（300ms）
- IME 组合输入保护
- 焦点保持（patch 不覆盖活跃元素的值）
- `<input type="range">` 发送 JSON number 供 `JsonDeserializable<Int64>` 解析

## Action 系统

### 事件委托

前端 CangjieUI 在容器上注册单一 `click` 事件监听：

```javascript
this.container.addEventListener('click', (e) => {
    const el = e.target.closest('[data-action-click]');
    if (!el) return;
    const name = el.getAttribute('data-action-click');
    this.send({ type: 'action', name, sessionId: this.sessionId });
});
```

服务端根据 `name` 查找 handler，执行后返回 `PatchResult`。

### ActionContext

```cangjie
public struct ActionContext {
    let sessionId: String
    let context: HashMap<String, String>  // 会话上下文
    let params: HashMap<String, String>   // 请求参数（bind value 等）
    let router: Router
    let pushFn: (Array<PatchEntryMsg>) -> Unit
    let sessionStates: HashMap<String, AppState>
}
```

### PatchResult

| 枚举值 | 行为 |
|--------|------|
| `PatchResult.ReRender` | 发送脏组件 patch（默认） |
| `PatchResult.Noop` | 不触发重渲 |

### 路由导航

```cangjie
ctx.navigate("/order/list")
// 或
Router.push("/order/123")
```

## 路由

### @Page 宏

```cangjie
@Page["/showcase"]
class ShowcasePage <: Component {
    // ...
}
```

`@Page` 宏在编译期：
1. 扩展类定义
2. 注册路由：`RouteRegistry.global().register("/showcase", { => ShowcasePage() })`

### RouteRegistry

```cangjie
// 注册路由
RouteRegistry.global().register("/order/:id", { => OrderDetail() })

// 匹配路径
match (RouteRegistry.global().create("/order/123")) {
    case Some(page) => // 渲染 OrderDetail
    case None => // 404
}

// 守卫
RouteRegistry.global().guard("/admin/*", AdminGuard())
```

### 页面级信号集成

导航时自动补全 `initSignals`，确保状态实例一致性：

```cangjie
private func applyNav(ws, state, session, newPage, path): Unit {
    state.page = newPage
    newPage.onMount(LifecycleContext(session.id, ...))
    let tree = newPage.renderWithScope()
    state.refreshFromTree(tree)
    wsSendJson(ws, FullTreeMsg(tree))
}
```

## 会话管理

### SessionManager

每 WebSocket 连接对应一个 Session，超时自动回收：

```cangjie
class SessionManager {
    let ttl: Int64          // 闲置超时（默认 300s）
    let sessions: HashMap<String, Session>

    // session_id 基于 ulid 生成
    func create(ws): String
    func get(id): Option<Session>
    func cleanup(): Unit    // 定期清理过期会话
}
```

### WebSocket 消息类型

| 方向 | type | 说明 |
|------|------|------|
| 前端 → 服务端 | `connect` | WebSocket 建立 |
| 前端 → 服务端 | `action` | 用户操作（click） |
| 前端 → 服务端 | `bind` | 输入绑定值变更 |
| 前端 → 服务端 | `navigate` | 路由跳转 |
| 前端 → 服务端 | `ack` | 确认（mount/update） |
| 服务端 → 前端 | `fullTree` | 全量树替换 |
| 服务端 → 前端 | `push` | 增量 patch |
| 服务端 → 前端 | `connected` | 连接成功确认 |
| 服务端 → 前端 | `title` | 页面标题更新 |
| 服务端 → 前端 | `deny` | 导航被守卫拒绝 |

## CSS 体系

### 双文件系统

```
bundle.css         ← CSS Module：@importCSS 宏编译生成，hashed class
element-plus.css   ← Element Plus 全局样式：SCSS 编译生成，独立文件
```

### CSS Module

```cangjie
// src/demo/style.css
.container { padding: 24px; }

// 在组件中使用
@importCSS("demo/style.css")
// 编译后：.container_4507100390487511585 { padding: 24px; }
```

```cangjie
let cls = cssModule("container")  // → "container_4507100390487511585"
div([text("内容")], attrs: Some(HashMap<String, String>([("class", cls)])))
```

### Element Plus 样式

SCSS 源文件在 `public/scss/element-plus/`，通过 `scripts/build-css.sh` 编译到独立文件：

```bash
./scripts/build-css.sh    # 输出到 examples/public/css/element-plus.css
```

全局 class（如 `el-button`、`el-menu-item`）直接写在 DOM 中，不被 CSS Module 哈希。

### 自定义扩展

放在 `public/scss/element-plus/custom/` 目录下，在 `element-plus.scss` 中 import：

```scss
@use 'slider.scss';
@use 'custom/slider-range.scss';  // 原 slider 样式的自定义替换
```

自定义样式复用 EP 的 CSS 变量：

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
}
```

### AppConfig 配置

```cangjie
App()
  .configure(AppConfig(
    cssBundle: "/css/bundle.css?v=2",          // CSS Module
    componentsCss: "/css/element-plus.css?v=2"  // EP 全局样式
  ))
  .serveStatic("/css", "public/css")
```

HTML 渲染结果：

```html
<link rel="stylesheet" href="/css/bundle.css?v=2">
<link rel="stylesheet" href="/css/element-plus.css?v=2">
```

## 宏系统

| 宏 | 用途 | 编译期行为 |
|----|------|-----------|
| `@Page["/path"]` | 注册页面路由 | 调用 `RouteRegistry.global().register()` |
| `@importCSS("path.css")` | 导入 CSS Module | 读取 CSS 文件，hash class 名，写入 bundle |
| `@sass("path.scss")` | 编译 SCSS | 调用 sass 编译器，输出处理后的 CSS |

## vnode 序列化

组件渲染结果（ComponentNode）序列化为 JSON 发送到前端：

```json
{
  "type": "div",
  "attrs": { "class": "container_4507" },
  "actions": { "click": "_h42" },
  "children": [
    { "type": "text", "attrs": { "text": "内容" } },
    { "type": "div", "attrs": { "data-bind-id": "_b7", "class": "el-input__wrapper" }, "children": [...] }
  ]
}
```

前端 CangjieUI 根据 `type` 创建 DOM 元素，设置属性，绑定 action/bind，递归渲染子树。

patch 消息同样使用 ComponentNode 格式，由 `applyTreePatches` 按 path 替换子树。
