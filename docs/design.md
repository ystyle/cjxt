# 仓颉全栈框架设计文档 —— 企业级服务端驱动 UI 系统

## 1. 背景与目标

### 1.1 背景
企业级管理端应用通常具有以下特点：
- 业务逻辑复杂，数据敏感性高，需要严格的权限控制。
- 首屏速度和 SEO 不是核心关注点。
- 交互密集（表单、列表、审批流程），但并发量不高。
- 传统方案（如 SPA）将大量逻辑放在前端，导致前端代码臃肿、安全风险大、维护成本高。

### 1.2 目标
设计并实现一个**纯仓颉服务端驱动的 UI 框架**，核心目标：
- 所有 UI 组件渲染、业务逻辑、状态管理全部在仓颉服务端完成。
- 前端仅作为轻量级渲染终端（接收组件树 JSON -> 渲染 DOM，发送 action -> 更新局部 DOM）。
- 不依赖任何 JavaScript 引擎，不使用 Node.js 生态。
- 提供类似 Next.js 的开发体验（`@Page` 宏路由、Server Actions）。
- 支持 Sass/CSS 预处理器，通过仓颉宏 + 外部二进制编译器实现编译时处理。
- 支持实时推送能力（WebSocket）。

## 2. 整体架构

```text
┌──────────────────────────────────────────────────────────────┐
│                         浏览器                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  轻量渲染器 (~2.5KB JS)                                 │  │
│  │  - 首屏：HTTP GET 获取完整 HTML + 初始组件树 JSON        │  │
│  │  - 交互：WebSocket 发送 action，接收 patch               │  │
│  │  - 绑定事件，发送 action 到服务端                        │  │
│  │  - 接收 patch 并更新 DOM                                 │  │
│  │  - 发送 mount/unmount ACK                                │  │
│  └──────────────────────────┬─────────────────────────────┘  │
└─────────────────────────────┼────────────────────────────────┘
                    ┌──────────┴──────────┐
                    │ HTTP (首屏)          │ WS (交互/推送)
                    └──────────┬──────────┘
┌─────────────────────────────▼────────────────────────────────┐
│                     仓颉 HTTP/WS 服务                         │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │  路由管理器    │  │  WS 会话     │  │  会话管理器           │ │
│  │  (@Page 宏)   │  │  - 升级/消息  │  │  - Session 生命周期   │ │
│  │  编译时注册    │  │  - action 路由│  │  - 组件树缓存          │ │
│  └──────┬──────┘  │  - patch 发送 │  │  - TTL 淘汰           │ │
│         │         └──────┬───────┘  └───────────┬──────────┘ │
│         ▼                ▼                      ▼            │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              页面组件 & 服务端组件库                      │ │
│  │  - 组件实现 Component 接口                              │ │
│  │  - render() 返回 Component 树（VNode/TextNode 等）     │ │
│  │  - 生命周期：onMount / onUpdate / onUnmount             │ │
│  │  - 样式通过 @importCSS 宏处理                           │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                                │
│                              ▼                                │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Signal 响应式状态 + Diff & Patch 引擎                   │ │
│  │  - Signal 自动追踪依赖，变更时触发 reRender               │ │
│  │  - GranularPatch 强类型 patch（AttrPatch/SubtreePatch）  │ │
│  │  - 前端颗粒 diff + subtree replaceChild                  │ │
│  │  - AppState 跨页面 session 级状态                        │ │
│  │  - patch 通过 WS 推送到前端                              │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## 3. 核心模块设计

### 3.0 设计理念：路由·状态·UI 一体化

仓颉没有现有框架生态，因此不采用前端领域"路由库 + 状态管理库 + UI 框架"的分层拼装模式，而是将三者合并为一套语言层级的统一抽象。

**为什么可以一体化**：
- 服务端驱动的模式下，"前端三件套"在后端没有物理分层的必要——路由是组件注册，状态是类字段，Action 是 lambda 型回调，它们天然属于同一个 class。
- 一体化后，一个页面就是一个 `@Page` class，所有逻辑集中在一个地方，降低认知负担，提升重构安全。

**设计原则**：

| 传统前端范式 | 本框架方案 | 优势 |
|-------------|-----------|------|
| React Router | `@Page` 宏 | 编译时校验，无运行时路由匹配开销 |
| Redux / Pinia | `var` 字段 + `ReRender` | 零样板代码，类型天然安全 |
| React Component | `Component` 接口 | 生命周期服务端可控，前后端时序一致 |
| API Route / Handler | `getActions()` + lambda | 无需反射，显式注册，编译安全 |

### 3.1 组件契约 —— `Component` 接口

所有树节点的统一抽象。`struct` 和 `class` 均可实现此接口。

```cangjie
public interface Component <: JsonSerializable {
    // ——— 用户必须实现 ———
    func render(): Component

