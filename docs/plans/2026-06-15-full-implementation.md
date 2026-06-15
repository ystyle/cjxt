# cjxt 全量实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 实现完整的仓颉服务端驱动 UI 框架，覆盖路由、组件、生命周期、diff/patch、WS 通信、样式系统、状态管理全链路。

**架构:** HTTP 首屏 + WS 交互双通道，`@Page` 宏编译时注册路由，`Component` interface 统一组件抽象，后端 diff + JSON Patch 增量更新，`var` 字段 + `ReRender` 作为基础状态管理。

**技术栈:** 仓颉语言 + `fountain`/`net.http` + WebSocket + 原生 JS 前端渲染器

---

### Task 1: 核心数据模型 —— ComponentNode

**Files:**
- Create: `src/core/vnode.cj`

**实现:**

```cangjie
package cjxt.core

public enum ComponentType {
    | Div
    | Span
    | Button
    | Input
    | Form
    | Table
    | Text
    | Image
    | H1
    | H2
    | P
    | Select
    | Textarea
    | A
    | Ul
    | Li
}

public type Attributes = Dictionary<String, String>
public type ActionMap = Dictionary<String, String>

public struct ComponentNode {
    let typ: ComponentType
    let attrs: Attributes
    let children: Array<ComponentNode>
    let key: String?
    let actions: ActionMap
}

// 辅助构造器
public func div(children: Array<ComponentNode> = [], attrs: Attributes = [:], actions: ActionMap = [:], key: String? = None): ComponentNode {
    ComponentNode(typ: ComponentType.Div, attrs: attrs, children: children, actions: actions, key: key)
}

public func span(children: Array<ComponentNode> = [], attrs: Attributes = [:], actions: ActionMap = [:], key: String? = None): ComponentNode {
    ComponentNode(typ: ComponentType.Span, attrs: attrs, children: children, actions: actions, key: key)
}

public func button(children: Array<ComponentNode> = [], attrs: Attributes = [:], actions: ActionMap = [:], key: String? = None): ComponentNode {
    ComponentNode(typ: ComponentType.Button, attrs: attrs, children: children, actions: actions, key: key)
}

public func text(content: String): ComponentNode {
    ComponentNode(typ: ComponentType.Text, attrs: ["text": content], children: [], key: None, actions: [:])
}

public func h1(children: Array<ComponentNode> = [], attrs: Attributes = [:], actions: ActionMap = [:], key: String? = None): ComponentNode {
    ComponentNode(typ: ComponentType.H1, attrs: attrs, children: children, actions: actions, key: key)
}

public func input(attrs: Attributes = [:], actions: ActionMap = [:], key: String? = None): ComponentNode {
    ComponentNode(typ: ComponentType.Input, attrs: attrs, children: [], actions: actions, key: key)
}

public func form(children: Array<ComponentNode> = [], attrs: Attributes = [:], actions: ActionMap = [:], key: String? = None): ComponentNode {
    ComponentNode(typ: ComponentType.Form, attrs: attrs, children: children, actions: actions, key: key)
}

public func image(attrs: Attributes = [:], key: String? = None): ComponentNode {
    ComponentNode(typ: ComponentType.Image, attrs: attrs, children: [], actions: [:], key: key)
}
```

**测试:** `src/vnode_test.cj`
```cangjie
package cjxt

import cjxt.core.*
import std.testing.*

class TestVnode {
    func testCreateDiv(): Unit {
        let node = div(children: [
            h1(children: [text("hello")])
        ])
        assertEqual(node.typ, ComponentType.Div)
        assertEqual(node.children[0].typ, ComponentType.H1)
    }

    func testTextNode(): Unit {
        let node = text("hello world")
        assertEqual(node.attrs["text"], "hello world")
    }

    func testButtonWithAction(): Unit {
        let node = button(attrs: ["class": "btn"], actions: ["click": "submit"])
        assertEqual(node.attrs["class"], "btn")
        assertEqual(node.actions["click"], "submit")
    }
}
```

---

### Task 2: Component 接口 + Action 上下文

**Files:**
- Create: `src/core/component.cj`
- Create: `src/core/action.cj`

**src/core/component.cj:**

