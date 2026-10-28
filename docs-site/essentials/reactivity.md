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

public static var pendingRender: Bool       // 重渲挂起标记
public static var dirtyComponents = ArrayList<Component>()  // 全局脏组件列表
public static var execMutex = Mutex()        // 执行互斥锁
```

- `Component.markDirty()` 将组件加入 `dirtyComponents`
- `RenderContext.collectDirty()` 收集脏组件（父覆盖子过滤）
- `RenderContext.clearDirty()` 清理所有脏标记

## Store

`Store<S>` 是对 `Signal<S>` 的简单封装：

```cangjie
let store = Store<Int64>(0)

store.get()                                          // 读值
store.set(fn: { v => v + 1 })                        // 更新
store.subscribe({ () => println("store changed") })  // 订阅
```

### ⚠️ Store 的作用域 = 它被放在哪里

框架**不管理** `Store` 的生命周期 —— 它就是一个普通对象，活多久取决于你把它存在什么位置：

| 存放位置 | 实际作用域 |
|---|---|
| **包级 `let`** | **进程级** —— 所有会话、所有浏览器标签页共享 |
| 页面组件字段 | 该页面实例（整个 WS 会话，整页刷新即重置） |
| `render()` 里 new | **一次渲染**，下一帧就没了 |

实测过包级 `Store` 的跨会话行为：标签页 A 把值点到 3，**新开的标签页 B 直接读到 3**。

所以「Store 是跨组件的」这句话，**只在包级定义时成立**。

## Store 与 AppState 的选用

两者都在解决「组件间共享状态」，但机制完全不同，容易混：

| | `Store<S>` | `AppState` |
|---|---|---|
| 是什么 | 普通类，包一个 `Signal<S>` | **空标记接口**（`public interface AppState {}`） |
| 框架认识它吗 | **不认识** | 认识：`App.state<T>()` 注册 + 每会话注入 |
| 作用域 | **由存放位置决定**（见上表） | 固定：**每会话一份**，跨导航、跨整页刷新，会话之间隔离 |
| 跨浏览器标签页共享 | ✅ 包级定义时可以 | ❌ 不能 |

**选用判据**：

- 状态**每个用户各一份**（购物车、表单草稿、当前选中项）→ **`AppState`**
- 状态**全站唯一**（站点配置、在线人数、缓存）→ **包级 `Store`** 或包级 `Signal`
- 状态只在本页、刷新可丢 → 页面实例字段

> 现状：`Store` 目前只在框架单测里用到，示例站与实际应用都没用它。需要共享状态时，
> 优先考虑 `AppState`（每会话）或包级 `Signal`（全局）。

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