    // ——— 生命周期，默认空实现 ———
    func onMount(ctx: LifecycleContext): Unit {}
    func onUpdate(ctx: LifecycleContext): Unit {}
    func onUnmount(ctx: LifecycleContext): Unit {}
    func onError(ctx: ErrorContext): Unit {}

    // ——— 框架内部方法 ———
    func reRender(): Unit {
        SignalTracker.pendingRender = true
    }

    func renderWithScope(): Component {
        SignalTracker.enterScope({ => this.reRender() })
        let tree = this.render()
        SignalTracker.exitScope()
        tree
    }

    func getActions(): HashMap<String, ActionHandler> {
        HashMap<String, ActionHandler>()
    }

    // ——— 默认序列化（内部类型各自覆盖） ———
    func toJson(w: JsonWriter): Unit {
        match (this) {
            case v: VNode => vnodeToJson(v, w)
            case t: TextNode => textNodeToJson(t, w)
            case f: FragmentNode => fragmentNodeToJson(f, w)
            case e: EmptyNode => emptyNodeToJson(e, w)
            case _ => ()
        }
    }

    // ——— 收集 action handler（递归遍历子节点） ———
    func collectHandlers(out: HashMap<String, ActionHandler>): Unit {
        match (this) {
            case v: VNode => vnodeCollectHandlers(v, out)
            case _ => ()
        }
    }
}
```

**设计说明**：
- `render()` 是唯一必须实现的方法。
- 所有生命周期方法提供默认空实现，最小化样板代码。
- `renderWithScope()` 包装 render，自动注册 Signal 依赖追踪。
- `reRender()` 设置 pendingRender 标志，延迟到 `sendPatch` 统一处理。
- `toJson` 默认实现通过 match 分发到具体类型的序列化逻辑。
- `collectHandlers` 默认实现处理 VNode，其他类型无 handler。

### 3.2 虚树类型体系

采用**一个 `Component` 接口涵盖所有树节点**的设计。内部具体类型（VNode、TextNode、FragmentNode、EmptyNode）都是 `Component` 的实现，用户通过标签辅助函数使用，不直接接触。

```text
Component (interface)     ← 唯一的树节点接口
├── VNode                 ← HTML 元素（div/span/button…）
├── TextNode              ← 文本
├── FragmentNode          ← 多子节点平铺展开
├── EmptyNode             ← 不渲染占位
└── UserPage (class)      ← 用户实现
```

```cangjie
public struct VNode <: Component {
    _tag: String                                    // "div" / "span" / "button"
    _attrs: Option<HashMap<String, String>>
    _children: Array<Component>                      // 子节点可以是任何 Component
    _key: Option<String>
    _actions: Option<HashMap<String, String>>        // action 名到 handler ID 的映射
    _handlers: Option<HashMap<String, ActionHandler>> // handler ID 到 lambda 的映射

