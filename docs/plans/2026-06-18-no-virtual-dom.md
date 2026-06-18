# 无虚拟 DOM 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 砍掉 diffTree，改为 Signal → 脏组件 → 直接子树替换的响应式架构

**Architecture:** 三阶段。Phase 1 并行添加新机制不改行为；Phase 2 切换 sendPatch；Phase 3 删除旧代码。

**Tech Stack:** Cangjie 1.1.0, StdX 1.1.0, Tang, WebSocket

**约束：**
- `class`/`struct` 使用 `init` 构造
- match arm `=> {}` 内不能 `let`/`for` — 提取为独立函数
- 枚举不支持 `==`/`!=`
- `type`/`match` 是关键字，变量名用 `typ`/`doMatch` 等

---

## Phase 1: 新机制并行构建

### Task 1: Signal 支持 subscriber 清理

**Files:**
- Modify: `src/signal.cj`
- Test: `src/signal_test.cj`

将 `subs` 改为可清理。在 `renderWithScope` 入口清理旧 subscriber。

```cangjie
// Signal 新增
public func clearSubs(): Unit {
    this.subs = ArrayList<() -> Unit>()
}
```

测试 subscriber isolation（两个独立 scope 各自注册，分别触发）。

---

### Task 2: Component 接口新增 dirty/路径支持 + BaseComponent

**Files:**
- Modify: `src/component.cj`
- Modify: `src/vnode.cj`

Component 接口新增默认实现：
- `markDirty()` — 设置 SignalTracker.pendingRender = true
- `setPath(path)` / `getPath()` — 空默认
- `clearDirty()` — 空默认
- `renderWithScope(path)` — 设置 path → enterScope({=>markDirty}) → render() → exitScope

创建 `BaseComponent` 类，封装 `_dirty: Bool` / `_path: String` 字段和上述方法实现。

VNode/TextNode/FragmentNode/EmptyNode 用默认空实现（不标记 dirty）。

signal_test.cj 添加 renderWithScope 测试。

---

### Task 3: 渲染栈路径追踪

**Files:**
- Modify: `src/component.cj`
- New: `src/renderctx.cj`

创建 `RenderContext` 管理渲染栈：

```cangjie
// RenderContext
static var pathStack = ArrayList<Int64>()

func pushIndex(idx: Int64): Unit { ... }
func popIndex(): Unit { ... }
func getCurrentPath(): String { ... }  // e.g. "/children/0/children/2"
```

初始全树渲染时，遍历展开后的树并 push/pop。遇到自定义组件（instanceof BaseComponent）时，调用 `component.renderWithScope(currentPath)`。

RenderContext 同时管理 `componentDirtyMap: HashMap<Int64, Component>`，用于脏组件收集。

---

### Task 4: 脏组件收集

**Files:**
- New: `src/dirty.cj`
- Modify: `src/app.cj`

`collectDirty(root)` 函数遍历树找到最小脏组件集（父覆盖子）：

```cangjie
func collectDirty(c: Component, path: String, out: ArrayList<(String, Component)>): Unit {
    match (c) {
        case v: VNode =>
            for (i in 0..v._children.size) {
                collectDirty(v._children[i], "${path}/children/${i}", out)
            }
        case f: FragmentNode =>
            for (i in 0..f._children.size) {
                collectDirty(f._children[i], path, out)
            }
        case b: BaseComponent =>
            if (b._dirty) {
                out.add((path, b))
            } else {
                // 不脏但可能有子组件脏？不展开子，BaseComponent 内部自行管理
            }
        case _ => ()
    }
}
```

注意：只遍历展开的 VNode/FragmentNode 树。BaseComponent 需要先 render 展开才能看到内部的子组件脏标记。

**设计决策：** 如何找到脏组件，一种方式是从根遍历（当前做法），另一种是维护一个脏组件注册表（Signal 触发时自注册）。

**当前推荐：根遍历 + 父覆盖子过滤。**

在 sendPatch 时从根展开树遍历一次，O(N) 但 N 只包含组件边界数（通常是几十个），不是完整 VNode 节点数。

---

## Phase 2: 切换 sendPatch

### Task 5: 一体化序列化函数

**Files:**
- Modify: `src/html.cj`（前端 JS）
- New: `src/serialize.cj`

创建 `serializeSubtree(component, path)` 一次遍历产出：

1. JSON tree（给前端）
2. `HashMap<String, ActionHandler>`（handler 映射）

```cangjie
func serializeSubtree(c: Component, handlerMap: HashMap<String, ActionHandler>): JsonValue {
    match (c) {
        case v: VNode =>
            // 分配 action ID，同时写入 JSON 和 handlerMap
            let actions = HashMap<String, String>()
            if (v._handlers != None) {
                for ((ev, handler) in v._handlers) {
                    let id = nextHid()
                    actions[ev] = id
                    handlerMap[id] = handler
                }
            }
            // JSON：{ type, attrs, actions, children }
            // handlerMap：{ h1: fn, h2: fn }
        case t: TextNode => ... 
        case f: FragmentNode => ...
        case e: EmptyNode => ...
        case b: BaseComponent => serializeSubtree(b.render(), handlerMap)
        case _ => serializeSubtree(c.render(), handlerMap)  // fallback
    }
}
```

