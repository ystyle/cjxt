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
│  │  路由管理器    │  │  WS Manager  │  │  会话管理器           │ │
│  │  (@Page 宏)   │  │  - 连接管理  │  │  - Session 生命周期   │ │
│  │  编译时注册    │  │  - 消息路由  │  │  - 组件树缓存          │ │
│  └──────┬──────┘  │  - 心跳检测  │  │  - TTL 淘汰           │ │
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
│  │  Diff & Patch 引擎                                       │ │
│  │  - 维护会话当前组件树                                     │ │
│  │  - action 处理后 render 新树，diff 产出 JSON Patch       │ │
│  │  - patch 通过 WS 推送到前端                               │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## 3. 核心模块设计

### 3.0 设计理念：路由·状态·UI 一体化

仓颉没有现有框架生态，因此不采用前端领域"路由库 + 状态管理库 + UI 框架"的分层拼装模式，而是将三者合并为一套语言层级的统一抽象：

```
┌─────────────────────────────────────────┐
│   @Page("/path")  →  路由声明            │
│         │                               │
│   Component 接口   →  UI 渲染 + 生命周期  │
│         │                               │
│   var 字段 + ReRender → 状态管理          │
│         │                               │
│   public method  →  Server Action        │
└─────────────────────────────────────────┘
```

**为什么可以一体化**：

- 服务端驱动的模式下，"前端三件套"在后端没有物理分层的必要——路由是组件注册，状态是类字段，Action 是成员方法，它们天然属于同一个 class。
- 拆开会导致：路由表单独维护一处、状态单独定义一套 action/reducer、渲染函数单独声明 —— 徒增心智负担和文件跳转成本。
- 一体化后，一个页面就是一个 `@Page` class，所有逻辑集中在一个地方，降低认知负担，提升重构安全。

**设计原则**：
| 传统前端范式 | 本框架方案 | 优势 |
|-------------|-----------|------|
| React Router | `@Page` 宏 | 编译时校验，无运行时路由匹配开销 |
| Redux / Pinia | `var` 字段 + `ReRender` | 零样板代码，类型天然安全 |
| React Component | `Component` 接口 | 生命周期服务端可控，前后端时序一致 |
| API Route / Handler | `public method` | 反射自动暴露，无需额外注册 |

> **未来优化**：`var + ReRender` 是全树重渲染后再 diff，对于高频更新的局部组件可引入 `Signal<T>` 实现细粒度响应式。`Signal<T>` 包装一个值并提供 `get()`/`set()`/`update()`，在 render 阶段自动追踪依赖，变更时仅重渲染脏子树。
>
> 对于跨组件/跨页面的全局状态，引入 `Store<S>`（类似 Zustand），提供 `get(selector)` 和 `set(updater)`，变更时自动触发现有 `ReRender` 链路。
>
> `Signal<T>` 和 `Store<S>` 底层共享同一套响应式机制，二者配合可覆盖从局部到全局的所有状态管理需求。具体实现在 Phase 5 细化。

### 3.1 组件契约 —— `Component` 接口

所有组件的统一抽象，定义`生命周期 + 渲染`的约定。`struct` 和 `class` 均可实现此接口。

```cangjie
public interface Component {
    // 必须：渲染产出组件树
    func render(): ComponentNode

    // 生命周期：组件已渲染到前端 DOM
    func onMount(ctx: LifecycleContext): Unit {}

    // 生命周期：组件属性或状态更新后
    func onUpdate(ctx: LifecycleContext): Unit {}

    // 生命周期：组件将被卸载前
    func onUnmount(ctx: LifecycleContext): Unit {}

    // 错误边界：action 抛出异常时回调
    func onError(ctx: ErrorContext): Unit {}
}
```

**设计说明**：
- 所有生命周期方法提供默认空实现，最小化样板代码。
- 触发时机由后端的 diff 引擎负责探测（新增节点→`onMount`，移除节点→`onUnmount`，属性变化→`onUpdate`）。
- `LifecycleContext` / `ErrorContext` 定义见 3.10。

### 3.2 数据模型 —— `ComponentNode`

组件树的可序列化表示，是前后端通信的桥梁。`Component.render()` 产出此结构。

