# 客户端组件（Client Component）

对于需要前端实时交互的组件（Tooltip、Popover、富文本编辑器、图表等），纯服务端驱动难以实现。cjxt 提供 `@ClientComponent` 宏，允许用仓颉定义组件接口，自动生成后端代理 + 前端 JS 注册。

## 定义组件

```cangjie
@ClientComponent[js: "public/js/components/my-component.js"]
class MyComponent {
    @Prop let content: String = ""
    @Prop let readOnly: Bool = false

    @Event func onChange(newContent: String): Unit {}
    @Event func onFocus(): Unit {}

    @Method func setContent(content: String): Unit {}
    @Method func undo(): Unit {}
}
```

### 语法说明

| 注解 | 位置 | 说明 |
|------|------|------|
| `@ClientComponent[js: "path"]` | 类 | `js` 参数指向前端 JS 文件路径（相对于包根目录或 `public/`） |
| `@Prop` | 字段 | 声明可从服务端传入的属性，必须有默认值 |
| `@Event` | 方法 | 声明可由前端触发的事件 |
| `@Method` | 方法 | 声明可由服务端调用的方法 |

组件定义文件使用 `@ClientComponent` 宏，需导入 `cjxt.macros.*`。编译时宏会：

1. 收集 `@Prop` / `@Event` / `@Method` 标注的信息
2. 读取 JS 文件内容，通过 `App.global().addJS()` 注册
3. 在类中生成 `public static func render(props): ClientComponentNode`

## 使用组件

```cangjie
let props = HashMap<String, String>()
props["content"] = "提示文本"
props["triggerText"] = "悬停我"
MyComponent.render(props)
```

`render()` 返回一个 `ClientComponentNode`，可作为普通 `IComponent` 放入渲染树：

```cangjie
div([
    MyComponent.render(props),
    Button("确认").kind(ButtonKind.Primary),
])
```

## 前端实现

前端 JS 使用 **IIFE + 全局注册** 模式（不支持 ES Module）：

```javascript
(function() {
    window.__CJXT_COMPONENTS__ = window.__CJXT_COMPONENTS__ || {};
    window.__CJXT_COMPONENTS__['MyComponent'] = {
        create(props, container, componentId) {
            // 创建组件 DOM，返回根元素
            const el = document.createElement('div');
            el.textContent = props.content || '';
            container.appendChild(el);
            return el;
        },
        update(props) {
            // 响应 Props 更新
        },
        methods: {
            setContent(content) {},
            undo() {},
        },
        destroy() {
            // 清理事件监听等
        },
    };
})();
```

### 生命周期

| 方法 | 时机 | 说明 |
|------|------|------|
| `create(props, container, componentId)` | 组件首次渲染 | 构建 DOM，返回根元素。`componentId` 是框架分配的实例 ID |
| `update(props)` | Props 更新时 | 根据新 props 更新 DOM |
| `methods.*` | 服务端调用时 | 通过 WS `call_method` 消息触发 |
| `destroy()` | 组件销毁时 | 清理定时器/事件监听 |

### 与后端通信

组件内通过 `window.CJXT.triggerEvent(componentId, eventName, data)` 发送事件到服务端：

```javascript
create(props, container, componentId) {
    const btn = document.createElement('button');
    btn.textContent = '提交';
    btn.addEventListener('click', () => {
        window.CJXT.triggerEvent(componentId, 'onChange', { newContent: '...' });
    });
    container.appendChild(btn);
    return container;
}
```

`componentId` 是框架自动注入的实例 ID（通过 `create` 时的 `this` 上下文）。服务端收到事件后执行注册的回调。

## 示例

### Tooltip

```cangjie
@ClientComponent[js: "../public/js/components/tooltip.js"]
class Tooltip {
    @Prop let content: String = ""
    @Prop let triggerText: String = ""
}

// 使用
let props = HashMap<String, String>()
props["content"] = "提示文本"
props["triggerText"] = "悬停我"
Tooltip.render(props)
```

### Popover

```cangjie
@ClientComponent[js: "../public/js/components/popover.js"]
class Popover {
    @Prop let content: String = ""
    @Prop let triggerText: String = ""
    @Prop let title: String = ""
}

// 使用
let props = HashMap<String, String>()
props["content"] = "这是一个弹出内容"
props["triggerText"] = "点击弹出"
props["title"] = "标题"
Popover.render(props)
```

### Popover

```cangjie
@ClientComponent[js: "../public/js/components/popover.js"]
class Popover {
    @Prop let content: String = ""
    @Prop let triggerText: String = ""
    @Prop let title: String = ""
    @Event func onShow(): Unit {}
    @Event func onHide(): Unit {}
}
```

## 注意事项

### JS 中的 `\${}` 转义

JS 文件中若含模板字符串 `${}`（如 `` `/_cjxt/js/${hash}.js` ``），需转义为 `\${}`，否则 Cangjie 的 `quote` 表达式会将其当作插值语法解析。

### 路径解析

`@ClientComponent[js: "path"]` 的路径按以下顺序查找：
1. 原始路径
2. `src/{path}`
3. `public/{path}`

建议将 JS 文件放在项目 `public/js/components/` 目录，引用时使用 `../public/js/components/xxx.js`（从 `examples/` 构建时）或直接 `public/js/components/xxx.js`（从根目录构建时）。
