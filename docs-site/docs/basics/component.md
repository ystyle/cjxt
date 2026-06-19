# 组件系统

组件继承 `Component` 抽象类，实现 `render()` 方法返回 UI 树。

## 基本组件

```cangjie
public class Hello <: Component {
    public func render(): IComponent {
        div(text("你好，cjxt"))
    }
}
```

## 带状态的组件

```cangjie
public class Counter <: Component {
    var count = Signal<Int64>(0)

    public func render(): IComponent {
        div([
            text("计数: ${this.count.get()}"),
            button(text("+")).onClick({ ctx =>
                this.count.update(fn: { v => v + 1 })
                PatchResult.ReRender
            }),
        ])
    }
}
```

## 生命周期

```cangjie
public func onMount(ctx: LifecycleContext): Unit {
    let st = ctx.getState<MyState>()
    this.state = st
}

public func onUnmount(ctx: LifecycleContext): Unit {
    // 页面离开时
}

public func onUpdate(ctx: LifecycleContext): Unit {
    // 每次 patch 推送后
}
```

## 页面路由注册

组件通过 `@Page` 宏注册为路由页面，详见[路由系统](/docs/basics/routing)。