```cangjie
public enum ComponentType <: ToString & Equatable<ComponentType> {
    | Div | Span | Button | Input | Form
    | Table | Text | Image | H1 | H2 | H3
    | P | Select | Textarea | A | Ul | Li

    public func toString(): String {
        match (this) {
            case Div => "div"
            // ...
        }
    }
}

public type Attributes = HashMap<String, String>
public type ActionMap = HashMap<String, String>

public struct ComponentNode <: JsonSerializable {
    let typ: ComponentType
    let attrs: Option<Attributes>
    let children: Array<ComponentNode>
    let key: Option<String>
    let actions: Option<ActionMap>

    public init(typ: ComponentType, children: Array<ComponentNode>,
                attrs!: Option<Attributes> = None, key!: Option<String> = None,
                actions!: Option<ActionMap> = None) { ... }

    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("type").writeValue(this.typ.toString())
        w.writeName("attrs").writeValue(this.attrs)
        w.writeName("actions").writeValue(this.actions)
        w.writeName("children").writeValue(this.children)
        w.endObject()
    }
}

// 标签辅助函数（命名参数默认值 DSL）
public func div(children: Array<ComponentNode>,
                attrs!: Option<Attributes> = None,
                key!: Option<String> = None,
                actions!: Option<ActionMap> = None): ComponentNode {
    ComponentNode(ComponentType.Div, children, attrs: attrs, key: key, actions: actions)
}
// ... span, button, text, h1, h2, p, input, form, image, a, ul, li 同理
```

### 3.3 页面与组件定义规范

页面通过 `@Page` 宏声明路由路径，框架在编译时收集所有 `@Page` 注解生成路由注册表。组件按场景可分为 **struct（纯展示/无状态）** 或 **class（业务页面/有状态）**。

#### 无状态组件 —— `struct implements Component`

适合纯展示卡片、布局等，无内部状态，渲染仅依赖构造时传入的数据。

```cangjie
// components/card.cj
public struct Card implements Component {
    let title: String
    let content: String

    public func render(): ComponentNode {
        div(attrs: ["class": "card"],
            children: [
                h1(children: [text(title)]),
                div(children: [text(content)])
            ])
    }
}
```

#### 有状态组件 —— `class implements Component`

适合业务页面，使用 `var` 维护可变状态，状态变更后触发重渲染。

```cangjie
@Page["/order/detail"]
public class OrderPage <: Component {
    let orderId: String
    var order: OrderData
    var loading: Bool = true

    public init(orderId: String) {
        this.orderId = orderId
        this.order = db.fetchOrder(orderId)
        this.loading = false
    }

    public func render(): ComponentNode {
        if (loading) {
            return div([text("加载中...")])
        }
        return div([h1([text("订单 ${order.orderId}")]), text("状态: ${order.status}")],
                   attrs: Some(["class": "order-detail"]))
    }

    public func getActions(): HashMap<String, ActionHandler> {
        HashMap<String, ActionHandler>([
            ("approve", { ctx =>
                db.updateOrderStatus(orderId, "approved")
                this.order.status = "approved"
                PatchResult.ReRender
            })
        ])
    }

    public func onMount(_: LifecycleContext): Unit {
        Logger.info("OrderPage 已挂载，orderId=${orderId}")
    }
}
```

**页面组件规范总结**：

| 元素 | 说明 |
|------|------|
| `@Page(path)` | 宏注解，声明路由路径，支持动态参数如 `@Page("/order/[id]")` |
| `implements Component` | 实现 Component 接口，提供 render() 和生命周期方法 |
| 构造函数 | 框架匹配路由后通过构造函数注入路由参数和数据 |
| `getServerSideProps` (可选) | 静态函数，在构造前调用，返回数据传给构造函数 |

> `@component` 宏可考虑用于轻量 lambda 场景（未来扩展），当前优先保证 interface + struct/class 的核心方案。

### 3.4 路由与导航

采用 **`@Page` 宏声明 + 编译时注册** 的方式，替代文件路径映射。

#### 3.4.1 `@Page` 宏

在页面类上使用 `@Page` 宏声明路由路径：

