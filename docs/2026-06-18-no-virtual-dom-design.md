# 无虚拟 DOM 架构设计

## 背景

当前架构问题：
- `sendPatch` 每次重建全树 → `diffTree` 全量比较 → 颗粒 `AttrPatch`/`SubtreePatch`
- action handler ID 全局递增，导致跨 render 的 ID 漂移（Issue #5）
- `Component.expand()` 两阶段渲染是临时方案，未消除根因

## 目标

砍掉 `diffTree`，实现服务端等效 SolidJS 的响应式模型：

```
Signal → Component.markDirty() → sendPatch:
  只 re-render 脏组件
  直接序列化子树 → SubtreePatch
  前端 replaceChild，不比较差异
```

## 设计

### 1. 组件级 Signal 订阅

当前 `SignalTracker.scopeStack` 是全局的，`renderWithScope` 只用在根组件。改为**每个 Component 独立注册 scope**：

```cangjie
// Component 新增
var _dirty: Bool = false
var _path: String = ""

func renderWithScope(path: String): Component {
    this._path = path
    SignalTracker.enterScope({ => this.markDirty() })
    let tree = this.render()
    SignalTracker.exitScope()
    tree
}

func markDirty(): Unit {
    this._dirty = true
    SignalTracker.pendingRender = true
}
```

`Signal.set()` 触发时，只通知订阅它的 Component，不涉及整棵树。

### 2. 渲染栈路径追踪

初始渲染时维护全局路径栈，每层递归 push/pop：

```
/                                 ← div
/children/0                       ← span
/children/0/children/0            ← text
/children/1                       ← Counter（这里 renderWithScope 捕获路径）
/children/2                       ← text
```

路径存储为 `ArrayList<String>`，renderWithScope 时从栈中取出当前路径。

路径追踪只遍历**展开后的 VNode 树**（不含自定义组件内部），不增加额外复杂度。

### 3. 脏组件收集（父覆盖子）

`sendPatch` 遍历树收集脏组件时，父脏则跳过子：

```text
treversal → 遇到已展开的 VNode 树，递归 children
遇到 Component（自定义组件）→ 查 _dirty
  脏 → 加入结果集，不递归其内部
  不脏 → 递归其内部（已展开为 VNode）
```

返回的脏组件集是**最小集**，父组件 SubtreePatch 已包含子。

### 4. sendPatch 新流程

```text
sendPatch:
  1. pendingRender = false
  2. dirtySet = collectDirty(root)    // 遍历找脏组件
  3. if dirtySet.isEmpty: return
  4. for component in dirtySet:
       path = component._path
       newSubtree = component.renderWithScope(path)
       json = serializeSubtree(newSubtree)
       handlerMap = collectHandlers(newSubtree)
       updateHandlerRegistry(path, handlerMap)
       // 更新展开树中该位置
       replaceInFullTree(root, path, json)
       wsSend({ kind: "patch", trees: [{ op: "replace", path, tree: json }] })
  5. clearDirty(root)
```

### 5. 序列化与 handler 收集一体化

不再用 `toJson` + `collectHandlers` 两遍。改为**一次遍历**同时产出 JSON 和 handlerMap：

```cangjie
func serializeSubtree(c: Component, path: String, handlerMap: HashMap<String, ActionHandler>): JsonValue {
    match (c) {
        case v: VNode =>
            // 分配 action ID，同时写入 JSON 和 handlerMap
            let actions = HashMap<String, String>()
            match (v._handlers) {
                case Some(h) =>
                    for ((ev, handler) in h) {
                        let id = nextHid()
                        actions[ev] = id
                        handlerMap[id] = handler
                    }
                case None => ()
            }
            // 递归 children
            ...
        case custom: Component =>
            // 不应出现——调用前已展开
            serializeSubtree(custom.render(), path, handlerMap)
        case t: TextNode => ...
        case f: FragmentNode => ...
        case e: EmptyNode => ...
    }
}
```

此函数同时承担 `toJson` 和 `collectHandlers` 的职责，ID 只在一次遍历中分配，无法漂移。

### 6. 前端变化

当前前端 `applyTreePatches` 支持 `add`/`remove`/`replace` + 排序。新架构只需：

```javascript
handleMsg(msg) {
    case 'patch':
        for (const p of msg.trees) {
            // 只有 replace
            const parentParts = pathToParentParts(p.path);
            const parentEl = navigateTo(parentParts, this.container);
            const idx = lastIndex(p.path);
            const newEl = this.renderSubtree(p.tree);
            parentEl.replaceChild(newEl, parentEl.childNodes[idx]);
        }
}
```

可以移除：
- `applyStrPatches`（不再有 attrs 级 patch）
- `applyPatchToTree`（虚拟树不再需要增量更新）
- `applyPatchToDOM`（DOM 不再有 attrs/actions/text 级 patch）
- 树 patch 排序逻辑
- focus 保存恢复（replaceChild 会自动保焦点——待验证）

### 7. 初次 HTTP 加载

不变。根组件 `renderWithScope("/")` → 全树 JSON → 嵌入 HTML。
新增 `initTree` 消息用于 WS 连接后的全树同步（与现有 `fullTree` 相同）。

### 8. 布局（Layout）

`applyLayout` 在 HTTP 初次和导航时包裹布局组件。布局组件本身也是 Component，可以注册 scope，但通常不应被 markDirty（布局不依赖可变 Signal）。

布局包裹逻辑不变：`applyLayout(path, tree)` → 展开序列化 → 发送。

### 9. 导航

导航走现有 `fullTree` 路径：`applyNav` → 新全树 → `sendFullTree`。
导航清除所有脏标记。

## 收益评估

| 维度 | 当前 | 新架构 |
|------|------|--------|
| diffTree | 50μs/100 节点 | 不存在 |
| render | 重建全树 | 只渲染脏组件 |
| WS patch | attrs 级颗粒 | 单子树 replace |
| handler ID 漂移 | 需 expand() 保障 | 一次性序列化自洽 |
| 实现量 | 现有 | 预估 ~500 行改动核心 |

## 风险

- **路径栈与并发**：当前单线程 + Mutex，路径栈用 `ThreadLocal` 或全局均可
- **全树维护**：每次脏组件渲染后需同步到全树（`replaceInFullTree`），用于后续脏组件收集和下次 diff
- **组件重建**：脏组件 re-render 产生新实例，旧的 subscriptions 需要清理（SignalTracker 需要支持 unsubscribe）
- **焦点保留**：`replaceChild` 替换 DOM 节点可能导致焦点丢失，需验证或加兜底
