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
- 提供类似 Next.js 的开发体验（`@Page` 宏路由、Server Actions、构建时 SSG）。
- 支持 Sass/CSS 预处理器，通过仓颉宏 + 外部二进制编译器实现编译时处理。
- 支持实时推送能力（WebSocket）。

## 2. 整体架构

```text
┌──────────────────────────────────────────────────────────────┐
│                         浏览器                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  轻量渲染器 (~2KB JS)                                   │  │
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
│  │  - 组件实现 Component 接口（interface）                  │ │
│  │  - struct 无状态 / class 有状态                          │ │
│  │  - render() 返回 ComponentNode 树                       │ │
│  │  - 生命周期：onMount / onUpdate / onUnmount             │ │
│  │  - 样式通过 defineCSS 宏处理                             │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                                │
│                              ▼                                │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Signal 响应式状态 + Diff & Patch 引擎                   │ │
│  │  - Signal 自动追踪依赖，变更时精准 patch                  │ │
│  │  - diff.cj 过渡方案（被 Signal 替代，待移除）             │ │
│  │  - AppState 跨组件/跨页面 session 级状态                  │ │
│  │  - patch 通过 WS 推送到前端                               │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## 3. 核心模块设计

### 3.0 设计理念：路由·状态·UI 一体化

仓颉没有现有框架生态，因此不采用前端领域"路由库 + 状态管理库 + UI 框架"的分层拼装模式，而是将三者合并为一套语言层级的统一抽象：

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

> **响应式增强**：`var + ReRender` 是全树重渲染后再 diff，适用于低频交互。对于高频更新的局部组件可使用 `Signal<T>` 实现细粒度响应式——Signal 变更时仅触发自身订阅的 re-render，零对比开销。
> `Store<S>` 提供函数式更新（`store.set(fn)`），配合 `SignalTracker` 实现自动依赖追踪：`initSignals` 在首次 render 时发现 Signal 依赖，自动订阅 reRender 回调。
> `AppState` 接口 + `ctx.getState<T>()` 实现跨页面/跨组件的 session 级状态共享，三者配合可覆盖从局部到全局的所有状态管理需求。

### 3.1 组件契约 —— `Component` 接口

所有组件的统一抽象，定义生命周期 + 渲染的约定。`struct` 和 `class` 均可实现此接口。

```cangjie
public interface Component {
    func render(): ComponentNode
    func getActions(): HashMap<String, ActionHandler> {
        HashMap<String, ActionHandler>()
    }
    func onMount(_: LifecycleContext): Unit {}
    func onUpdate(_: LifecycleContext): Unit {}
    func onUnmount(_: LifecycleContext): Unit {}
    func onError(_: ErrorContext): Unit {}
}
```

**设计说明**：
- `render()` 是唯一必须实现的方法。
- `getActions()` 返回 action 名到处理函数的映射，默认空 Map。
- 所有生命周期方法提供默认空实现，最小化样板代码。
- `LifecycleContext` 包含 `sessionId`、`routeParams`、`componentKey`、`triggerAction`。
- `ErrorContext` 包含 `sessionId`、`actionName`、`error`。

### 3.2 数据模型 —— `ComponentNode`

组件树的可序列化表示，是前后端通信的桥梁。实现 `JsonSerializable`，利用标准库 `writeValue` 原生序列化。

```cangjie
public enum ComponentType <: ToString & Equatable<ComponentType> {
    | Div | Span | Button | Input | Form
    | Table | Text | Image | H1 | H2 | H3
    | P | Select | Textarea | A | Ul | Li
}

public type Attributes = HashMap<String, String>
public type ActionMap = HashMap<String, String>