```cangjie
@Page["/order/list"]
public struct OrderListPage <: Component { ... }

@Page["/order/[id]"]         // 动态参数
public class OrderDetailPage <: Component { ... }

@Page["/user/profile"]
public struct UserProfilePage <: Component { ... }
```

**宏展开产物**：编译时 `@Page` 宏收集所有路径-类型映射，在 class 定义后追加 Token 序列，生成路由注册语句：

```cangjie
// 由 @Page 宏自动生成（开发者无需手写）
let __reg_OrderListPage__ = RouteRegistry.global().register("/order/list", { => OrderListPage() })
```

#### 3.4.2 首屏加载流程

HTTP GET 请求到达后，框架查找路由注册表，匹配路径，构造组件实例：

```cangjie
func handlePageRequest(req: HttpRequest): HttpResponse {
    let route = routeRegistry.match(req.path)  // /order/123 → OrderDetailPage + {id: "123"}
    if (route == None) { return HttpResponse(404) }

    // 数据预取（可选，由页面类静态定义）
    let data = route.pageType.getServerSideProps?(route.params)

    // 构造组件实例——通过构造函数注入参数
    let page: Component
    if (data != None) {
        page = route.pageType.newInstance(data)
    } else {
        page = route.pageType.newInstance(route.params)
    }

    // 渲染组件树
    let tree = page.render()

    // 创建会话，缓存组件树
    let session = sessionManager.create(page, tree, route.path)

    // 返回 HTML 壳 + 初始组件树 JSON
    let html = generateHtmlShell(session.id, tree)
    return HttpResponse(200, "text/html", html)
}
```

#### 3.4.3 导航切换（Navigate）

导航是**运行时行为**——用户触发后，服务端切换页面并触发生命周期。两种触发方式：

**方式一：action 内调用 `ctx.router.push`**

在 action 中随时调用，调用后立即导航，后续代码不再执行：

```cangjie
public func saveAndBack(ctx: ActionContext): PatchResult {
    db.save(formData)
    ctx.router.push("/order/list")
}
```

**方式二：前端直接发起 `navigate`**

```text
WS: { type: "navigate", path: "/order/list" }
```

**服务端导航处理流程**：

```cangjie
func handleNavigate(session: Session, targetPath: String) {
    // 1. 卸载当前页面
    session.page.onUnmount(LifecycleContext{ session })

    // 2. 匹配新路由
    let route = routeRegistry.match(targetPath)

    // 3. 构造新页面实例
    let newPage = route.pageType.newInstance(route.params)

    // 4. 渲染新树
    let newTree = newPage.render()

    // 5. 更新会话的页面和树
    session.updatePage(newPage, newTree, targetPath)

    // 6. 通过 WS 推送新页面的完整树
    session.ws.send({ type: "fullTree", tree: newTree, path: targetPath })

    // 7. 前端渲染完成后发送 ack:mount
    //    服务端收到后调用 newPage.onMount()
}
```

#### 3.7.2 交互通道（WebSocket）

页面加载后，前端 JS 主动发起 WS 连接：

```text
客户端 → 服务端: { type: "connect", sessionId: "..." }
服务端 → 客户端: {"kind":"connected"}
服务端 → 客户端: {"kind":"patch","patches":[{"op":"replace","path":"","value":<tree>}]}
客户端 → 服务端: {"type":"action","name":"click","params":{}}
服务端 → 客户端: {"kind":"patch","patches":[...]}
```

WS 连接建立后，该会话的所有 action、patch 均通过 WS 传输，不再使用 HTTP。

协议消息使用标准 `JsonSerializable` struct 定义：

```cangjie
public struct ConnectedMsg <: JsonSerializable {
    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("connected")
        w.endObject()
    }
}

public struct PatchMsg <: JsonSerializable {
    let patches: Array<PatchEntryMsg>
    public func toJson(w: JsonWriter): Unit {
        w.startObject()
        w.writeName("kind").writeValue("patch")
        w.writeName("patches").writeValue(this.patches)
        w.endObject()
    }
}
```

### 3.5 后端 Diff 与 Patch

**核心思想**：每次 action 处理后，服务端生成新组件树，与旧树进行差异比较，输出 JSON Patch（RFC 6902 格式），前端应用 patch。

**数据结构**：