    public func render(): Component { this }
    // toJson: {type, attrs, actions, children}
    // collectHandlers: 遍历自身 _handlers + 递归子节点
    // 链式方法：onClick / className / bind / style / attr / children / key
}
```

```cangjie
public struct TextNode <: Component {
    _text: String
    public func render(): Component { this }
    // toJson → {"type":"text","attrs":{"text":"..."}}（兼容前端）
}
```

```cangjie
public struct FragmentNode <: Component {
    _children: Array<Component>
    public func render(): Component { this }
    // toJson → {"type":"fragment","children":[...]}
    // 前端展开 children，不产生自身 DOM
}
```

```cangjie
public struct EmptyNode <: Component {
    public func render(): Component { this }
    // toJson → {"type":"empty"}
    // 前端跳过
}
```

**类型演变**（相对于旧版 `ComponentNode` struct）：
- `ComponentType` 枚举 → `VNode._tag: String`
- `ComponentType.Text` hack → `TextNode`
- 新增 `FragmentNode`（多子节点平铺）
- 新增 `EmptyNode`（条件渲染占位）
- `_children` 类型从 `Array<ComponentNode>` 改为 `Array<Component>`

### 3.3 页面与组件定义

页面通过 `@Page` 宏声明路由路径。所有组件实现 `Component` 接口。

```cangjie
// 无状态组件
public struct Card <: Component {
    let title: String
    let content: String
    public func render(): Component { ... }
}

// 有状态业务页面
@Page["/order/[id]"]
public class OrderPage <: Component {
    var order: OrderData
    public func render(): Component { ... }
    public func getActions(): HashMap<String, ActionHandler> { ... }
}

// 组件库组件
public func Button(label: String, kind: String, …): Component {
    // 内部通过 button() / text() 等辅助函数构建
}
```

**标签辅助函数**（全部通过命名参数 `!` 支持默认值）：

```cangjie
public func div(children: Array<Component>, attrs!: Option<Attributes> = None, …): Component
public func button(children: Array<Component>, …): Component
public func text(content: String): Component
public func span(children: Array<Component>, …): Component
public func input(attrs!: Option<Attributes> = None, …): Component
// … h1 / h2 / h3 / p / form / a / ul / li / image / cssStyle
```

所有辅助函数返回 `Component`（内部是 VNode/TextNode），调用方无需关心具体类型。

### 3.4 路由与导航

采用 **`@Page` 宏声明 + 编译时注册**，替代文件路径映射。宏在每个 `@Page` class 定义后追加 Token 序列，生成 `RouteRegistry.global().register(path, factory)` 调用。

`RouteRegistry` 是全局单例，提供 `register` 和 `create` 方法。动态路由使用 `[id]` 语法，`RouteEntry.doMatch()` 解析参数。

#### 3.4.1 路由守卫

**守卫声明**：`@Page` 宏第三个参数传守卫函数，守卫签名 `(HashMap<String, String>) -> Bool`，`context` 来自 Session。

```cangjie
@Page["/admin", "管理后台", { ctx => ctx.get("role") == Some("admin") }]
class AdminPage <: Component { ... }
```

### 3.5 Diff & Patch 引擎

采用 **GranularPatch 强类型系统**：diffTree 根据节点类型分发，生成 `AttrPatch`（字符串值变更）或 `SubtreePatch`（子树结构变更）。

#### 3.5.1 GranularPatch 枚举

```cangjie
public enum GranularPatch {
    | AttrPatch(AttrPatchEntry)      // 属性/文本内容变更
    | SubtreePatch(TreePatchEntry)   // 子树结构变更（add/replace/remove）
}

public struct AttrPatchEntry {
    let op: String       // "replace" | "remove"
    let path: String     // JSON Pointer，如 "/children/0/attrs/class"
    let value: Option<String>
}

