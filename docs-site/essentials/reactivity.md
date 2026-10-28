# 响应式：Signal

## Signal<T\>

`Signal<T>` 是 cjxt 的核心响应式原语：

```cangjie
// 创建信号
let count = Signal<Int64>(0)

// 读取值（自动注册当前 scope 为依赖）
let val = count.get()

// 更新值（触发所有订阅 + 脏标记）
count.set(42)

// 基于当前值计算新值
count.update(fn: { v => v + 1 })

// 手动订阅
count.subscribe({ () => println("count changed") })

// 清除所有订阅
count.clearSubs()
```

## SignalTracker 自动依赖追踪

`SignalTracker` 维护作用域栈。在 `enterScope` 中 `get` 过的所有 Signal 变化时，都会触发 scope 回调：

```cangjie
SignalTracker.enterScope({ () =>
    count.get()       // 注册当前 scope 为 count 的依赖
    name.get()        // 注册当前 scope 为 name 的依赖
})
// count 或 name 变化时，scope 回调自动执行
```

核心机制：
- `get()` 时，如果当前在 scope 中，将 scope 回调注册为 Signal 的订阅者
- `set()` 时，遍历所有订阅者并执行
- `pendingRender` 全局标记联

### ⚠️ Signal 的生存期由「放在哪」决定

`Signal<T>` 自己不做生命周期管理。它能活多久，完全看它被存在什么对象上 ——
**这是本项目最容易踩错的一处**，选错位置的后果是「界面改了不动」或「状态莫名串了」。

| 存放位置 | 实际存活 | 典型误判 |
|---|---|---|
| 页面组件**实例字段** | **整个 WS 会话** | 以为「一次请求就丢」—— 其实 HTTP 首渲建的 session 会被随后的 WS 连接沿用，页面是同一个实例；只有**整页刷新**才重置 |
| `AppState` 字段 | 整个 session（跨导航、跨整页刷新） | — |
| 函数内 / `render()` 里 new | **一次渲染** | 以为能跨帧保持 |
| **包级 `let`** | **进程存活期**（所有会话共享） | — |

**判据**：

> 这个状态该不该跨浏览器标签页共享？
> 该 → 包级 `let`；不该但要跨导航 → `AppState`；只在本页、刷新可丢 → 页面实例字段。

**一个会让人误判成框架故障的场景**：用原生 `<form method="post">` 做整页提交时，
每次请求都会新建页面实例 → 页面字段上的 Signal 必然重置。
这不是 Signal 不能用，而是**那条路径本来就会换实例**；要保留状态得改走 WS action。

### 在组件中的自动追踪

`Component.renderWithScope(path)` 自动包装 `render()`：

```cangjie
class MyComponent <: Component {
    var count = Signal<Int64>(0)
    var name = Signal<String>("")

    public func render(): IComponent {
        // 访问 count.get() 和 name.get() →
        // 自动注册依赖，Signal 变化时标记 this 为脏
        div([
            text("${this.count.get()}"),
            Input().bind(this.name),
        ])
    }
}
```

任意依赖变化时，组件被标记为脏，下次 `sendPatch` 只重渲该组件子树。

## 脏标记系统

```cangjie
SignalTracker.pendingRender: Bool            // 重渲挂起标记
SignalTracker.execMutex: Mutex               // 执行互斥锁
```

脏组件队列**跨会话共享**（`sendPatch` 要按会话挑属于自己的），因此不暴露裸集合，
只提供加锁的受控访问：

```cangjie
SignalTracker.addDirty(c: Component)         // 标记（markDirty 内部调用）
SignalTracker.snapshotDirty(): ArrayList<Component>   // 查看（不清空）
SignalTracker.dirtyCount(): Int64            // 数量
RenderContext.collectDirty()                 // 收集（父覆盖子过滤）
RenderContext.collectOwnedDirty(session)     // 只挑本会话当前树上的
RenderContext.clearDirty()                   // 清理所有脏标记
RenderContext.clearDirtyForSession(session)  // 只清本会话
```

> 不要直接读写 `SignalTracker.dirtyComponents` —— 队列有锁保护，
> 裸访问会绕过它（早期文档里的 `dirtyComponents = ArrayList<Component>()` 写法已失效）。