```cangjie
enum PatchOp {
    Add, Remove, Replace, Move, Copy, Test
}

struct Patch {
    let op: PatchOp
    let path: string   // JSON Pointer 格式，如 "/children/0/attrs/class"
    let value: Json?   // 可选
    let from: string?  // 用于 Move/Copy
}
```

**Diff 算法简化版**：

```cangjie
func diff(old: ComponentNode, new: ComponentNode, basePath: string = ""): Array<Patch> {
    var patches = []
    if old.type != new.type || old.key != new.key {
        patches.push(Patch{op: Replace, path: basePath, value: serialize(new)})
        return patches
    }
    // 对比属性
    for (k, v) in old.attrs {
        if new.attrs.get(k) != v {
            patches.push(Patch{op: Replace, path: "${basePath}/attrs/${k}", value: new.attrs[k]})
        }
    }
    // 对比 children (使用 LCS 或简单索引比较，可借助 key)
    // ... 递归
    return patches
}
```

**会话缓存**：内存中维护 `Map<SessionId, ComponentNode>`，定期清理不活跃会话。

### 3.6 Server Actions

Action 通过 WS 消息传输，不再使用 HTTP POST。

#### 核心类型定义

```cangjie
// Action 执行上下文，注入到每个 action handler 的第一个参数
public struct ActionContext {
    let sessionId: String
    let params: HashMap<String, String>
    let router: Router
}

// Action 返回类型
public enum PatchResult {
    ReRender,                       // 触发全树 render + diff + patch
    Patch(patches: Array<Patch>),   // 直接返回指定 patch
}

// 路由操作对象，由框架注入
public struct Router {
    let sessionId: String
    let navigateFn: (String) -> Unit

    public func push(path: String): Unit
}

// Action handler 类型
public type ActionHandler = (ActionContext) -> PatchResult
```

#### WS 消息格式

```text
客户端 → 服务端: {
    type: "action",
    name: "approve",
    params: { "orderId": "123" }
}
```

#### 服务端处理流程

```cangjie
func handleWSAction(session: Session, msg: WsMessage) {
    let page = session.page as Component
    let method = reflect(page, msg.name)

    // 构造 ActionContext，注入 router
    let ctx = ActionContext{
        session: session,
        params: msg.params,
        router: Router{ session: session }
    }

    let result = method.call(page, ctx)

    if (result is ReRender) {
        let newTree = page.render()
        let patches = diff(session.tree, newTree)
        session.tree = newTree

        session.ws.send({ type: "patch", patches: patches })
        page.onUpdate(LifecycleContext{ session })
    }
}
```

> **注意**：若 action 内部调用 `ctx.router.push(path)`，则 `Router.push` 内部直接调用导航流程，action 返回的 `PatchResult` 被忽略（无需再 ReRender）。

### 3.7 实时推送 (WebSocket 主动推送)

WS 连接建立后，服务端可在任意时刻向客户端推送消息，无需等待 action 请求。

**场景**：
- 服务端主动推送数据变更（如审批状态变化）。
- 协作编辑提醒。
- 系统通知。

**推送方式**：

```cangjie
// 在任意业务代码中
sessionManager.send(userId, {
    type: "push",
    patches: [
        { op: "replace", path: "/children/0/children/2", value: text("状态: 已审批") }
    ]
})
```

**前端处理**：渲染器的 WS 接收逻辑统一处理 `patch` 和 `push` 消息，应用方式完全一致。

### 3.8 样式系统：`defineCSS` 宏

#### 设计目标
- 支持纯 CSS 和 Sass（后续可扩展 Less）。
- 编译时处理，零运行时开销。
- 可选 kind 参数，不写则默认为 CSS。

#### 使用示例

```cangjie
// 纯 CSS
let btnStyle = defineCSS(`
    .btn { color: red; }
`)

// 使用 Sass
let sassStyle = defineCSS(kind: "sass", `
    $primary: #007bff;
    .btn {
        background: $primary;
        &:hover { background: darken($primary, 10%); }
    }
`)
```

#### 实现方案（构建脚本 + 外部二进制）

**步骤1：宏 `defineCSS` 生成唯一标识并保存源文件**

