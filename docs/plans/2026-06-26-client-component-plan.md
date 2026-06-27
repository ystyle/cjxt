# 客户端组件（Client Component）实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现 `@ClientComponent` 宏 + 前端运行环境 + 后端集成，使开发者能定义客户端组件并在页面中使用

**Architecture:** 参考 storm-cj 的 `@Model`+`@Id` 嵌套宏模式，`@ClientComponent` 外层宏收集 `@Prop`/`@Event`/`@Method` 内层宏的信息，生成后端代理函数 + 前端 JS 注册代码。前端 `cangjie-ui.js` 扩展 `client:xxx` 节点渲染。后端 `app.cj` 扩展 WS 协议处理 `client_event`。

**Tech Stack:** cjxt macros + embed + cangjie-ui.js + WebSocket

---

### Task 1: 内层宏 `@Prop` / `@Event` / `@Method`

**Files:**
- Create: `src/macros/client_macros.cj`

**参考实现：**
- `storm-cj/src/macros/field_macros.cj` — `@Id` 宏模式
- `storm-cj/src/macros/token_verifier.cj` — 声明类型校验

**Step 1: 实现 `@Prop` 宏**

```cangjie
macro package cjxt.macros

import std.ast.*

public macro Prop(input: Tokens): Tokens {
    let varDecl = VarDecl(input)
    let fieldName = varDecl.identifier.value
    let fieldType = varDecl.declType.toTokens().toString().trimAscii()
    setItem("prop_name", fieldName)
    setItem("prop_type", fieldType)
    input
}
```

`@Event` 解析 `FuncDecl`，`@Method` 解析 `FuncDecl`，同样用 `setItem` 发送信息。

**Step 2: 提交**

```bash
git add src/macros/client_macros.cj
git commit -m "feat(cc): 内层宏 @Prop/@Event/@Method"
```

---

### Task 2: 外层宏 `@ClientComponent`

**Files:**
- Modify: `src/macros/client_macros.cj`

**参考实现：**
- `storm-cj/src/macros/model.cj` — `@Model` 宏收集 `getChildMessages`
- `kux-cj/src/macros/crud.cj` — `@Crud` 宏收集钩子

**Step 1: 实现 `@ClientComponent` 属性宏**

处理流程：
1. 解析 `attr` 获取 `js` 路径参数
2. 解析 `input` 获取 class 名
3. 用 `getChildMessages("prop_name")` 收集字段
4. 用 `getChildMessages("event_name")` 收集事件
5. 用 `getChildMessages("method_name")` 收集方法
6. 用 `File.readFrom()` 读取 JS 文件内容
7. 生成代码：
   - `public func RichEditor(props: HashMap<String, String>): ClientComponentNode` 代理函数
   - `App.global().addJS(jsString)` 注册调用

**Step 2: 提交**

```bash
git add src/macros/client_macros.cj
git commit -m "feat(cc): @ClientComponent 外层宏"
```

---

### Task 3: ClientComponentNode VNode 类型

**Files:**
- Modify: `src/vnode.cj`
- Modify: `src/renderctx.cj` (expandTree)
- Modify: `src/action.cj` (序列化 + WS 消息类型)

**Step 1: 新增 `ClientComponentNode` 类**

```cangjie
public class ClientComponentNode <: Component {
    let _componentName: String
    let _props: HashMap<String, String>
    let _events: ArrayList<String>
    let _methods: ArrayList<String>
    let _handlers: HashMap<String, ActionHandler>
    var _componentId: String

    public init(componentName: String, props: HashMap<String, String>,
                events: ArrayList<String>, methods: ArrayList<String>)

    // 代理事件注册
    public func on(eventName: String, h: ActionHandler): ClientComponentNode

    // ID 继承 — 跨渲染保持 ID
    public func inheritId(oldId: String): ClientComponentNode

    // IComponent 接口
    public func render(): IComponent { this }

    // 序列化
    public func toJson(w: JsonWriter): Unit
}
```

**Step 2: extendTree 新增分支**

`ClientComponentNode` 作为叶子节点，不递归展开：
```cangjie
case cc: ClientComponentNode => cc
```

同时需实现 componentId 继承：
- 在 `expandTree` 中传入旧树（或从 `SessionState` 获取）
- 匹配路径找到旧节点，继承 `componentId`

**Step 3: serialize 新增分支**

```cangjie
case cc: ClientComponentNode =>
    w.startObject()
    w.writeName("type").writeValue("client:${cc._componentName}")
    w.writeName("componentId").writeValue(cc._componentId)
    w.writeName("props").writeValue(jsonString(cc._props))
    w.writeName("events").writeValue(jsonString(cc._events))
    w.writeName("methods").writeValue(jsonString(cc._methods))
    w.endObject()
```

**Step 4: WS 消息类型扩展**

在 `action.cj` 新增：
- `ClientEventMsg`（前端 → 服务端：事件上行）
- `CallMethodMsg`（服务端 → 前端：方法调用）
- `UpdatePropsMsg`（服务端 → 前端：props 更新）

**Step 5: 单元测试**