public struct TreePatchEntry {
    let op: String       // "replace" | "add" | "remove"
    let path: String     // JSON Pointer，如 "/children/2/children/0"
    let tree: Option<Component>  // 子树（add/replace 时携带）
}
```

#### 3.5.2 diffTree 算法

```cangjie
func diffTree(old: Component, new: Component, path: String): ArrayList<GranularPatch>
    match (old, new):
        case (o: VNode, n: VNode) =>
            if (o._tag != n._tag || o._key != n._key) =>
                SubtreePatch("replace", path, Some(new))
            // attrs diff
            // children diff（递归）
        case (o: TextNode, n: TextNode) =>
            AttrPatch("replace", "${path}/attrs/text", Some(n._text))
        case (o: FragmentNode, n: FragmentNode) =>
            diffChildren(o._children, n._children, path)
        case (_, _) =>
            SubtreePatch("replace", path, Some(new))
```

diff 跳过 `_actions` 比较——handler ID 每次 render 重新生成，但不需要通知前端变更。

#### 3.5.3 消息序列化

```cangjie
public struct CombinedPatchMsg <: JsonSerializable {
    let attrs: Array<AttrPatchEntry>     // 属性/文本变更
    let trees: Array<TreePatchEntry>     // 子树结构变更
    // kind: "patch"
}
```

```json
{"kind":"patch","attrs":[{"op":"replace","path":"/children/0/attrs/text","value":"2"}],"trees":[{"op":"add","path":"/children/1/children/0","tree":{...}}]}
```

前端分两条路径处理：`applyStrPatches`（attrs）和 `applyTreePatches`（trees），结构变更用 `replaceChild` 保留焦点。

#### 3.5.4 结构变更 fallback

`SubtreePatch` 中 `tree` 字段携带完整子树，前端直接用 `renderSubtree` 创建 DOM 后 `replaceChild`。无需 fallback 到全树替换。

### 3.6 Server Actions

Action 通过 WS 消息传输。组件通过 `getActions()` 注册 action 回调，或通过 `onClick` 链式方法在渲染时注册 handler。

```cangjie
public type ActionHandler = (ActionContext) -> PatchResult

public struct ActionContext {
    let sessionId: String
    let context: HashMap<String, String>
    let params: HashMap<String, String>
    let router: Router
    let pushFn: (Array<PatchEntryMsg>) -> Unit     // 主动推送
    let sessionStates: HashMap<String, AppState>
}
```

**action handler 注册流程**：
1. `onClick(h: ActionHandler)` 在 `_handlers` 中注册 handler
2. 首次渲染时 `collectHandlers` 收集到 `state.handlers`
3. 前端点击按钮后发送 action name（即 handler ID）
4. 服务器 `dispatchAction` 在 `state.actions` / `state.handlers` 中查找
5. 执行 handler，返回 `PatchResult.ReRender` → `sendPatch`

**双向数据绑定**通过 `WS bind` 消息走同一套 handler 系统：
- `bind<T>(signal)` → 生成 bind ID → 在 `_handlers` 中注册 setter handler
- 前端 `input` 事件 → debounce 300ms → WS bind → handler 执行 `signal.set()`

### 3.7 实时推送 (WebSocket)

#### WS 交互流程

```
客户端 → 服务端: {"type":"connect","sessionId":"..."}
服务端 → 客户端: {"kind":"connected"}
服务端 → 客户端: {"kind":"patch","attrs":[],"trees":[{"op":"replace","path":"","tree":<tree>}]}
客户端 → 服务端: {"type":"ack","event":"mount"}
客户端 → 服务端: {"type":"action","name":"_h5","params":{}}
服务端 → 客户端: {"kind":"patch","attrs":[{"op":"replace","path":"/children/0/attrs/text","value":"1"}],"trees":[]}
```

**协议消息类型**：

| kind | 方向 | 用途 |
|------|------|------|
| `connected` | 服务端→客户端 | WS 连接确认 |
| `patch` | 服务端→客户端 | 增量更新（attrs + trees） |
| `fullTree` | 服务端→客户端 | 页面导航整树替换 |
| `push` | 服务端→客户端 | action 内 `ctx.push` 主动推送 |
| `title` | 服务端→客户端 | 更新 document.title |
| `deny` | 服务端→客户端 | 导航被守卫拒绝 |

### 3.8 样式系统：`@importCSS`

#### 核心类型

```cangjie
public struct CssModule {
    let map: HashMap<String, String>
    // map: {"card": "card_a1b2c3", "title": "title_a1b2c3"}
    public func get(name: String): String
}
```

#### 使用方法

```cangjie
let css = @importCSS("style.css")
func cls(name: String): String { css.get(name) }

