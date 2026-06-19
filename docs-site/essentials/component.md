# 组件系统

## IComponent 接口

所有组件实现 `IComponent` 接口：

```cangjie
public interface IComponent <: JsonSerializable {
    func render(): IComponent                             // 渲染（必须实现）
    func getComponentKey(): String                        // 组件 key
    func markDirty(): Unit                                // 标记脏
    func isDirty(): Bool                                  // 是否脏
    func clearDirty(): Unit                               // 清理脏标记
    func getPath(): String                                // 获取路径
    func setPath(p: String): Unit                         // 设置路径
    func reRender(): Unit                                 // 强制重渲
    func renderWithScope(path: String): IComponent        // 带 scope 的渲染
    func renderWithScope(): IComponent
    func getActions(): HashMap<String, ActionHandler>     // 获取 action handler
    func onMount(ctx: LifecycleContext): Unit             // 挂载
    func onUpdate(ctx: LifecycleContext): Unit            // 更新
    func onUnmount(ctx: LifecycleContext): Unit            // 卸载
    func onError(ctx: ErrorContext): Unit                 // 错误
    func toJson(w: JsonWriter): Unit                      // 序列化
    func collectHandlers(out: HashMap<String, ActionHandler>): Unit
}
```

## Component 抽象类

继承 `Component` 实现组件：

```cangjie
public abstract class Component <: IComponent {
    var _dirty: Bool = false
    var _path: String = ""
    var _events = HashMap<String, ActionHandler>()

    public func on(ev: String, h: ActionHandler): Component  // 注册事件回调
    public func markDirty(): Unit
    public func isDirty(): Bool
    public func clearDirty(): Unit
    public func getPath(): String
    public func setPath(p: String): Unit
}
```

## 编写组件

```cangjie
public class Counter <: Component {
    var count = Signal<Int64>(0)

    public func render(): IComponent {
        div([
            text("计数: ${this.count.get()}"),
            Button("+1").onClick({ ctx =>
                this.count.update(fn: { v => v + 1 })
                PatchResult.ReRender
            }),
        ])
    }
}
```

## 生命周期

| 钩子 | 触发时机 |
|------|----------|
| `onMount` | 页面首次渲染或 `applyNav` 后 |
| `onUnmount` | 页面离开时 |
| `onUpdate` | 前端 ack update 时 |
| `onError` | Action/Bind handler 抛出异常时 |

```cangjie
public func onMount(ctx: LifecycleContext): Unit {
    let st = ctx.getState<MyState>()   // 获取共享状态
    this.state = st
}
```

### LifecycleContext

```cangjie
public struct LifecycleContext {
    let sessionId: String
    let routeParams: HashMap<String, String>
    let componentKey: Option<String>
    let triggerAction: Option<String>
    let states: HashMap<String, AppState>

    func getState<T>(): T where T <: AppState  // 通过类型名取 AppState
}
```

### ErrorContext

```cangjie
public struct ErrorContext {
    let sessionId: String
    let actionName: String
    let error: Error
}
```