宏在编译时不会直接调用编译器，而是：
- 计算内容的 hash（如 SHA256）。
- 将原始内容写入 `target/.css-cache/<hash>.sass` 或 `.css`。
- 生成代码：`include_css!("<hash>")`。

**步骤2：构建脚本 `build.cj`**

在 `cjpm build` 前执行：
- 扫描 `target/.css-cache/*.sass`，若对应的 `.css` 不存在或源文件更新，则调用 `dart-sass` 二进制编译。
- 将编译结果写入 `<hash>.css`。

**步骤3：宏 `include_css!`**

读取 `<hash>.css` 文件内容，返回字符串字面量嵌入到代码中。

**外部工具准备**：
- 下载 `dart-sass` 独立二进制，放置在项目工具目录或系统 PATH 中。
- 在构建脚本中通过 `exec` 调用。

#### 优势
- 完全编译时处理，运行时无开销。
- 支持增量编译（基于文件时间戳）。
- 开发者无需额外配置构建管道（除了首次放置二进制）。

### 3.9 前端轻量渲染器

使用原生 JavaScript（约 3KB gzipped），支持 HTTP 首屏加载和 WS 交互双通道。

```javascript
class CangjieUI {
    constructor(container, sessionId) {
        this.container = container;
        this.sessionId = sessionId;
        this.tree = null;
        this.ws = null;
    }

    // 初始化：渲染首屏树，建立 WS 连接
    init(tree) {
        this.tree = tree;
        this.renderTree(tree, this.container);
        this.connectWS();
    }

    connectWS() {
        this.ws = new WebSocket(`ws://${location.host}/_ws`);
        this.ws.onopen = () => {
            this.ws.send(JSON.stringify({
                type: "connect",
                sessionId: this.sessionId
            }));
        };
        this.ws.onmessage = (e) => {
            const msg = JSON.parse(e.data);
            switch (msg.type) {
                case "connected":  this.onMount(); break;
                case "patch":      this.applyPatches(msg.patches); break;
                case "push":       this.applyPatches(msg.patches); break;
                case "fullTree":   this.loadNewPage(msg); break;
                case "pong":       break;
            }
        };
        // 自动重连逻辑...
    }

    loadNewPage(msg) {
        this.tree = msg.tree;
        this.container.innerHTML = '';
        this.renderTree(msg.tree, this.container);
        this.ws.send(JSON.stringify({ type: "ack", event: "mount" }));
    }

    onMount() {
        this.ws.send(JSON.stringify({ type: "ack", event: "mount" }));
    }

    renderTree(node, parentEl) {
        const el = document.createElement(node.type);
        for (const [k, v] of Object.entries(node.attrs)) {
            el.setAttribute(k, v);
        }
        for (const [event, actionName] of Object.entries(node.actions)) {
            el.addEventListener(event, (e) => {
                const params = this.extractParams(el, e);
                this.ws.send(JSON.stringify({
                    type: "action",
                    name: actionName,
                    params
                }));
            });
        }
        for (const child of node.children) {
            this.renderTree(child, el);
        }
        parentEl.appendChild(el);
    }

    applyPatches(patches) {
        for (const patch of patches) {
            const target = this.locateNodeByPath(patch.path);
            if (patch.op === "replace") {
                this.updateNode(target, patch.value);
            }
        }
    }
}
```

### 3.10 生命周期管理

组件生命周期由服务端框架驱动，通过 WS 消息与前端协作。

#### 完整生命周期流程

```text
┌─────────┐          ┌─────────────┐          ┌───────────┐
│  浏览器  │          │  HTTP/WS 服务│          │  业务组件  │
│ (渲染器)  │          │  (框架)     │          │ (Component)│
└────┬─────┘          └──────┬──────┘          └─────┬─────┘
     │                       │                       │
     │  ① HTTP GET /page     │                       │
     │──────────────────────│                       │
     │                       │  ② 路由匹配           │
     │                       │──────────────────────│
     │                       │  ③ getServerSideProps │
     │                       │──────────────────────│
     │                       │  ④ new 构造组件       │
     │                       │──────────────────────│
     │                       │  ⑤ render()          │
     │                       │◄─────────────────────│
     │                       │  ⑥ 创建 Session       │
     │  HTML + 初始树 JSON    │                       │
     │◄─────────────────────│                       │
     │  ⑦ 渲染首屏 DOM       │                       │
     │                       │                       │
     │  ⑧ WS connect(sid)    │                       │
     │──────────────────────│                       │
     │                       │  ⑨ onMount()         │
     │                       │──────────────────────│
     │ ⑩ connected + ack:mount│                       │
     │◄─────────────────────│                       │
     ╞═══════════════════════╪═══════════════════════╡
     │     交互阶段（可多次）  │                       │
     │                       │                       │
     │  ⑪ WS action(name, p) │                       │
     │──────────────────────│                       │
     │                       │  ⑫ 反射调用 public    │
     │                       │     method            │
     │                       │──────────────────────│
     │                       │  ← ReRender           │
     │                       │◄─────────────────────│
     │                       │  ⑬ render()          │
     │                       │──────────────────────│
     │                       │  ⑭ diff → patches    │
     │ ⑮ WS patch(patches)   │                       │
     │◄─────────────────────│                       │
     │  ⑯ 应用 patch 到 DOM  │                       │
     │  ⑰ WS ack:update      │                       │
     │──────────────────────│                       │
     │                       │  ⑱ onUpdate()        │
     │                       │──────────────────────│
     ╞═══════════════════════╪═══════════════════════╡
     │     导航 / 离开        │                       │
     │                       │                       │
     │  ⑲ WS navigate(path)  │                       │
     │   (或 WS 断开)        │                       │
     │──────────────────────│                       │
     │                       │  ⑳ onUnmount()       │
     │                       │──────────────────────│
     │                       │  ㉑ 回收 Session      │
     │ ㉒ 新的 HTTP 首屏流程  │                       │
     │──────────────────────│                       │