div([], attrs: Some(HashMap([("class", cls("card"))])))
```

`@importCSS` 宏在编译时读取外部 CSS/SCSS 文件，sass 编译（.scss），类名 hash scope 后写入 `public/css/bundle.css`。`@sass` 宏已废弃，统一使用 `@importCSS`。

Element Plus 组件库的样式采用单独路径：EP 原始 SCSS 编译为独立 CSS 文件，通过 `serveStatic` 服务 + `config.componentsCss` 注入 HTML。不走 `@importCSS` 的 hash 流程，使用全局 BEM 类名。

### 3.9 前端轻量渲染器

原生 JavaScript（约 2.5KB），支持 HTTP 首屏 + WS patch 双通道。

**核心方法**：
- `renderTree(node, parentEl)` — 递归创建 DOM
- `renderSubtree(node)` — 创建单个子树的 DOM（用于 `replaceChild`）
- `navigateTo(parts, parent)` — 按 path 导航到目标元素
- `applyStrPatches(attrs)` — 应用属性/文本变更到 DOM
- `applyTreePatches(trees)` — 应用子树结构变更（`replaceChild`/`insertBefore`/`removeChild`）
- `attachBind(el)` — 绑定 input/blur/enter 事件
- `handleMsg(msg)` — 按 kind 分发消息
- `loadNewPage(msg)` — 导航整树替换

**节点类型处理**：

| type | 处理 |
|------|------|
| `text` | `createTextNode` |
| `fragment` | 递归展开 children，不创建自身 DOM |
| `empty` | 跳过 |
| `style` | `createElement('style')` + `textContent` |
| 其他（div/span/…） | `createElement(type)` + 属性 + 事件 + 子节点 |

### 3.10 生命周期管理

| 方法 | 触发条件 |
|------|---------|
| `render()` | 首次加载 / action 返回 `ReRender` |
| `onMount` | `startSession` / `servePage` / `applyNav` 时在 render 前调用 |
| `onUpdate` | patch 推送到前端后，前端 ack 触发 |
| `onUnmount` | 页面跳转 / WS 断开 |
| `onError` | action 方法抛出异常 |

**注意**：
- `onMount` 在 HTTP 首屏 + WS 导航时均调用，确保组件状态一致性
- mount ack 不再触发 `onMount`（防止状态覆盖）
- 导航时先 `onUnmount` 旧页面，再 `onMount` 新页面

### 3.11 响应式状态管理（Signal / Store / AppState）

框架提供三层状态管理：

| 层级 | 类型 | 作用域 | 适合场景 |
|------|------|--------|----------|
| 局部状态 | `var` 字段 | Component 实例 | 表单输入、临时变量 |
| 响应式状态 | `Signal<T>` / `Store<S>` | Component 字段或模块级 | 需要自动追踪变更的状态 |
| Session 级状态 | `AppState` 接口 | Session 级别，跨导航持久 | 用户信息、全局配置 |

#### 3.11.1 Signal\<T\>

```cangjie
public class Signal<T> {
    func get(): T         // 读取 + 自动追踪（render 中调用时发现依赖）
    func set(v: T)        // 写入 + 触发所有订阅者
    func update(fn: (T) -> T)  // 函数式更新
    func subscribe(fn: () -> Unit)
}
```

**自动依赖追踪**（`SignalTracker`）：

```cangjie
public class SignalTracker {
    static var scopeStack = ArrayList<() -> Unit>()
    static var pendingRender: Bool = false
    static var execMutex = Mutex()

