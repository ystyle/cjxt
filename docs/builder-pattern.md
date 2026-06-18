# Builder DSL 模式（仿 ArkUI 尾随闭包）

ArkUI 使用 `Column { Text("a"); Button("b") }` 的 builder 模式构建 UI
树。子组件不通过返回值组合，而是在构造函数中通过线程/协程局部变量注册到"当前
父节点"。

## 核心机制

```cangjie
// 父栈（作用域栈）
let _parentStack = ArrayList<ChildCollector>()
```

容器组件执行 builder 前 push 自己的 collector，builder 内子组件的构造函数
自动向栈顶 collector 注册自身，builder 结束后 pop。

## 关键约束

- 渲染是串行的（`execMutex` 保证），所以全局变量安全
- builder 内不允许异步操作或跨协程执行
- 子组件构造函数必须先于 render() 执行（构造时注册）

## 示例实现

```cangjie
let _parentStack = ArrayList<ChildCollector>()

public class ChildCollector {
    var _children: ArrayList<Component> = ArrayList<Component>()
    public func add(c: Component): Unit { _children.add(c) }
    public func toArray(): Array<Component> { _children.toArray() }
}

public class Column <: Component {
    var _builder: () -> Unit

    public init(builder!: () -> Unit = {=>}) {
        this._builder = builder
    }

    public func render(): Component {
        let collector = ChildCollector()
        _parentStack.add(collector)
        this._builder()
        _parentStack.remove(_parentStack.size - 1.._parentStack.size)
        div(collector.toArray())
    }
}

public class CText <: Component {
    var _text: String

    public init(text: String) {
        this._text = text
        if (_parentStack.size > 0) {
            _parentStack[_parentStack.size - 1].add(this)
        }
    }

    public func render(): Component { span([text(this._text)]) }
}
```

调用：

```cangjie
Column {
    CText("hello")
    CText("world")
}
```

## 如需多线程安全

改用 `std.core.ThreadLocal<T>` 做线程局部父栈：

```cangjie
import std.core.ThreadLocal

let _parentStack = ThreadLocal<ArrayList<ChildCollector>>()

func getStack(): ArrayList<ChildCollector> {
    match (_parentStack.get()) {
        case Some(s) => s
        case None => {
            let s = ArrayList<ChildCollector>()
            _parentStack.set(s)
            s
        }
    }
}
```

## 与现有 children 模式的关系

| 模式 | 优点 | 缺点 |
|------|------|------|
| `children: Array<Component>` | 纯函数，无副作用 | 调用时 `[Child(...), ...]` 语法冗余 |
| Builder `() -> Unit` | DSL 简洁，`{ }` 尾随闭包 | 依赖全局状态，render 耦合构造 |

两者可以并存：内部用 collector 收集，对外暴露 `children` 参数作为 fallback。