```cangjie
package cjxt.core

public interface Component {
    func render(): ComponentNode

    func onMount(ctx: LifecycleContext): Unit {}

    func onUpdate(ctx: LifecycleContext): Unit {}

    func onUnmount(ctx: LifecycleContext): Unit {}

    func onError(ctx: ErrorContext): Unit {}
}

public struct LifecycleContext {
    let sessionId: String
    let routeParams: Dictionary<String, String>
    let componentKey: String?
    let triggerAction: String?

    public func new(sessionId: String, routeParams: Dictionary<String, String> = [:], componentKey: String? = None, triggerAction: String? = None) {
        this.sessionId = sessionId
        this.routeParams = routeParams
        this.componentKey = componentKey
        this.triggerAction = triggerAction
    }
}

public struct ErrorContext {
    let sessionId: String
    let actionName: String
    let error: Error

    public func new(sessionId: String, actionName: String, error: Error) {
        this.sessionId = sessionId
        this.actionName = actionName
        this.error = error
    }
}
```

**src/core/action.cj:**

```cangjie
package cjxt.core

public enum PatchResult {
    | ReRender
    | Patch(patches: Array<Patch>)
}

public struct Patch {
    let op: String       // "add" | "remove" | "replace" | "move"
    let path: String     // JSON Pointer
    let value: Json?
    let from: String?

    public func new(op: String, path: String, value: Json? = None, from: String? = None) {
        this.op = op
        this.path = path
        this.value = value
        this.from = from
    }
}

public struct ActionContext {
    let sessionId: String
    let params: Dictionary<String, Json>
    let router: Router

    public func new(sessionId: String, params: Dictionary<String, Json>, router: Router) {
        this.sessionId = sessionId
        this.params = params
        this.router = router
    }
}

public struct Router {
    let sessionId: String
    let navigateFn: (String) -> Unit

    public func new(sessionId: String, navigateFn: (String) -> Unit) {
        this.sessionId = sessionId
        this.navigateFn = navigateFn
    }

    public func push(path: String): Unit {
        this.navigateFn(path)
    }
}
```

**测试:** `src/action_test.cj`
```cangjie
package cjxt

import cjxt.core.*
import std.testing.*

class TestAction {
    func testPatchResult(): Unit {
        let p = PatchResult.ReRender
        assertTrue(match(p) { case ReRender => true; case _ => false })
    }

    func testPatchCreate(): Unit {
        let p = Patch(op: "replace", path: "/children/0", value: Json("hello"))
        assertEqual(p.op, "replace")
        assertEqual(p.path, "/children/0")
    }

    func testRouterPush(): Unit {
        var called = ""
        let router = Router(sessionId: "s1", navigateFn: { path => called = path })
        router.push("/order/list")
        assertEqual(called, "/order/list")
    }
}
```

---

### Task 3: WS 协议 + Session 管理器

**Files:**
- Create: `src/ws/protocol.cj`
- Create: `src/session/manager.cj`

**src/ws/protocol.cj:**

```cangjie
package cjxt.ws

public enum WsMessageType {
    | Connect
    | Connected
    | Action
    | Patch
    | Push
    | FullTree
    | Navigate
    | Ack
    | Ping
    | Pong
    | Disconnect
}

// 消息体（反）序列化由外部解析层负责
public struct WsMessage {
    let type: WsMessageType
    let sessionId: String
    let name: String?            // action name
    let params: Json?            // action / navigation params
    let patches: Json?           // patch / push data
    let tree: Json?              // fullTree 时携带完整 ComponentNode 树
    let path: String?            // navigate path
    let event: String?           // ack event name
}

// WS 连接状态
public enum WsState {
    | Connecting
    | Connected
    | Disconnected
}
```

**src/session/manager.cj:**

