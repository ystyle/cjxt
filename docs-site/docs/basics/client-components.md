# 客户端组件（Client Component）

对于需要前端实时交互的组件（Tooltip、Popover、富文本编辑器、图表等），纯服务端驱动难以实现。cjxt 提供 `@ClientComponent` 宏，允许用仓颉定义组件接口，自动生成代理类，在前端渲染 DOM。

## 定义组件

```cangjie
@ClientComponent
public class MyComponent {
    @Prop let content: String = ""
    @Prop let readOnly: String = ""
}

// 使用
MyComponent("提示文本", "false")
```

宏展开等价于：

```cangjie
public class MyComponent <: Component {
    var _props: HashMap<String, JsonSerializable> = HashMap<String, JsonSerializable>()

    public init(content: String, readOnly: String) {
        _props["content"] = content
        _props["readOnly"] = readOnly
    }

    public func render(): IComponent {
        ClientComponentNode("MyComponent", this._props)
    }
}
```

`render()` 返回一个 `ClientComponentNode`，可作为普通 `IComponent` 放入渲染树。事件通过 `.on()` 链式注册，与 VNode 的 handler ID 体系一致：

```cangjie
Tooltip("提示文本", "悬停我")
    .on("onShow", { ctx => PatchResult.Noop })
```

### 语法说明

| 注解 | 位置 | 说明 |
|------|------|------|
| `@ClientComponent` | 类 | 标记为客户端组件，生成 `Component` 子类 |
| `@Prop` | 字段 | 声明构造器参数，自动填入 `_props`。类型可为 `String` / `Int64` / `Bool` / `Float64`，或任何实现 `JsonSerializable` 的类型 |

Props 类型不限于 `String`。`Int64` → JSON number，`Bool` → JSON true/false，`Float64` → JSON float。自定义类型实现 `JsonSerializable` 后也可作为 prop：

```cangjie
@ClientComponent
public class Counter {
    @Prop let value: Int64 = 0
    @Prop let label: String = ""
}

// 使用
Counter(42, "计数")
```

### Props 传入 Signal

@Prop 构造器参数类型可以是 `String`、`Int64`、`Bool`、`Float64` 等，不是 Signal。若需要在父组件重渲染时传入动态值：

```cangjie
Tooltip(contentSignal.get(), triggerSignal.get())
```

Signal 变化驱动父组件重新 `render()`，新建子组件实例时传新值。如需在组件外部持久化状态，由调用方在父组件或 Store 中管理 Signal。

## 前端实现

前端 JS 使用 **IIFE + Class 全局注册**（不支持 ES Module）：

```javascript
(function() {
    const { registerComponent } = window.CJXT || {};
    registerComponent('MyComponent', class {
        create(props, container) {
            const el = document.createElement('div');
            el.textContent = props.content || '';
            container.appendChild(el);
            return el;
        }
        update(props) {}
        destroy(el) {}
    });
})();
```

### 生命周期

| 方法 | 时机 | 说明 |
|------|------|------|
| `create(props, container)` | 组件首次渲染 | 构建 DOM，返回根元素 |
| `update(props)` | Props 更新时 | 根据新 props 更新 DOM |
| `destroy(el)` | 组件销毁时 | 清理定时器/事件监听 |

组件 JS 文件统一通过 `App.UseComponent()` 嵌入到页面（`@EmbedString` 编译时嵌入），不通过宏注册。

### 与后端通信

客户端组件通过 **标准 Action 机制**与后端通信。`ClientComponentNode.on()` 使用 `nextHid()` 生成 handler ID（对齐 `VNode.on()`），`toJson` 输出 `actions` 映射：

```cangjie
Tooltip("提示", "悬停我")
    .on("onShow", { ctx => PatchResult.Noop })
    .on("onHide", { ctx => PatchResult.Noop })
```

渲染后 DOM 上会有 `data-action-onShow="_h1"`，事件通过 `type: "action"` 消息派发到后端 `state.handlers`。

前端 JS 中不需要手动调用 `CJXT.triggerEvent`。事件通过标准 DOM 事件冒泡 + 框架 `attachClickDelegate` 自动捕获。

## 示例

### Tooltip

```cangjie
@ClientComponent
public class Tooltip {
    @Prop let content: String = ""
    @Prop let triggerText: String = ""
}

// 使用
Tooltip("提示文本", "悬停我")
```

### Popover

```cangjie
@ClientComponent
public class Popover {
    @Prop let content: String = ""
    @Prop let triggerText: String = ""
    @Prop let title: String = ""
}

// 使用
Popover("这是一个弹出内容", "点击弹出", "标题")
```

## 前端组件注册

客户端组件 JS 注册在 `UseComponent()` 中统一处理，宏不参与 JS 注册：

```cangjie
// src/app.cj — UseComponent()
public func UseComponent(): App {
    this.addCSS(_componentCSS)
    this.addJS(_frontendJS)
    this.addJS(_tooltipJS)
    this.addJS(_popoverJS)
    this
}
```

所有组件 JS 文件放在 `public/js/components/` 目录下，通过 `@EmbedString` 编译时嵌入。

## 注意事项

### JS 注册为 Class

前端组件使用 `class` 注册而非字面量对象，这样 `destroy()` 可访问类作用域内的引用（如事件监听器函数引用），正确处理清理：

```javascript
CJXT.registerComponent('MyComponent', class {
    create(props, container) {
        this._handler = () => { /* ... */ };
        document.addEventListener('click', this._handler);
        return container;
    }
    destroy(el) {
        document.removeEventListener('click', this._handler);
    }
});
```

### 构建时同步 JS 文件

`@EmbedString` 按包根目录解析路径（通过编译器 `-p` 参数定位），编译时自动找到 `public/js/components/` 下的文件，无需手动同步到 `examples/`。