```

#### Component 接口（完整版）

```cangjie
public interface Component {
    // 必须：渲染产出组件树
    func render(): ComponentNode

    // 生命周期：组件已渲染到前端 DOM
    func onMount(ctx: LifecycleContext): Unit {}

    // 生命周期：组件属性或状态更新后
    func onUpdate(ctx: LifecycleContext): Unit {}

    // 生命周期：组件将被卸载前
    func onUnmount(ctx: LifecycleContext): Unit {}

    // 错误边界：action 抛出异常时回调
    func onError(ctx: ErrorContext): Unit {}
}
```

#### 生命周期触发条件

| 方法 | 触发条件 | 调用时机 |
|------|---------|---------|
| `render()` | 页面首次加载 / action 返回 `ReRender` | 每次需要生成组件树时 |
| `onMount` | 服务端收到前端 `ack: mount` | WS 连接建立后 |
| `onUpdate` | patch 推送到前端后 | 每次 diff/patch 完成后 |
| `onUnmount` | 会话超时 / 页面跳转 / WS 断开 | 资源回收前 |
| `onError` | action 方法抛出异常 | 异常发生时，用于日志/监控/清理，不可影响返回给前端的 patch |

#### 生命周期上下文

```cangjie
public struct LifecycleContext {
    let sessionId: String
    let routeParams: Dictionary<String, String>
    let componentKey: String?      // 当前组件在树中的 key
    let triggerAction: String?     // 触发此次更新的 action 名称
}