public struct ComponentNode <: JsonSerializable {
    let typ: ComponentType
    let attrs: Option<Attributes>
    let children: Array<ComponentNode>
    let key: Option<String>
    let actions: Option<ActionMap>
}
```

`Option` 类型的 `attrs`/`actions`/`key` 避免为空 Map 分配内存，序列化时标准库原生支持 `Option<T>`、`HashMap<String, T>`、`Array<T>`。

**标签辅助函数**：`div`、`span`、`button`、`text`、`h1`、`h2`、`p`、`input`、`form`、`image`、`a`、`ul`、`li`，全部使用命名参数默认值（`attrs!: Option<Attributes> = None`），作为 DSL 供组件 `render()` 中调用。

### 3.3 页面与组件定义规范

页面通过 `@Page` 宏声明路由路径，组件按场景分 **struct（纯展示/无状态）** 或 **class（业务页面/有状态）**。

```cangjie
// 无状态组件：适合卡片、布局等
public struct Card <: Component {
    let title: String
    let content: String
    public func render(): ComponentNode { ... }
}

// 有状态组件：适合业务页面
@Page["/order/[id]"]
public class OrderPage <: Component {
    var order: OrderData
    public func render(): ComponentNode { ... }
    public func getActions(): HashMap<String, ActionHandler> { ... }
}
```

**页面组件规范总结**：

| 元素 | 说明 |
|------|------|
| `@Page["/path"]` | 宏注解，声明路由路径，支持动态参数如 `[id]` |
| `<: Component` | 实现 Component 接口，提供 render() 和生命周期方法 |
| `getActions()` | 返回 action 名到处理函数的映射 |

### 3.4 路由与导航

采用 **`@Page` 宏声明 + 编译时注册**，替代文件路径映射。宏在每个 `@Page` class 定义后追加 Token 序列，生成 `RouteRegistry.global().register(path, factory)` 调用。

`RouteRegistry` 是全局单例，提供 `register` 和 `create` 方法。动态路由使用 `[id]` 语法，`RouteEntry.doMatch()` 解析参数。

#### 首屏加载流程

HTTP GET 请求 → 路由匹配 → 构造组件实例 → `render()` → 创建 Session → 返回 HTML 壳。

#### 导航切换

两种方式：action 内调用 `ctx.router.push(path)`（方式一），或前端 WS 发送 navigate 消息（方式二）。服务端收到后执行 unmount → 匹配新路由 → 构造新页面 → render → 推送 fullTree。

#### 3.4.1 路由守卫

**应用场景**：部分页面需要登录或特定权限才能访问（如管理后台、个人中心）。

**守卫声明**：`@Page` 宏第三个参数传守卫函数，守卫签名 `(HashMap<String, String>) -> Bool`，`context` 来自 Session。

```cangjie
// 页面级守卫
@Page["/admin", "管理后台", { ctx => ctx.get("role") == Some("admin") }]
class AdminPage <: Component { ... }

// 公开页面（无守卫）
@Page["/login", "登录"]
class LoginPage <: Component { ... }
```

**守卫检查流程**：

1. 用户发起导航（action 内 `router.push` 或 WS navigate）。
2. 框架匹配新路由，获取守卫函数。
3. 从当前会话读取 `context`，传入守卫。
4. 守卫返回 `true` → 继续导航（unmount → 新页面 → fullTree）。
5. 守卫返回 `false` → 拒绝导航，前端收到 `deny` 消息。

**会话上下文**：`Session.context` 是 `HashMap<String, String>`，登录 action 中写入：

```cangjie
session.context["role"] = "admin"
```

框架不绑定业务字段，由项目自行管理 key-value。

### 3.5 后端 Diff 与 Patch（将废弃）

**注意**：当前 diff 引擎已由 Phase 5 的 `Signal<T>` 响应式系统替代。Signal 粒度追踪脏节点并直接生成 patch，无需对比新旧两棵树。`diff.cj` 将在 Signal 全量覆盖后移除。

当前（过渡期）diff 算法：先比较 type 和 key，不同则整节点替换；再逐属性比较 attr 变更；最后按位置比较 children（递归）。

```cangjie
public enum PatchResult { ReRender, Patch(Array<PatchEntry>) }