```cangjie
package cjxt.session

import cjxt.core.*
import cjxt.ws.*
import std.collection.*
import std.time.*

public struct Session {
    let id: String
    var page: Component
    var tree: ComponentNode
    var wsState: WsState
    var createdAt: Instant
    var lastActiveAt: Instant

    public func new(id: String, page: Component, tree: ComponentNode) {
        this.id = id
        this.page = page
        this.tree = tree
        this.wsState = WsState.Connecting
        this.createdAt = Instant.now()
        this.lastActiveAt = Instant.now()
    }

    public func touch(): Unit {
        this.lastActiveAt = Instant.now()
    }

    public func updatePage(page: Component, tree: ComponentNode): Unit {
        this.page = page
        this.tree = tree
        this.touch()
    }

    public func isExpired(ttl: Duration): Bool {
        Instant.now() - this.lastActiveAt > ttl
    }
}

public class SessionManager {
    private let sessions = ConcurrentHashMap<String, Session>()
    private let ttl: Duration

    public func new(ttl: Duration = Duration.ofMinutes(30)) {
        this.ttl = ttl
    }

    public func create(page: Component, tree: ComponentNode): Session {
        let id = generateSessionId()
        let session = Session(id: id, page: page, tree: tree)
        sessions.put(id, session)
        return session
    }

    public func get(id: String): Session? {
        let s = sessions.get(id)
        if (s != None) {
            s.get().touch()
        }
        return s
    }

    public func remove(id: String): Unit {
        sessions.remove(id)
    }

    public func cleanup(): Unit {
        let expired = ArrayList<String>()
        for (id, session) in sessions.entrySet() {
            if (session.isExpired(ttl)) {
                expired.add(id)
            }
        }
        for (id in expired) {
            sessions.remove(id)
        }
    }

    private func generateSessionId(): String {
        // 简化实现：时间戳 + 随机数
        "${Instant.now().toEpochMilli()}-${Random().nextInt64().toString()}"
    }
}
```

---

### Task 4: Diff 引擎

**Files:**
- Create: `src/diff/engine.cj`

```cangjie
package cjxt.diff

import cjxt.core.*
import std.encoding.JSON

public func diff(old: ComponentNode, new: ComponentNode, basePath: String = ""): Array<Patch> {
    var patches = ArrayList<Patch>()

    // 类型或 key 不同 → 整节点替换
    if (old.typ != new.typ || old.key != new.key) {
        patches.add(Patch(
            op: "replace",
            path: basePath,
            value: serialize(new)
        ))
        return patches.toArray()
    }

    // 对比属性
    let allKeys = mergeKeys(old.attrs, new.attrs)
    for (key in allKeys) {
        let oldVal = old.attrs.get(key)
        let newVal = new.attrs.get(key)
        if (oldVal != newVal) {
            let attrPath = if (basePath == "") "/attrs/${key}" else "${basePath}/attrs/${key}"
            patches.add(Patch(
                op: if (oldVal == None) "add" else "replace",
                path: attrPath,
                value: Json(newVal.getOr(""))
            ))
        }
    }

    // 对比 actions
    let allActions = mergeKeys(old.actions, new.actions)
    for (key in allActions) {
        let oldAct = old.actions.get(key)
        let newAct = new.actions.get(key)
        if (oldAct != newAct) {
            let actPath = if (basePath == "") "/actions/${key}" else "${basePath}/actions/${key}"
            if (newAct == None) {
                patches.add(Patch(op: "remove", path: actPath))
            } else {
                patches.add(Patch(op: "replace", path: actPath, value: Json(newAct.getOr(""))))
            }
        }
    }

    // 对比 children（基于索引，如有 key 则优先匹配 key）
    let maxLen = if (old.children.size > new.children.size) old.children.size else new.children.size
    for (i in 0..maxLen) {
        let childPath = if (basePath == "") "/children/${i}" else "${basePath}/children/${i}"
        if (i >= old.children.size) {
            // 新增子节点
            patches.add(Patch(op: "add", path: childPath, value: serialize(new.children[i])))
        } else if (i >= new.children.size) {
            // 删除子节点
            patches.add(Patch(op: "remove", path: childPath))
        } else {
            let sub = diff(old.children[i], new.children[i], childPath)
            for (p in sub) { patches.add(p) }
        }
    }

    patches.toArray()
}

private func mergeKeys(a: Dictionary<String, String>, b: Dictionary<String, String>): Array<String> {
    let keys = HashSet<String>()
    for (k in a.keys()) { keys.add(k) }
    for (k in b.keys()) { keys.add(k) }
    keys.toArray()
}

private func serialize(node: ComponentNode): Json {
    // 简化的序列化：实际应递归序列化整棵树
    Json(JSON.encode(node))
}
```

---

### Task 5: @Page 宏 + 路由注册表

**Files:**
- Create: `src/router/page_macro.cj` (macro package)
- Create: `src/router/registry.cj`