## 并发与线程模型（多会话安全）

`Signal` 是**跨线程共享**的：cjxt 每条 WS 连接跑在一个线程上（`App.listenLoop`），
所以两个浏览器标签页 = 两条线程，可能同时读写**同一个** 包级 `Signal`。

框架内部把状态分两类处理，理解这条能解释很多「偶发」问题：

| 状态 | 归属 | 为什么 |
|---|---|---|
| `scopeStack` / `collectorStack` / `batchDepth` / `untrackedDepth` | **线程局部** | 语义是「本线程这一轮正在渲染什么」，不该跨线程共享 |
| `RenderContext` 的渲染捕获（`beginCapture`/`endCapture`） | **线程局部** | 「本线程这一轮渲染产出了哪些组件」 |
| `ReactiveNode.subs`（订阅表） | **加锁共享** | 同一个 Signal 会被多线程同时订阅/退订/通知 |
| `dirtyComponents`（脏组件队列） | **加锁共享** | `sendPatch` 要按会话挑属于自己的组件 |

> ⚠️ **不要在渲染回调里假设「全局只有一个会话在渲染」**。早期版本把渲染上下文
> 放在进程级静态变量里，多标签页并发操作时会出现：组件被登记到**错误的会话**名下、
> 订阅错乱，最终 **SIGSEGV（进程崩溃）** 或某会话的更新**静默丢失**。
> 已修复，回归用例见 `src/concurrency_race_test.cj`。

**对使用者意味着什么**：你不需要自己加锁 —— 框架已保证 `Signal` 的读写与订阅管理是线程安全的。
但你**写在 Signal 里的业务对象**如果被多线程改写，仍要自己保证其内部一致性。

## Signal 与 AppState 的选用

两者都在解决「组件间共享状态」，但机制和作用域完全不同：

| | 包级 `Signal` / `Computed` | `AppState` |
|---|---|---|
| 是什么 | 普通响应式值，放在包级 `let` | **空标记接口**（`public interface AppState {}`） |
| 框架认识它吗 | 不认识（就是普通对象） | 认识：`App.state<T>()` 注册 + 每会话注入 |
| 作用域 | **进程级** —— 所有会话、所有标签页共享 | 固定：**每会话一份**，跨导航；整页刷新重置 |
| 会话之间隔离 | ❌ 共享同一份 | ✅ 各一份 |
| 能派生（`Computed`） | ✅ | ✅（字段里放 Signal/Computed） |

**选用判据**：

- 状态**每个用户各一份**（购物车、表单草稿、当前选中项）→ **`AppState`**
- 状态**全站唯一**（站点配置、在线人数、缓存）→ **包级 `Signal`**（要派生就配 `Computed`）
- 状态只在本页、刷新可丢 → 页面实例字段

**关于「跨组件的状态容器」**：不需要额外的 `Store` 类型。包级 `Signal` 已经提供了
跨组件/跨页面共享所需的一切（读写、订阅、派生、`bind()` 直连组件、相等性去重、精确退订）。
早期版本曾有一个 `Store<S>`（`Signal` 的薄封装），因其能力被 `Signal` 完全覆盖、
且**无法传给组件的 `bind()`**（未实现 `Readable`），已移除。若你仍在旧代码里看到它，
直接把 `Store<Int64>(0)` 换成 `Signal<Int64>(0)`、`store.set({ v => ... })` 换成
`store.update({ v => ... })` 即可。

## 会话级全局状态（AppState）

通过 `AppState` 接口 + `ActionContext.getState<T>()` 实现跨组件共享：

```cangjie
// 定义状态
class CounterState <: AppState {
    var count = Signal<Int64>(0)
}

// 注册
App().state<CounterState>({ => CounterState() })

// 在 Action handler 中使用
button([text("+")]).onClick({ ctx =>
    let st = ctx.getState<CounterState>()
    st.count.set(st.count.get() + 1)
    PatchResult.ReRender
})

// 在 onMount 中使用
public func onMount(ctx: LifecycleContext): Unit {
    let st = ctx.getState<CounterState>()
    this.state = st
}
```
