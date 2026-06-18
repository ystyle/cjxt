# 类型系统重构

## 背景

当前类型体系混乱，用户对「该用哪个类/接口」感到困惑。

### 问题

```
Component (interface)     ← 用户想要「组件」但它是个接口
BaseComponent (class)     ← 用户被迫继承的叫「基础」，语义不对
```

- Component 接口上堆满了字段默认实现（markDirty/setPath/getPath/renderWithScope）
- BaseComponent 多了一层抽象，用户不知道为什么需要它
- 自定义组件的唯一基类叫「基础组件」，而接口反而叫「组件」

### 目标

- 用户只需要知道一个类名：`Component`
- 接口名明确标记为「内部接口」，用户不需要接触
- render() 返回类型是接口（多态），基类是类（实现复用）

## 方案

```
IComponent (接口，原名 Component)   ← I 前缀 = Interface，框架内部用
  │
  ├── VNode (struct)     → 不变
  ├── TextNode (struct)  → 不变
  ├── FragmentNode (struct) → 不变
  ├── EmptyNode (struct) → 不变
  └── Component (class，原名 BaseComponent)  ← 用户只需要知道这个
        ├── Counter
        ├── Menu
        ├── Button
        ├── Input
        └── ...你的业务组件
```

### 职责分配

| 类型 | 职责 |
|------|------|
| `IComponent` | 定义契约：`render()` / `toJson()` / `markDirty()` / `renderWithScope(path)` |
| `Component` | 提供实现：`_dirty` / `_path` / `_events` / `on(ev, handler)` / `getState<>()` |
| `VNode` | HTML 元素，struct 值类型，不存储可变状态 |

### 组件 `Component` 类完整接口

```cangjie
class Component <: IComponent {
    var _dirty: Bool = false
    var _path: String = ""
    var _events = HashMap<String, ActionHandler>()

    public init() {}

    func on(ev: String, h: ActionHandler): this {
        this._events[ev] = h
        this
    }

    func getState<T>(): T where T <: AppState { ... }
    func markDirty(): Unit { ... }
    func reRender(): Unit { ... }
    func setPath(p: String): Unit { this._path = p }
    func getPath(): String { this._path }

    // 用户唯一需要覆写的方法
    abstract func render(): IComponent
}
```

### 用户代码示例

```cangjie
class Counter <: Component {
    let s = Signal<Int64>(0)

    func render(): IComponent {
        div([
            text("${s.get()}"),
            button("+").onClick({ ctx =>
                s.update({ v => v + 1 }); ReRender
            })
        ])
    }
}

class MyForm <: Component {
    func render(): IComponent {
        form([
            input().on("change", { ctx => ... }),
            button("提交").on("click", { ctx => ... })
        ]).on("submit", { ctx => ... })  // 组件级事件
    }
}
```

### 改哪些文件

核心改名：`Component` → `IComponent`，`BaseComponent` → `Component`

| 文件 | 改动 |
|------|------|
| `src/component.cj` | interface 改名 `IComponent`，class 改名 `Component` |
| `src/vnode.cj` | `VNode <: IComponent`，变量/参数类型从 `Component` 改 `IComponent` |
| `src/app.cj` | 变量/参数类型从 `Component` 改 `IComponent` |
| `src/action.cj` | `ActionHandler` 签名中的 `IComponent`，`TreePatchEntry.tree` 类型 |
| `src/signal.cj` | 无变化 |
| `src/renderctx.cj` | 变量/参数类型 `Component` → `IComponent` |
| `src/serialize.cj` | 变量/参数类型 `Component` → `IComponent` |
| `src/html.cj` | 无变化（前端 JS） |
| `src/ws.cj` | 无变化 |
| `src/session.cj` | `Session.tree` 类型 `Component` → `IComponent` |
| `src/registry.cj` | `RouterRegistry.create` 返回类型 |
| `src/diff.cj` | 已删除 |
| `src/components/*.cj` | `<: Component` → `<: IComponent`（现在是 `<: Component`，改后变成 `<: IComponent`）|

注意：`Component` 作为函数参数/变量名时，与关键字冲突的（如 match arm 中的 `case _`），不需要额外处理。

### 注意事项

- `IComponent` 接口保留所有默认方法实现（`markDirty`/`setPath`/`getPath`/`clearDirty`/`isDirty` 的空默认）
- `Component` 类覆写这些方法以提供真实字段支持
- `VNode` 等 struct 直接 `<: IComponent`，不继承 `Component`
- `render()` 返回类型改为 `IComponent`