    static func enterScope(cb: () -> Unit): Unit    // push 到 scopeStack
    static func exitScope(): Unit                      // pop
    static func currentSub(): Option<() -> Unit>       // scopeStack 栈顶
}
```

`renderWithScope()` 包装了 scope 生命周期：

```cangjie
func renderWithScope(): Component {
    SignalTracker.enterScope({ => this.reRender() })
    let tree = this.render()           // Signal.get() 将 this.reRender 注册到 Signal
    SignalTracker.exitScope()
    tree
}
```

- `Signal.get()` 检查 `currentSub()`，存在则添加到订阅列表
- `Signal.set(v)` 更新值 + 遍历调用所有订阅者
- 订阅者 `reRender()` 只设 `pendingRender = true`，不做其他操作
- `sendPatch()` 清 `pendingRender` + 重新 render + diff + 发送

#### 3.11.2 Store\<S\>

```cangjie
public class Store<S> {
    func get(): S
    func set(updater: (S) -> S)   // 例: store.set({ v => v + 1 })
    func subscribe(fn: () -> Unit)
}
```

薄封装，内部基于 `Signal<S>`。

#### 3.11.3 AppState 接口

```cangjie
public interface AppState {}    // 空标记接口
```

**注册**：通过 `App.state<T>()` 编译时注册工厂，每个 session 独立实例。

```cangjie
App()
    .state<CartState>({ => CartState() })
    .host("0.0.0.0").port(8080).serve()