宏定义文件需要 `macro package` 声明，包名 `cjxt.router.macros`，放在 `src/router/` 下。

**src/router/page_macro.cj:**

```cangjie
package cjxt.router.macros

import std.ast.*

// 简化标记宏：用于编译时收集路由信息
public macro Page(route: String): ClassDecorator {
    // 展开为：在类的静态初始化中注册路由
    // 实际实现依赖仓颉宏 API
    quote {
        // 编译时调用 Registry.register(path, ClassType)
    }
}
```

**src/router/registry.cj:**

```cangjie
package cjxt.router

import cjxt.core.*
import std.collection.*

public struct RouteEntry {
    let path: String
    let pageType: MetaType
    let paramNames: Array<String>  // 从路径中提取的动态参数名

    public func new(path: String, pageType: MetaType) {
        this.path = path
        this.pageType = pageType
        this.paramNames = extractParamNames(path)
    }

    public func match(requestPath: String): Dictionary<String, String>? {
        // 简单匹配：先精确匹配，再尝试动态匹配
        if (path == requestPath) {
            return [:]
        }
        let parts = requestPath.split("/")
        let pattern = path.split("/")
        if (parts.size != pattern.size) {
            return None
        }
        var params = Dictionary<String, String>()
        for (i in 0..parts.size) {
            if (pattern[i].startsWith("[") && pattern[i].endsWith("]")) {
                let name = pattern[i].substring(1, pattern[i].size - 1)
                params.put(name, parts[i])
            } else if (pattern[i] != parts[i]) {
                return None
            }
        }
        params
    }

    private func extractParamNames(path: String): Array<String> {
        var names = ArrayList<String>()
        for (segment in path.split("/")) {
            if (segment.startsWith("[") && segment.endsWith("]")) {
                names.add(segment.substring(1, segment.size - 1))
            }
        }
        names.toArray()
    }
}

public class RouteRegistry {
    private let routes = ArrayList<RouteEntry>()

    public func new() {}

    public func register(path: String, pageType: MetaType): Unit {
        routes.add(RouteEntry(path: path, pageType: pageType))
    }

    public func match(path: String): (RouteEntry, Dictionary<String, String>)? {
        for (entry in routes) {
            let params = entry.match(path)
            if (params != None) {
                return (entry, params.getOr([:]))
            }
        }
        None
    }
}
```

---

### Task 6: HTML 壳生成 + 前端渲染器

**Files:**
- Create: `src/render/html.cj`
- Create: `src/render/frontend.js`

**src/render/html.cj:**

```cangjie
package cjxt.render

import cjxt.core.*
import std.encoding.JSON

public func generateHtmlShell(sessionId: String, tree: ComponentNode): String {
    let treeJson = JSON.encode(tree)
    """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>cjxt</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    </style>
</head>
<body>
    <div id="app"></div>
    <script>
        var __SESSION_ID__ = "${sessionId}";
        var __INITIAL_TREE__ = ${treeJson};
    </script>
    <script>
${FRONTEND_JS}
    </script>
</body>
</html>
"""
}
```

**src/render/frontend.js:**

内联在 html.cj 中的 JS 字符串常量。核心渲染器约 3KB。

**核心逻辑：**