public struct PatchEntry {
    let op: String      // "replace" | "add" | "remove"
    let path: String    // JSON Pointer
    let value: Option<String>
    let from: Option<String>
}
```

Diff 算法：先比较 type 和 key，不同则整节点替换；再逐属性比较 attr 变更；最后按位置比较 children（递归）。

### 3.6 Server Actions

Action 通过 WS 消息传输。组件通过 `getActions()` 注册 action 回调，框架收到 WS action 消息后查找并执行。

```cangjie
public type ActionHandler = (ActionContext) -> PatchResult

public struct ActionContext {
    let sessionId: String
    let params: HashMap<String, String>
    let router: Router
}

public struct Router {
    let sessionId: String
    let navigateFn: (String) -> Unit
    public func push(path: String): Unit
}
```

如果 action 内部调用 `ctx.router.push(path)`，则导航优先，返回的 `PatchResult` 被忽略。

### 3.7 实时推送 (WebSocket)

#### WS 交互流程

```
客户端 → 服务端: { type: "connect", sessionId: "..." }
服务端 → 客户端: {"kind":"connected"}
服务端 → 客户端: {"kind":"patch","patches":[{"op":"replace","path":"","value":<tree>}]}
客户端 → 服务端: {"type":"action","name":"click","params":{}}
服务端 → 客户端: {"kind":"patch","patches":[...]}
```

协议消息使用 `JsonSerializable` struct 定义（`ConnectedMsg`、`PatchMsg`、`PatchEntryMsg`），通过 `wsSendJson<T>()` 序列化发送。

#### 服务端推送

WS 连接建立后，服务端可在任意时刻推送 patch 消息，用于数据变更通知、协作提醒等。

### 3.8 样式系统：`defineCSS` / `@sass` 宏

#### 设计目标
- 编译时处理，零运行时开销。
- 支持纯 CSS 和 Sass，统一使用方式。
- 自动类名 scope hash，避免全局冲突（类似 CSS Modules）。

#### 核心类型

```cangjie
public struct CssModule {
    let map: HashMap<String, String>
    // map 内容: {"btn": "btn_a1b2c3", "title": "title_a1b2c3", "_css": ".btn_a1b2c3{...}"}
    public func get(name: String): String
    // _css 由框架在适当位置注入到 HTML <style>
}
```

宏统一返回 `CssModule`，调用方通过 `get(name)` 获取 scoped 类名。

#### 使用方法

```cangjie
// 纯 CSS
let css = @defineCSS(".btn { color: red; }")
div([], attrs: Some(HashMap([("class", css.get("btn"))])))

