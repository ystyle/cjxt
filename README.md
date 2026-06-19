# cjxt

仓颉全栈服务端驱动 UI 框架

## 示例

```cangjie
import cjxt.*

class Counter <: Component {
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

main() {
    App().serve()
}
```

## 特性

- **全栈统一** — 一套仓颉代码管理路由、状态和 UI，无需前后端分离
- **零前端框架** — 前端 JS 不到 5KB，WebSocket 增量推送，无 React/Vue 依赖
- **类型安全** — Signal 泛型、组件 Props 编译期检查，仓颉类型系统贯穿全栈
- **精准重渲** — Signal 自动追踪依赖，只重渲变化的组件
- **Element Plus 设计** — 组件对齐 EP 的 Props/Events/样式，SCSS 变量直接复用
- **编译期宏** — `@Page` 路由、CSS Module 等宏编译期生成代码，零运行时开销

## 文档

[https://ystyle.top/cjxt](https://ystyle.top/cjxt)

## 仓库

- AtomGit（主站）：[https://atomgit.com/ystyle/cjxt](https://atomgit.com/ystyle/cjxt)
- GitHub：[https://github.com/ystyle/cjxt](https://github.com/ystyle/cjxt)
