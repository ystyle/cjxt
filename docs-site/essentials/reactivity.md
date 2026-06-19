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

## 全局状态（AppState）

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