```cangjie
// vnode_test.cj
func testClientComponentSerialize(): Unit {
    let cc = ClientComponentNode("test-comp", HashMap<String, String>(), ["onChange"], ["doSomething"])
    let json = serializeComponent(cc)
    assert(json.contains("client:test-comp"))
    assert(json.contains("componentId"))
}
```

**Step 6: 提交**

```bash
git add src/vnode.cj src/renderctx.cj src/action.cj src/vnode_test.cj
git commit -m "feat(cc): ClientComponentNode + 序列化 + WS 消息"
```

---

### Task 4: 前端运行环境扩展

**Files:**
- Modify: `public/js/cangjie-ui.js`

**Step 1: WS 消息处理扩展**

在 `handleMsg` 新增分支：
```javascript
case 'call_method':
    const entry = this.clientInstances?.get(msg.componentId);
    if (entry && entry.comp.methods?.[msg.method]) {
        entry.comp.methods[msg.method](...(msg.args || []));
    }
    break;
case 'update_props':
    const entry2 = this.clientInstances?.get(msg.componentId);
    if (entry2) entry2.comp.update(msg.props);
    break;
```

**Step 2: client:xxx 渲染分支**

在 `renderTree`/`renderSubtree` 的 type 分支中新增：
```javascript
if (type.startsWith('client:')) {
    const compName = type.slice(7);
    const comp = (window.__CJXT_COMPONENTS__ || {})[compName];
    if (!comp) return null;
    const el = comp.create(node.props || {}, parentEl);
    el.__componentId = node.componentId;
    el.__compName = compName;
    if (!this.clientInstances) this.clientInstances = new Map();
    this.clientInstances.set(node.componentId, { instance: el, comp });
    return el;
}
```

**Step 3: Patch 替换时 destroy 清理**

在 `applyTreePatches` 的 `replaceChild` 之前：
```javascript
if (old.__componentId && this.clientInstances?.has(old.__componentId)) {
    const entry = this.clientInstances.get(old.__componentId);
    entry.comp.destroy?.(entry.instance);
    this.clientInstances.delete(old.__componentId);
}
```

**Step 4: CJXT 全局对象**

```javascript
window.CJXT = {
    triggerEvent(componentId, event, data) {
        this.send({ kind: 'client_event', componentId, event, data });
    },
};
```

注意：`triggerEvent` 需要能访问 `this.send`，需在 `CangjieUI` 构造时绑定。

**Step 5: 提交**

```bash
git add public/js/cangjie-ui.js
git commit -m "feat(cc): 前端运行时 client:xxx + CJXT + WS handler"
```

---

### Task 5: 后端集成

**Files:**
- Modify: `src/app.cj`

**Step 1: listenLoop 新增 client_event 处理**

```cangjie
} else if (t == "client_event") {
    let componentId = readField(raw, "componentId")
    let event = readField(raw, "event")
    let data = readField(raw, "data")
    if (componentId != "" && event != "") {
        this.dispatchClientEvent(ws, state, session, componentId, event, data)
    }
```

**Step 2: dispatchClientEvent 方法**

```cangjie
private func dispatchClientEvent(ws: WebSocket, state: SessionState, session: Session,
                                  componentId: String, event: String, data: String): Unit {
    // 在树中查找 componentId 对应的 ClientComponentNode
    // 获取注册的事件回调
    // 执行回调
    // 返回 patch
}
```

**Step 3: 提交**

```bash
git add src/app.cj
git commit -m "feat(cc): 后端 client_event 处理 + componentId 继承"
```

---

### Task 6: 示例组件 — Tooltip

**Files:**
- Create: `public/js/components/tooltip.js`
- Modify: `examples/src/showcase.cj`

**Step 1: 实现 Tooltip 前端组件**

```javascript
(function() {
    window.__CJXT_COMPONENTS__ = window.__CJXT_COMPONENTS__ || {};
    window.__CJXT_COMPONENTS__['tooltip'] = {
        create(props, container) {
            const trigger = document.createElement('span');
            trigger.textContent = props.triggerText || '?';
            trigger.className = 'el-tooltip-trigger';
            const tip = document.createElement('div');
            tip.className = 'el-tooltip__popper';
            tip.textContent = props.content || '';
            tip.style.display = 'none';
            container.appendChild(trigger);
            container.appendChild(tip);
            trigger.addEventListener('mouseenter', () => { tip.style.display = 'block'; });
            trigger.addEventListener('mouseleave', () => { tip.style.display = 'none'; });
            return container;
        },
        update(props) {},
        destroy() {},
    };
})();
```

**Step 2: 仓颉侧定义（或直接用宏定义）**

通过 `@ClientComponent` 宏：
```cangjie
@ClientComponent(js: "public/js/components/tooltip.js")
class Tooltip {
    @Prop let content: String
    @Prop let triggerText: String
}
```

**Step 3: Showcase 演示**

**Step 4: 提交**

```bash
git add public/js/components/tooltip.js examples/src/showcase.cj
git commit -m "feat(cc): Tooltip 示例组件"
```

---

### 完整构建顺序

```bash
cd /home/ystyle/Projects/Cangjie/cjxt
cjpm build     # 编译宏包
cd examples
rm -rf target/release/cjxt
eval "$(cjvs env zsh)" && eval "$(cjvs stdx env zsh)"
cjpm build
./target/release/bin/main
```