```javascript
class CangjieUI {
    constructor(container, sessionId) {
        this.container = container;
        this.sessionId = sessionId;
        this.tree = null;
        this.ws = null;
        this.reconnectTimer = null;
    }

    init(tree) {
        this.tree = tree;
        this.renderTree(tree, this.container);
        this.connectWS();
    }

    connectWS() {
        const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
        this.ws = new WebSocket(`${proto}//${location.host}/_ws`);
        this.ws.onopen = () => {
            this.send({ type: "connect", sessionId: this.sessionId });
        };
        this.ws.onmessage = (e) => {
            const msg = JSON.parse(e.data);
            switch (msg.type) {
                case "connected": this.ack("mount"); break;
                case "patch":     this.applyPatches(msg.patches); this.ack("update"); break;
                case "push":      this.applyPatches(msg.patches); break;
                case "fullTree":  this.loadNewPage(msg); break;
                case "pong":      break;
            }
        };
        this.ws.onclose = () => this.scheduleReconnect();
    }

    ack(event) {
        this.send({ type: "ack", event, sessionId: this.sessionId });
    }

    send(data) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(data));
        }
    }

    scheduleReconnect() {
        this.reconnectTimer = setTimeout(() => this.connectWS(), 3000);
    }

    loadNewPage(msg) {
        this.tree = msg.tree;
        this.container.innerHTML = '';
        this.renderTree(msg.tree, this.container);
        this.ack("mount");
    }

    renderTree(node, parentEl) {
        const el = document.createElement(node.type.toLowerCase());
        for (const [k, v] of Object.entries(node.attrs || {})) {
            if (k === 'text') { el.textContent = v; continue; }
            el.setAttribute(k, v);
        }
        for (const [event, actionName] of Object.entries(node.actions || {})) {
            el.addEventListener(event, (e) => {
                const params = this.extractParams(el, e);
                this.send({ type: "action", name: actionName, params, sessionId: this.sessionId });
            });
        }
        for (const child of (node.children || [])) {
            this.renderTree(child, el);
        }
        parentEl.appendChild(el);
    }

    extractParams(el, e) {
        const params = {};
        for (const attr of el.attributes) {
            if (attr.name.startsWith('data-')) {
                params[attr.name.slice(5)] = attr.value;
            }
        }
        return params;
    }

    applyPatches(patches) {
        for (const patch of patches) {
            const target = this.locateNode(patch.path);
            if (!target) continue;
            switch (patch.op) {
                case 'replace': this.replaceNode(target, patch.value); break;
                case 'add':    this.addNode(target, patch.value); break;
                case 'remove': this.removeNode(target); break;
            }
        }
    }

    locateNode(path) {
        // JSON Pointer 简化实现：/children/0/attrs/class
        const parts = path.split('/').filter(Boolean);
        let node = this.tree;
        for (const part of parts) {
            if (part === 'children') continue;
            const idx = parseInt(part, 10);
            if (!isNaN(idx)) { node = node.children?.[idx]; continue; }
            if (part === 'attrs' || part === 'actions') break;
        }
        return node;
    }

    replaceNode(target, value) {
        if (typeof value === 'string') {
            try { value = JSON.parse(value); } catch(e) {}
        }
        Object.assign(target, value);
        this.container.innerHTML = '';
        this.renderTree(this.tree, this.container);
    }

    addNode(target, value) {
        if (typeof value === 'string') {
            try { value = JSON.parse(value); } catch(e) {}
        }
        target.children = target.children || [];
        target.children.push(value);
        this.container.innerHTML = '';
        this.renderTree(this.tree, this.container);
    }

    removeNode(target) {
        // 简化：全量重渲染
        this.container.innerHTML = '';
        this.renderTree(this.tree, this.container);
    }
}

// 启动
const ui = new CangjieUI(document.getElementById('app'), __SESSION_ID__);
ui.init(__INITIAL_TREE__);
```

---

### Task 7: WS Manager

**Files:**
- Create: `src/ws/manager.cj`

```cangjie
package cjxt.ws

import cjxt.core.*
import cjxt.session.*
import std.net.*

public class WsManager {
    private let sessionManager: SessionManager
    // WS 连接使用标准库 net 或 fountain 实现
    // 此处为接口定义，具体实现依赖 HTTP 框架

    public func new(sessionManager: SessionManager) {
        this.sessionManager = sessionManager
    }
}
```

---

### Task 8: 主入口 main.cj

**Files:**
- Modify: `src/main.cj`

```cangjie
package cjxt

import cjxt.core.*
import cjxt.render.*
import cjxt.router.*
import cjxt.session.*
import cjxt.ws.*
import cjxt.diff.*
import std.net.http.*

func main(): Unit {
    // 初始化核心组件
    let sessionManager = SessionManager()
    let routeRegistry = RouteRegistry()
    let wsManager = WsManager(sessionManager)

    // 启动 HTTP 服务
    let server = HttpServer()
    server.get("/*", handlePageRequest(sessionManager, routeRegistry))
    server.ws("/_ws", handleWSConnection(sessionManager, wsManager))
    server.start(8080)
    println("cjxt server started on :8080")
}
```

---

### Task 9: 样式系统 defineCSS 宏

**Files:**
- Create: `src/css/define_css_macro.cj`
- Create: `src/css/builder.cj`

---

### Task 10: Signal + Store 状态管理

**Files:**
- Create: `src/core/signal.cj`
)