移除旧的 `Component.toJson` fallback（第 42 行 `this.render().toJson(w)`）。

handlerMap 由调用方（sendPatch）持有，替代 `state.actions` + `state.handlers` 的作用。

---

### Task 6: 新 sendPatch

**Files:**
- Modify: `src/app.cj`

新 sendPatch 流程：

```cangjie
func sendPatch(ws, state, session) {
    SignalTracker.pendingRender = false
    let dirtySet = ArrayList<(String, Component)>()
    collectDirty(state.page, "", dirtySet)  // 从根遍历
    if (dirtySet.isEmpty) { return }
    
    for ((path, component) in dirtySet) {
        SignalTracker.pendingRender = false
        // 清理旧 subscriber
        // render
        let newSubtree = component.renderWithScope(path)
        // 序列化
        let patchHandlerMap = HashMap<String, ActionHandler>()
        let json = serializeSubtree(newSubtree, patchHandlerMap)
        // 更新 handler 映射
        // 更新全树中该位置
        replaceSubtreeInFullTree(session.tree, path, json)
        // 发送
        wsSendJson(ws, PatchMsg([TreePatchEntry("replace", path, Some(json))]))
    }
    
    clearDirty(state.page)
}
```

关键点：
- `session.tree` 仍然是完整展开树，用于后续脏组件收集遍历
- 每个脏组件渲染后，用 `replaceSubtreeInFullTree` 同步到 session.tree
- handler 映射更新为新的 patchHandlerMap

action dispatch 查找 handler 时从最新 handlerMap 找。

---

### Task 7: 前端子树替换

**Files:**
- Modify: `src/html.cj`

简化为只处理 `replace` 操作：

```javascript
handleMsg(msg) {
    case 'patch':
        for (const p of msg.trees) {
            // 只有 replace
            const parentParts = p.path.split('/').filter(Boolean).slice(0, -2);
            const parentEl = parentParts.length ? this.navigateTo(parentParts, this.container) : this.container;
            const idx = parseInt(p.path.split('/').filter(Boolean).pop());
            const newEl = this.renderSubtree(p.tree);
            const old = parentEl.childNodes[idx];
            if (old) parentEl.replaceChild(newEl, old);
        }
}
```

移除不再需要的函数：
- `applyStrPatches` / `applyPatchToTree` / `applyPatchToDOM` — 不再有颗粒 patch
- `sortedTrees` — 只有单个 replace，无需排序
- focus 保存恢复 — replaceChild 应自动保焦点（待验证，不移除也可以）

---

### Task 8: 初始全树渲染 + 导航适配

**Files:**
- Modify: `src/app.cj`

servePage:
```cangjie
// 初始 HTTP
page.renderWithScope("/") → 序列化全树 → HTML shell
注意：初始渲染时需要用 RenderContext 路径栈给所有子组件分配路径
```

applyNav:
- 直接替换 state.page → renderWithScope → 全树序列化 → FullTreeMsg

startSession/initSignals:
```cangjie
// WS 连接后的全树同步
page.renderWithScope("/") → serializeTree → send FullTreeMsg
```

---

## Phase 3: 清理旧代码

### Task 9: 删除废弃代码

**Files:**
- Delete: `src/diff.cj`（整个文件）
- Modify: `src/diff_test.cj`（删除或改为空）
- Delete: `src/expand?` — 移除 Component.expand() 默认实现
- Modify: `src/vnode.cj` — 移除 VNode/FragmentNode/TextNode/EmptyNode 的 expand() 重写
- Modify: `src/component.cj` — 移除 expand() 默认实现、移除 toJson fallback 到 render()
- Modify: `src/html.cj` — 移除 applyStrPatches、applyPatchToTree、applyPatchToDOM、sortedTrees、focusSave
- Modify: `src/app.cj` — 移除所有 .expand() 调用、移除 sendGranularPatch/CombinedPatchMsg
- Modify: `src/action.cj` — 移除 GranularPatch 相关枚举如果不再需要

---

## 依赖图

```
Task 1 (Signal clearSubs) ──→ Task 2 (Component dirty) ──→ Task 3 (RenderContext)
                                                                     ↓
Task 4 (collectDirty) ←────────────────────────────────────────── Task 3
       ↓
Task 5 (serializeSubtree) ←── Task 1 (复用 ID 管理)
       ↓
Task 6 (new sendPatch) ←── Task 4 + Task 5 + Task 3
       ↓
Task 7 (前端简化) ←── Task 6 的新 patch 格式
       ↓
Task 8 (初始渲染/导航) ←── Task 6
       ↓
Task 9 (清理旧代码) ←── 全部
```

---

## 执行顺序

```
Task 1 + Task 2 → Task 3 → Task 4 + Task 5 → Task 6 → Task 7 + Task 8 → Task 9
                                ↓
                           Task 5 依赖 Task 3（路径栈），可以并行
```

推荐执行方式：**线性执行**。Task 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9。

每个任务写完测试→实现→提交。
