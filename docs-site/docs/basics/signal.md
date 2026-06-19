# Signal

Signal 是 cjxt 的响应式数据单元，类似 SolidJS 的 Signal、Vue 的 `ref`。

## 创建信号

```cangjie
let count = Signal<Int64>(0)
let name = Signal<String>("")
```

## 读写值

```cangjie
count.get()              // 读值
count.set(42)            // 设值
count.update(fn: { v => v + 1 })  // 基于当前值计算
```

## 在组件中使用

```cangjie
class Counter <: Component {
    var count = Signal<Int64>(0)

    public func render(): IComponent {
        div([
            text("值: ${this.count.get()}"),
            button(text("+1")).onClick({ ctx =>
                this.count.update(fn: { v => v + 1 })
                PatchResult.ReRender
            }),
        ])
    }
}
```

组件在 `render()` 中访问 Signal 时自动建立依赖关系，Signal 变化时自动重渲该组件。

## 表单绑定

Signal 通过 `bind()` 与表单组件双向绑定：

```cangjie
Input().bind(this.state.username)             // Signal<String>
Slider().bind(this.state.volume)              // Signal<Int64>
Switch().bind(this.state.enabled)             // Signal<Bool>
Select().bind(this.state.option)              // Signal<String>
```

## 全局状态

跨组件共享的状态通过 `AppState` 管理：

```cangjie
class CounterState <: AppState {
    var count = Signal<Int64>(0)
}

// 注册
App().state<CounterState>({ => CounterState() })

// 在组件中使用
button(text("+")).onClick({ ctx =>
    let st = ctx.getState<CounterState>()
    st.count.set(st.count.get() + 1)
    PatchResult.ReRender
})
```
