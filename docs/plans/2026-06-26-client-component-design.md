# 客户端组件（Client Component）设计

## 概述

在服务端驱动 UI 架构中，某些需要前端实时交互的组件（富文本编辑器、图表、Tooltip/Popover 等）无法纯服务端实现。客户端组件机制允许在保持服务端控制权的前提下，安全地集成前端实现。

## 核心设计：一份仓颉定义，双端生成

开发者只需在仓颉中定义一次组件接口，`@ClientComponent` 宏自动生成后端代理函数 + 前端 JS 注册。

## 嵌套宏模式验证

参考项目中已验证的同类模式：

**storm-cj `@Model` + `@Id`（同宏包）：**
```cangjie
@Model
class User {
    @Id var id: Int64
    @Index var name: String
}
```
- 内层宏 `@Id`：`setItem("Id", fieldName)`，返回原输入
- 外层宏 `@Model`：`getChildMessages("Id")` → `messages[0].getString("Id")`

**kux-cj `@Crud` + `@BeforeCreate`（跨宏包）：**
```cangjie
@Crud[Todo, "/api/todos"]
class TodoService {
    @BeforeCreate
    func myHook(todo: Todo): Unit {}
}
```
- 内层宏 `@BeforeCreate`：`assertParentContext("Crud")` + `setItem("funcName", fnName)`
- 外层宏 `@Crud`：`getChildMessages("BeforeCreate")` 遍历接收

两个项目证明了 `setItem`/`getChildMessages` 在嵌套属性宏中工作正常，展开顺序为**内层先展开**。设计可行。

## 工作原理

```cangjie
@ClientComponent(js: "./web/components/editor.js")
class RichEditor {
    @Prop let content: String
    @Prop let readOnly: Bool = false

    @Event func onChange(newContent: String) -> Void

    @Method func setContent(content: String) -> Void
    @Method func undo() -> Void
}
```

编译时 `@ClientComponent` 宏展开：

1. **收集信息**：内层 `@Prop` / `@Event` / `@Method` 宏通过 `setItem` 向外层发送信息
2. **前端 JS 注册**：宏内用 `File.readFrom()` 读取 JS 文件，以字符串字面量形式生成 `App.addJS(jsString)` 调用
3. **生成后端代理函数**：`RichEditor(props)` → 生成 `ClientComponentNode`
4. **组件清单注册**：组件名 → JS blob hash 的映射

## 后端运行时

### VNode 扩展

新增 `ClientComponentNode` 类型实现 `IComponent` + `JsonSerializable`：

```cangjie
public class ClientComponentNode <: Component {
    let _componentName: String       // "rich-editor"
    let _props: HashMap<String, String>
    let _events: ArrayList<String>
    let _methods: ArrayList<String>
    let _eventHandlers: HashMap<String, ActionHandler>
    var _componentId: String

    // componentId 继承方法 — 跨 render 保持 ID 不变
    public func inheritId(oldId: String): ClientComponentNode { ... }
}
```

序列化为 JSON：

```json
{
    "type": "client:rich-editor",
    "componentId": "uuid-xxx",
    "props": { "content": "Hello", "readOnly": false },
    "events": ["onChange"],
    "methods": ["setContent", "undo"]
}
```

### componentId 跨渲染继承

每次 `render()` 生成新的 `ClientComponentNode`，新的 `componentId`。`expandTree` 时需继承旧树中的 ID：

```
expandTree 中遇到 ClientComponentNode:
  1. 用当前节点路径在旧树中查找对应旧节点
  2. 如果旧节点是 ClientComponentNode，继承其 componentId
  3. 否则生成新的 UUID
```

需在 `RenderContext` 或 `expandTree` 中访问旧树，在会话重建时。

### expandTree / serialize 扩展

- `expandTree`：`ClientComponentNode` 作为叶子节点，不递归展开
- `serializeNode`：新增 `case cc: ClientComponentNode =>` 处理分支

### WS 协议扩展（统一使用 `kind` 字段）

前端 → 服务端（事件上行）：

```json
{ "kind": "client_event", "componentId": "uuid-xxx", "event": "onChange", "data": { "newContent": "..." } }
```

服务端 → 前端（方法调用）：

```json
{ "kind": "call_method", "componentId": "uuid-xxx", "method": "undo", "args": [] }
```

服务端 → 前端（Props 更新）：

```json
{ "kind": "update_props", "componentId": "uuid-xxx", "props": { "content": "..." } }
```

### app.cj listenLoop 扩展

在 `listenLoop` 中新增 `client_event` 消息处理分支：
- 根据 componentId 找到组件实例
- 根据 event 名找到注册的回调
- 执行回调，返回 patch 或调用方法