// Sass — 写法完全一致
let css = @sass("$primary: red; .btn { color: $primary; }")
div([], attrs: Some(HashMap([("class", css.get("btn"))])))
```

#### 实现方案

**纯 CSS 流程（`@defineCSS`）：**
1. 宏接收 CSS 字符串，计算 hash 作为 scope。
2. 扫描 `.identifier {` 提取类名，替换为 `.identifier_HASH {`。
3. 返回 `CssModule({"btn": "btn_HASH", "_css": ".btn_HASH{...}"})`。
4. 零 I/O，纯编译时字符串处理。

**Sass 流程（`@sass`）：**
1. 写 `.scss` 到 `target/.css-cache/<hash>.scss`。
2. `build.cj`（自动执行）扫描缓存目录，编译无对应 `.css` 的 `.scss`。
3. 宏展开时读 `<hash>.css`，解析类名，返回 `CssModule`。

`build.cj` 由 `cjpm build` 在编译前自动执行，开发者无需手动调用。

#### CSS 注入

`CssModule` 的 `_css` 字段存储完整 scoped CSS。框架在 HTML 壳生成时收集当前页面的所有 `_css`，注入到 `<style>` 标签中，开发者无需手动管理。

### 3.9 前端轻量渲染器

原生 JavaScript（约 2KB），支持 HTTP 首屏 + WS patch 双通道。核心逻辑：

- `renderTree(node, el)`：递归创建 DOM 节点，绑定 action 事件。
- `applyPatches(patches)`：按 `op` + `path` 定位节点并更新。
- `handleMsg(msg)`：按 `msg.kind` 分发（connected/patch/fullTree）。
- `connectWS()`：自动重连（3s 间隔）。

### 3.10 生命周期管理

| 方法 | 触发条件 |
|------|---------|
| `render()` | 首次加载 / action 返回 `ReRender` |
| `onMount` | 服务端收到前端 ack:mount；同时 `startSession` 时在 `initSignals` 前调用 |
| `onUpdate` | patch 推送到前端后 |
| `onUnmount` | 会话超时 / 页面跳转 / WS 断开 |
| `onError` | action 方法抛出异常 |

### 3.11 响应式状态管理（Signal / Store / AppState）

框架提供三层状态管理，覆盖从局部到 session 级的不同作用域：

| 层级 | 类型 | 作用域 | 适合场景 |
|------|------|--------|----------|
| 局部状态 | `var` 字段 | Component 实例（per-session） | 表单输入、临时变量 |
| 响应式状态 | `Signal<T>` / `Store<S>` | Component 字段或模块级 | 需要自动追踪变更的状态 |
| Session 级状态 | `AppState` 接口 | Session 级别，跨导航持久 | 用户信息、全局配置、跨组件数据 |

#### 3.11.1 Signal\<T\>

`Signal<T>` 是响应式系统的核心单元，提供单值容器 + 订阅通知能力。

```cangjie
public class Signal<T> {
    func get(): T       // 读取 + 自动追踪（render 中调用时发现依赖）
    func set(v: T)      // 写入 + 触发所有订阅者
    func update(fn: (T) -> T)  // 函数式更新
    func subscribe(fn: () -> Unit)
}
```

**自动依赖追踪**：`SignalTracker.pendingSub` 是静态字段，`initSignals` 在首次 render 前将其设置为 reRender lambda。render 过程中任何 `Signal.get()` 调用都将该 reRender 添加到对应 Signal 的订阅列表。后续该 Signal 变更时自动触发 reRender。

```cangjie
// initSignals 核心流程
SignalTracker.pendingSub = Some(reRender)
let raw = state.page.render()        // Signal.get() 触发 → subs.add(reRender)
SignalTracker.pendingSub = None
```

**双触发保护**：`SignalTracker.rendered` 标志防止 Signal subscriber 和 `ReRender` 返回值导致的重复 patch。subscriber 执行时将 `rendered = true`，`runAction` 检查到后跳过 `sendPatch`。

#### 3.11.2 Store\<S\>

`Store<S>` 基于 `Signal<T>` 的函数式状态容器，提供 `set(updater)` 替代直接赋值。

```cangjie
public class Store<S> {
    func get(): S
    func set(updater: (S) -> S)   // 例如: store.set({ v => v + 1 })
    func subscribe(fn: () -> Unit)
}
```

`Store` 只是一个薄封装，所有能力来自内部的 `Signal<S>`。`store.set(fn)` 等价于 `signal.update(fn)`。

**使用方式**：

```cangjie
// 模块级 Store（全局 singleton，所有 session 共享）
let globalCount = Store<Int64>(0)

// Component 字段 Store（per-session，导航重建实例后重置）
class HomePage <: Component {
    var localStore = Store<String>("")
}
```

#### 3.11.3 AppState 接口

`AppState` 是空标记接口，用于将 session 级状态的类型注册到框架。

```cangjie
public interface AppState {}    // 空接口，仅做边界标记
```

**定义**：用户实现接口，内部使用 `Store<T>` 定义持久字段。

```cangjie
class AppData <: AppState {
    var counter = Store<Int64>(0)
    var user = Store<Option<User>>(None)
}
```

**注册**：通过 `App.state<T>()` 编译时注册工厂，每个 session 独立实例。

```cangjie
App()
    .state<AppData>({ => AppData() })
    .state<CartState>({ => CartState() })
    .host("0.0.0.0").port(8080).serve()
```

**访问**：两种方式。

方式一 — Action handler 中通过 `ctx.getState<T>()`：

```cangjie
func onClick({ ctx =>
    let d = ctx.getState<AppData>()
    d.counter.set({ v => v + 1 })
    PatchResult.ReRender
})
```

方式二 — `onMount` 生命周期中保存到字段，`render()` 直接访问：

```cangjie
class HomePage <: Component {
    var data: Option<AppData> = None

    func onMount(ctx: LifecycleContext): Unit {
        this.data = Some(ctx.getState<AppData>())
    }

    func render(): ComponentNode {
        let d = this.getAppData()
        p(text("counter: ${d.counter.get()}"))
    }
}
```

**实现原理**：

```text
App.state<AppData>(factory)
  → App.stateRegs 存入 (typeName, factory)
  → startSession → initStates(session)
    → session.states[TypeInfo.of<T>().qualifiedName] = factory()
  → onMount / runAction
    → ctx.getState<T>()
      → TypeInfo.of<T>().qualifiedName 反射取类名
      → session.states[key] match 转型到 T
```

`LifecycleContext` 和 `ActionContext` 都持有 `session.states` 引用，均提供 `getState<T>()` 方法。转型使用仓颉 `match(s) { case t: T => t }` 模式匹配实现类型安全的向下转型。

#### 3.11.4 三层次状态使用指南

| 场景 | 推荐方式 | 理由 |
|------|---------|------|
| 页面内临时状态 | Component `var` 字段 | 无需 Signal 追踪，最轻量 |
| 高频更新（定时器、动画） | `Signal<T>` 或 `Store<T>` | 自动追踪，精准 patch |
| 跨页面共享 | `AppState` 接口 | session 级持久，`onMount` 注入 |
| 全局共享（所有 session） | 模块级 `let store = Store<T>` | 单例，适合在线人数等 |
| 导航不保留 | Component `var` 字段 | 新建实例自动重置 |
| 导航需保留 | `AppState` 字段 | session 级生命周期 |

### 3.12 数据绑定（表单双向数据流）

#### 3.12.1 设计目标

表单是服务端驱动 UI 的典型痛点——用户的输入只存在于浏览器 DOM 中，服务端需要实时感知输入以执行校验、联动计算和提交。本框架的数据绑定设计遵循**单向数据流**原则：

```text
Keypress → DOM input.value 更新（本地，即时）
    ↓ (可配触发时机：debounce / blur / enter)
WS bind 消息 → server Signal.set() → reRender → patch
    ↓
patch 更新计算字段（校验结果、联动下拉、总价等）不覆盖用户正在编辑的 input
```

前端维护 input 自身的局部状态（用户敲入的字符），服务端只负责计算和联动，双方各司其职。

#### 3.12.2 核心 API

复用 `stdx.encoding.json.stream` 已有的 `JsonDeserializable<T>` 接口，不引入新类型。

```cangjie
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable, JsonReader, JsonDeserializable}

// P0 — 简单绑定（String 和 Int64 等内置类型已实现 JsonDeserializable）
input(placeholder: "Email").bind(this.email)
input(type: "number").bind(this.age)

// P1 — 复杂类型（Array、自定义对象）
// 自定义类型实现 JsonDeserializable 即可
extend TagList <: JsonDeserializable<TagList> {
    static func fromJson(r: JsonReader): TagList { ... }
}
tagWidget().bind(this.tags)   // T = TagList, 自动反序列化
```

`bind()` 方法签名：

```cangjie
public func bind<T>(signal: Signal<T>): ComponentNode where T <: JsonDeserializable<T>
```

#### 3.12.3 ComponentNode 扩展

新增 `_bids` 字段，结构与 `_actions` 类似，但不作为 HTML 属性渲染，仅服务端用于路由 bind 事件。

```cangjie
public struct ComponentNode <: JsonSerializable {
    let _bids: Option<HashMap<String, String>>   // bind-id → handler-name
    // _handlers 中存放对应的 ActionHandler
}
```

`bind()` 链式方法：
1. 生成 bind ID（如 `_b_1`）
2. 在 `_bids` 中记录 ID → ID 映射
3. 在 `_handlers` 中注册 ActionHandler：
   - 从 `ctx.params["value"]` 取 JSON 字符串
   - 转为 `ByteBuffer` → 创建 `JsonReader`
   - 调用 `T.fromJson(reader)` 反序列化
   - `signal.set(parsed)` 更新响应式状态
   - 返回 `PatchResult.ReRender`

#### 3.12.4 WS 协议

```json
// 浏览器 → 服务端
{"type":"bind","name":"_b_1","value":"\"hello\""}
{"type":"bind","name":"_b_2","value":"42"}
{"type":"bind","name":"_b_3","value":"[\"a\",\"b\"]"}

// 服务端 → 浏览器（同普通 action 的 patch）
{"kind":"patch","patches":[{"op":"replace","path":"","value":<tree>}]}
```

`"value"` 字段始终是 JSON 文本，`JsonReader` 天然兼容。

#### 3.12.5 前端行为

**渲染阶段**：
- `input`/`select`/`textarea` 渲染时设 `value="${signal.get()}"` + `data-bind-id`
- `value` 来自服务端 `Signal.get()` 的 JSON 序列化

**事件阶段**：
- 监听 `input`（文本类）/ `change`（选择类/复选框）
- debounce 300ms 后发送 `bind` 消息
- onBlur 立即发送（取消 debounce）
- onEnter（`input[type=text]`）立即发送
- 在发送前标记 `data-bind-dirty`，patch 时不覆盖该 input 的 value

**patch 阶段**：
- 检查目标元素是否有 `data-bind-id` + `data-bind-dirty`
- 有 → 跳过 `value` 属性更新，继续更新其他属性（`disabled`、`class`、`placeholder`）
- 无 → 正常更新全部属性
- 非 `data-bind-id` 的元素正常更新全部属性

#### 3.12.6 服务端处理

```
WS bind message
  → listenLoop 识别 t == "bind"
  → 提取 name + value
  → dispatchBind(ws, state, session, name, value)
    → 从 state.handlers 查找 handler
    → ActionContext.params["value"] = value
    → fn(ctx)
      → JsonReader 读取 value
      → T.fromJson(reader) → signal.set(val)
        → Signal subscriber reRender → patch
          → 联动字段在 reRender 中自动计算
```

#### 3.12.7 类型支持矩阵

| 类型 | 支持级别 | 备注 |
|------|---------|------|
| `String` | P0 | 内置，`JsonReader.readString()` |
| `Int64` | P0 | 内置，`JsonReader.readInt64()` |
| `Bool` | P0 | 内置，`JsonReader.readBool()` |
| `Float64` | P1 | 内置支持 |
| `Array<String>` | P1 | 用户 `extend` + `fromJson` |
| `HashMap<String, String>` | P1 | 用户 `extend` + `fromJson` |
| 自定义 struct/class | P1 | 实现 `JsonDeserializable<T>` |

## 4. 技术选型

| 模块 | 技术方案 |
|------|----------|
| HTTP 服务 | `tang` 框架（内置 WS 支持） |
| WebSocket | tang `ctx.upgrade()` + 自研 WS 循环 |
| 路由 | `@Page` 宏 + 编译时 `RouteRegistry` 注册 |
| JSON 序列化 | `stdx.encoding.json.stream`（原生支持 HashMap/Array/Option） |
| 响应式系统 | `Signal<T>` 自动追踪 + `Store<S>` 函数式更新 |
| Session 级状态 | `AppState` 接口 + `TypeInfo.of<T>()` 反射注册 |
| 组件树 Diff | `Signal` 精准 patch（`diff.cj` 过渡期保留） |
| 样式预处理 | `dart-sass` 二进制 + 宏（Phase 4） |
| 前端渲染器 | 原生 JS (~2KB) |
| 会话存储 | 内存 `HashMap` + TTL 淘汰 |

## 5. 实施路线图

### Phase 1: 最小可行产品（MVP）✅
- [x] 定义 `Component` 接口及生命周期方法。
- [x] 实现 `ComponentNode` 定义及序列化。
- [x] 实现 `@Page` 宏（基本路径匹配 + 动态参数 `[id]`）。
- [x] 实现基础 HTTP + WebSocket 服务（tang）。
- [x] 实现前端渲染器（首屏 + WS patch）。
- [x] 验证全链路流程。

### Phase 2: Action 与 Patch ✅
- [x] 实现 WebSocket 全链路（升级/消息/派发）。
- [x] 实现 Server Actions（getActions + ActionHandler）。
- [x] 实现后端 diff 算法（key + type）。（注：Phase 5 被 Signal 替代后废弃）
- [x] 实现 JSON Patch 生成与前端应用。
- [x] 实现会话基础管理。

### Phase 3: 生命周期与导航 ✅
- [x] 实现 `onMount`/`onUpdate`/`onUnmount` 事件触发。
- [x] 实现 `onError` 错误边界。
- [x] 实现导航机制（WS navigate / ctx.router.push）。
- [x] 实现 `defineCSS` 宏（纯 CSS 模式）。

### Phase 4: 增强特性
- [x] ~~构建时 SSG~~（后台系统场景不需要）
- [x] `defineCSS` / `@sass` 宏 + CssModule 样式系统。
- [x] WS 主动推送（`ctx.push`）。
- [x] 路由守卫（`@Page` 第三参数 + `Session.context`）。
- [x] WS 断线重连与 session 恢复。
- [x] 应用配置（title、favicon、links、scripts、theme）。
- [ ] 开发模式热重载（延迟到后期）。

### Phase 5: 优化与生态
- [x] `Signal<T>` + `Store<S>` — 响应式状态管理，**替代 diff 引擎**。
  - Signal 粒度追踪脏节点，精准 patch，零对比开销。
  - `SignalTracker` 自动依赖追踪，`rendered` 标志防双触发。
  - Component 与模块级 Store 均支持自动订阅。
- [x] `AppState` 接口 — session 级状态注册表 `ctx.getState<T>()`。
  - 编译时类型安全注册，`onMount` 注入组件字段。
  - `LifecycleContext` 与 `ActionContext` 均可访问。
  - 跨导航持久，新 Component 实例通过 onMount 获取。
- [ ] **数据绑定** — `bind<T>()` 表单双向数据流。
  - 复用 `JsonDeserializable<T>`，`where T <: JsonDeserializable<T>` 约束。
  - `ComponentNode._bids` 字段 + WS `bind` 消息。
  - 前端 debounce/blur/enter 触发 + patch 跳过编辑中 input。
- [ ] diff.cj 在 Signal 全量覆盖后移除。
- [ ] LRU 会话淘汰与内存监控。
- [ ] 组件库抽象（Button、Form、Table、Modal 等）。
- [ ] 性能优化（缓存策略）。
- [ ] 文档与示例应用。

## 6. 风险与应对

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| 仓颉宏 I/O 限制 | 无法在宏中安全读写文件 | 采用构建脚本分离方案 |
| `dart-sass` 二进制依赖 | 部署需携带额外文件 | 提供下载脚本，容器化时打包 |
| diff 算法性能 | 大组件树 diff 耗时 | key 优化、限制树深度、增量更新 |
| 会话内存占用 | 活跃会话多导致 OOM | TTL 淘汰 |

## 7. 总结

本设计文档提出了一套完整的、基于仓颉语言的企业级服务端驱动 UI 框架。核心创新点在于：
- **全栈仓颉**：从后端逻辑、组件渲染、样式编译到构建工具，统一使用仓颉语言。
- **后端 diff + 前端 patch**：既保证服务端状态权威性，又减少网络传输。
- **编译时样式系统**：通过宏和外部二进制，实现 Sass 支持且零运行时开销。
- **Next.js 类开发体验**：`@Page` 宏路由、Server Actions 等现代范式。

该框架特别适合内部管理系统、后台仪表板等对安全性和可维护性要求高的场景。