```

**访问**：Action handler / onMount 中 `ctx.getState<T>()`。

### 3.12 数据绑定

#### 核心 API

```cangjie
public func bind<T>(signal: Signal<T>): Component where T <: ToString & JsonDeserializable<T>
```

`bind()` 链式方法：
1. 生成 bind ID（`_b1`, `_b2` …）
2. 在 VNode `_attrs` 中添加 `data-bind-id` 属性和 `value` 属性
3. 在 `_handlers` 中注册 setter handler：
   - 从 `ctx.params["value"]` 取 JSON 字符串
   - `JsonReader` 反序列化为 `T`
   - `signal.set(parsed)` 更新状态
   - 返回 `ReRender`

#### 前端行为

- 渲染时设 `value="${signal.get()}"` + `data-bind-id` 属性
- 监听 `input` 事件（debounce 300ms）→ WS bind
- `blur` / `Enter` 立即发送
- patch 阶段不覆盖编辑中的 input（`data-bind-dirty` 标记）

**注意**：当前使用 `el.value = value` 而非 `setAttribute("value", value)` 更新 input 的 value，确保 property 同步。

### 3.13 组件库

**源码位置**：`src/components/`（包 `cjxt.components`）

**风格**：Element Plus BEM 类名，样式通过 Element Plus 原始 SCSS 编译为独立 CSS 文件提供，不走 `@importCSS` hash。

**阶段划分**：

| Stage | 组件 | 状态 |
|-------|------|------|
| Stage 1 | Button | ✅ 完成 |
| Stage 1 | Row/Col/Card/Divider/Tag/Badge/Space/Icon/Link/Text/ButtonGroup | ❌ |
| Stage 2 | Input/InputNumber/Switch/Radio/Checkbox/Select/Slider/Rate + Form | ❌ |
| Stage 3 | Table/Progress/Avatar/Empty/Descriptions/Statistic/Result | ❌ |
| Stage 4 | Dialog/Drawer/Tooltip/Popover/Dropdown/Tabs/Collapse/Pagination… | ❌ |

详见 `docs/component-library-plan.md`。

## 4. 技术选型

| 模块 | 技术方案 |
|------|----------|
| HTTP 服务 | `tang` 框架（内置 WS 支持） |
| WebSocket | tang `ctx.upgrade()` + 自研 WS 循环 |
| 路由 | `@Page` 宏 + 编译时 `RouteRegistry` 注册 |
| JSON 序列化 | `stdx.encoding.json.stream` |
| 响应式系统 | `Signal<T>` + `SignalTracker` 自动追踪 |
| Session 级状态 | `AppState` 接口 + `TypeInfo.of<T>()` 反射注册 |
| Diff & Patch | `GranularPatch` 强类型 + `CombinedPatchMsg` 双数组 |
| 样式预处理 | `@importCSS` 宏（支持 Sass），EP 样式单独编译 |
| 前端渲染器 | 原生 JS (~2.5KB) |
| 会话存储 | 内存 `HashMap` + TTL 淘汰 |

## 5. 实施路线图

### Phase 1: 最小可行产品（MVP）✅
- [x] 定义 `Component` 接口及生命周期方法
- [x] 实现 `ComponentNode` 定义及序列化（旧 struct，已演进为 `Component` 接口体系）
- [x] 实现 `@Page` 宏
- [x] 实现 HTTP + WebSocket 服务（tang）
- [x] 实现前端渲染器

### Phase 2: Action 与 Patch ✅
- [x] WebSocket 全链路
- [x] Server Actions
- [x] 后端 diff 算法（已演进为 `GranularPatch` 强类型）
- [x] 会话基础管理

### Phase 3: 生命周期与导航 ✅
- [x] 生命周期事件触发
- [x] 导航机制
- [x] CSS 宏

### Phase 4: 增强特性 ✅
- [x] `@importCSS` 宏 + CssModule
- [x] WS 主动推送（`ctx.push`）
- [x] 路由守卫
- [x] WS 断线重连与 session 恢复
- [x] 应用配置（title、favicon、cssBundle、componentsCss）

### Phase 5: 响应式系统 ✅
- [x] `Signal<T>` + `Store<S>`
- [x] SignalTracker 自动依赖追踪 + `renderWithScope`
- [x] `AppState` 接口 + `ctx.getState<T>()`
- [x] 数据绑定 `bind<T>()`

### Phase 6: 颗粒 Diff 与 Patch ✅
- [x] `GranularPatch` 强类型枚举（AttrPatch / SubtreePatch）
- [x] `CombinedPatchMsg` 双数组序列化
- [x] 前端 applyStrPatches + applyTreePatches
- [x] subtree replaceChild 保焦点

### Phase 7: 组件库（进行中）
- [ ] Stage 1 布局组件（Button 已完成）
- [ ] Stage 2 表单组件
- [ ] Stage 3 数据展示组件
- [ ] Stage 4 交互组件

### Known Issues
- [ ] `readField` 多遍字符串解析统一为单次 JSON 解析（#7）
- [ ] Component-level 脏标记跳过不变子树 diff（#8）
- [ ] execMutex / scopeStack session-local 改造（#9）
- [ ] 前端颗粒 diff 时 attachBind 事件解绑/重绑（#10）

## 6. 风险与应对

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| 仓颉宏 I/O 限制 | 无法在宏中安全读写文件 | 采用构建脚本分离方案 |
| `dart-sass` 二进制依赖 | 部署需携带额外文件 | 提供下载脚本，容器化时打包 |
| 会话内存占用 | 活跃会话多导致 OOM | TTL 淘汰 |
| handlers map 累积 | 长期运行 handler 数量增长 | 后续实现 LRU 淘汰或弱引用 |

## 7. 总结

本框架的核心创新点：
- **全栈仓颉**：从后端逻辑、组件渲染、样式编译到构建工具，统一使用仓颉语言。
- **Signal 响应式 + 颗粒 patch**：自动依赖追踪 + 强类型 patch 枚举 + 前端子树替换。
- **编译时样式系统**：通过 `@importCSS` 宏实现 Sass 支持且零运行时开销。
- **单 `Component` 接口**：所有树节点统一为 `Component`，简化用户心智模型。
- **Next.js 类开发体验**：`@Page` 宏路由、Server Actions 等现代范式。