public struct ErrorContext {
    let sessionId: String
    let actionName: String
    let error: Error
    let defaultPatch: Array<Patch>  // 框架生成的默认错误提示 patch
}
```

### 3.11 类型安全与错误处理

- 利用仓颉的强类型系统，组件属性、Action 参数等使用 struct 定义，减少运行时错误。
- 在开发模式下，服务端返回的 patch 可包含额外的调试信息。
- 错误边界：若 action 抛出异常，框架 catch 后调用 `onError` 做日志/监控，同时向前端推送默认错误提示 patch。

## 4. 技术选型

| 模块 | 技术方案 | 理由 |
|------|----------|------|
| HTTP 服务 | `tang` 框架 | 成熟稳定，性能足够，内置 WS 支持 |
| WebSocket | tang `ctx.upgrade()` + 自研 WS 循环 | 轻量，无外部依赖 |
| 路由 | `@Page` 宏 + 编译时注册 | 强类型、编译时校验、重构安全 |
| JSON 序列化 | `stdx.encoding.json.stream` (JsonWriter + JsonSerializable) | 原生支持 HashMap/Array/Option |
| 组件树 Diff | 自研按 key + type 比较 | 针对组件树优化 |
| 样式预处理 | `dart-sass` 二进制 + 仓颉宏 (Phase 4) | 稳定、功能强大、纯编译时 |
| 前端渲染器 | 原生 JS (~2KB) | 无框架依赖，体积小 |
| 会话存储 | 内存 `HashMap` + TTL 淘汰 | 管理端并发不高，简单可靠 |

## 5. 实施路线图

### Phase 1: 最小可行产品（MVP）✅
- [x] 定义 `Component` 接口及生命周期方法。
- [x] 实现 `ComponentNode` 定义及序列化（JsonSerializable）。
- [x] 实现 `@Page` 宏（基本路径匹配 + 动态参数 `[id]`）。
- [x] 实现基础 HTTP + WebSocket 服务（tang 框架）。
- [x] 实现前端渲染器（首屏整体渲染 + WS patch 应用）。
- [x] 验证"服务端渲染组件树"完整流程。

### Phase 2: Action 与 Patch ✅
- [x] 实现 WebSocket 全链路（升级/消息读写/action 派发）。
- [x] 实现 Server Actions 框架（getActions + ActionHandler 回调）。
- [x] 实现后端 diff 算法（基于 key + type）。
- [x] 实现 JSON Patch 生成与前端应用（WS 传输）。
- [x] 实现会话基础管理（创建/获取/清理）。

### Phase 3: 生命周期与导航（进行中）
- [ ] 实现 `onMount`/`onUpdate`/`onUnmount` 生命周期事件触发。
- [ ] 实现 `onError` 错误边界。
- [ ] 实现导航机制（WS navigate / ctx.router.push）。
- [ ] 实现 `defineCSS` 宏（纯 CSS）。
- [ ] 集成 `dart-sass` 二进制，完善构建脚本。
- [ ] 支持 `kind: "sass"`。

### Phase 4: 增强特性
- [ ] 构建时 SSG（生成静态 HTML）。
- [ ] WS 主动推送集成（push 消息）。
- [ ] 开发模式热重载。
- [ ] WS 断线重连与 session 恢复。
- [ ] 前端 navigate 客户端路由过渡动画。
- [ ] 应用配置（theme、layout 等）。

### Phase 5: 优化与生态
- [ ] 组件库抽象（Button、Form、Table、Modal 等）。
- [ ] `Signal<T>` 细粒度响应式实现。
- [ ] `Store<S>` 全局状态管理实现（类似 Zustand）。
- [ ] 性能优化（diff 算法优化、缓存策略）。
- [ ] LRU 会话淘汰与内存监控。
- [ ] 文档与示例应用。

## 6. 风险与应对

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| 仓颉宏 I/O 限制 | 无法在宏中安全读写文件 | 采用构建脚本分离方案 |
| `dart-sass` 二进制依赖 | 部署需携带额外文件 | 提供下载脚本，容器化时打包 |
| diff 算法性能 | 大组件树 diff 耗时 | 引入 key 优化，限制树深度，考虑增量更新 |
| 前端 patch 库体积 | 增加 JS 体积 | 自研精简 patch 应用器（<1KB） |
| 会话内存占用 | 活跃会话多导致 OOM | 设置 TTL，使用 LRU 淘汰 |

## 7. 总结

本设计文档提出了一套完整的、基于仓颉语言的企业级服务端驱动 UI 框架。核心创新点在于：
- **全栈仓颉**：从后端逻辑、组件渲染、样式编译到构建工具，统一使用仓颉语言。
- **后端 diff + 前端 patch**：既保证服务端状态权威性，又减少网络传输。
- **编译时样式系统**：通过宏和外部二进制，实现 Sass 支持且零运行时开销。
- **Next.js 类开发体验**：`@Page` 宏路由、Server Actions、数据预取等现代范式。

该框架特别适合内部管理系统、后台仪表板等对安全性和可维护性要求高的场景，可显著降低前端复杂度，提升整体开发效率。