### client_event 事件回调注册

`ClientComponentNode` 支持 `.on(eventName, callback)` 链式方法：

```cangjie
@ClientComponent(js: "./editor.js")
class RichEditor {
    @Event func onChange(newContent: String) -> Void
}
```
生成：
```cangjie
public func RichEditor(props: HashMap<String, String>): ClientComponentNode {
    ClientComponentNode("rich-editor", props, ["onChange"], ["setContent", "undo"])
}

// 用户使用时：
RichEditor(content: "Hello")
    .on("onChange", { ctx => ... })
```

## 前端运行时

### 前端组件注册方式

JS 通过 `<script src>` 加载（非 ES Module），使用 IIFE + 全局注册：

```javascript
// web/components/editor.js
(function() {
    const name = 'rich-editor';
    window.__CJXT_COMPONENTS__ = window.__CJXT_COMPONENTS__ || {};
    window.__CJXT_COMPONENTS__[name] = {
        create(props, container) {
            const el = document.createElement('div');
            container.appendChild(el);
            return el;
        },
        update(props) {},
        methods: {
            setContent(content) {},
            undo() {},
        },
        destroy() {},
    };
})();
```

### cangjie-ui.js 扩展

1. **组件注册表**：服务端通过 `addJS()` 注册的 JS blob → `window.__CJXT_COMPONENTS__`

2. **`client:xxx` 节点渲染**：`renderTree`/`renderSubtree` 新增：
   ```javascript
   if (type.startsWith('client:')) {
       const compName = type.slice(7);
       const comp = (window.__CJXT_COMPONENTS__ || {})[compName];
       if (!comp) return;
       const instance = comp.create(node.props || {}, parentEl);
       instance.__componentId = node.componentId;
       instance.__compName = compName;
       this.clientInstances = this.clientInstances || new Map();
       this.clientInstances.set(node.componentId, { instance, comp });
   }
   ```

3. **Patch 替换处理**：替换节点时检查旧节点是否为 client 组件，调用 `destroy()`：
   ```javascript
   if (old.__componentId && this.clientInstances?.has(old.__componentId)) {
       const entry = this.clientInstances.get(old.__componentId);
       entry.comp.destroy?.(entry.instance);
       this.clientInstances.delete(old.__componentId);
   }
   ```

4. **WS 消息处理**：`handleMsg` 新增 `call_method` / `update_props` 分支

5. **CJXT 全局工具**：
   ```javascript
   window.CJXT = {
       triggerEvent(componentId, event, data) {
           // 通过 WS 发送 client_event
       },
   };
   ```

### 事件上行流程

```
组件内调用 CJXT.triggerEvent(id, 'onChange', { newContent: '...' })
  → WS 发送 { kind: "client_event", componentId, event: "onChange", data }
  → 服务端 listenLoop 收到，查找组件实例和回调
  → 执行回调 → 返回 patch → WS 推回前端
```

## 实现步骤

1. **宏实现** (`src/macros/client_component.cj`)：
   - `@Prop` / `@Event` / `@Method` 内层宏（嵌套宏，用 setItem 传数据，同 storm-cj `@Id` 模式）
   - `@ClientComponent` 外层属性宏（解析 attr 中的 js 路径，收集内层数据，生成代理函数 + JS 注册）

2. **VNode 扩展** (`src/vnode.cj`)：
   - 新增 `ClientComponentNode` 类
   - `expandTree` 新增 `client:` 分支
   - `serializeNode` 新增序列化

3. **前端运行环境** (`cangjie-ui.js`)：
   - `__CJXT_COMPONENTS__` 注册表
   - `client:xxx` 渲染分支
   - `call_method` / `update_props` WS 消息处理
   - patch 替换时 destroy 清理

4. **后端集成** (`app.cj`)：
   - `client_event` 消息处理
   - componentId 跨渲染继承

5. **WS 协议扩展** (`action.cj`)：
   - 新增 `ClientEventMsg` / `CallMethodMsg` / `UpdatePropsMsg` 结构体

6. **示例组件**（Tooltip/Popover 作为第一个客户端组件）

## 与 Issue #3 的差异

| Issue #3 设计 | 实际实现 |
|--------------|---------|
| 动态 `import(jsUrl)` 加载 | `@EmbedString` 编译时嵌入 + `addJS()` 注册 |
| 独立 `components.json` 清单 | 宏展开时直接生成注册代码 |
| 需要独立构建步骤 | 一次 `cjpm build` 完成 |
| ES Module `export default` | IIFE + `window.__CJXT_COMPONENTS__` |
| `"type"` 字段 | 统一使用 `"kind"` 字段 |
