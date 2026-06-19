# VNode 与 DSL

## VNode

`VNode` 是构建 UI 树的基本单元：

```cangjie
public struct VNode <: IComponent {
    _tag: String                    // HTML 标签
    _attrs: Option<Attributes>      // 属性字典
    _children: Array<IComponent>    // 子节点
    _key: Option<String>            // 差分 key
    _actions: Option<ActionMap>     // 事件 → handler ID
    _handlers: Option<HashMap<String, ActionHandler>>  // handler ID → 回调
}
```

## 标签辅助函数

| 函数 | 生成 |
|------|------|
| `div([...])` | `<div>` |
| `span([...])` | `<span>` |
| `button([...])` | `<button>` |
| `input()` | `<input>` |
| `a([...])` | `<a>` |
| `p([...])` | `<p>` |
| `h1([...])` / `h2` / `h3` | `<h1~3>` |
| `form([...])` | `<form>` |
| `image()` | `<image>` |
| `i([...])` | `<i>` |
| `ul([li([...])])` | `<ul><li>` |
| `text("内容")` | 文本节点 |
| `Fragment([...])` | 片段（不产生 DOM 节点） |
| `Empty()` | 空节点 |
| `cssStyle("body{margin:0}")` | `<style>` |

所有标签函数签名一致：`func name(children, attrs?, key?, actions?): VNode`。

## 方法链

```cangjie
div([text("框")])
    .attr("data-id", "123")         // 设单个属性
    .attrs(HashMap<String, String>([("class", "box")]))  // 全量替换属性
    .style("padding:8px")           // 设 style
    .className("box")               // 设 class
    .key("unique-key")              // 设 key
    .children([...])                // 替换子节点
    .actions(m)                     // 设 actions 映射
```

## 事件绑定

```cangjie
// onClick — 通过 ActionHandler（推荐）
button([text("提交")]).onClick({ ctx =>
    PatchResult.ReRender
})

// onClick — 通过 action 名字符串
button([text("提交")]).onClick("submitAction")

// 泛用事件绑定（click, mouseenter, keydown...）
div([...]).on("click", { ctx => PatchResult.ReRender })
```

### ActionHandler

```cangjie
public type ActionHandler = (ActionContext) -> PatchResult
```

## 双向数据绑定

```cangjie
// bind<T> 要求 T: ToString & JsonDeserializable<T>
Input().bind(this.state.username)               // Signal<String>
Slider().bind(this.state.volume)                // Signal<Int64>
Switch().bind(this.state.enabled)               // Signal<Bool>
CheckboxGroup([...]).bind(this.state.checks)    // Signal<ArrayList<String>>
Select().bind(this.state.option)                // Signal<String>
Select().multiple().bindMulti(this.state.list)  // Signal<ArrayList<String>>
```

### bind 机制

1. `VNode.bind<T>(signal)` 分配 `data-bind-id`（如 `_b1`）
2. 创建 handler，在 handler 中用 `JsonDeserializable<T>.fromJson(value)` 解析 → `signal.set()`
3. 前端监听 `input` 事件，300ms debounce 后通过 WS 发送
4. IME 组合期间不发送
5. `<input type="range">` 发送 JSON number 以支持 `JsonDeserializable<Int64>`
6. Patch 更新时保持焦点元素的值不被覆盖

### 前端 JS 实现

```javascript
 FRONTEND_JS
attachBind(el) {
    const bid = el.getAttribute('data-bind-id');
    // 300ms debounce
    el.addEventListener('input', () => {
        clearTimeout(timer);
        timer = setTimeout(() => {
            const raw = el.value ?? el.textContent ?? '';
            const value = el.type === 'range' ? parseFloat(raw) : raw;
            this.send({ type: 'bind', name: bid, value });
        }, 300);
    });
    // IME 保护
    el.addEventListener('compositionstart', () => { composing = true; });
    el.addEventListener('compositionend', () => { /* 恢复发送 */ });
    // Enter 直接提交
    el.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') { send(); }
    });
}
```

## ActionContext

```cangjie
public struct ActionContext {
    let sessionId: String
    let context: HashMap<String, String>    // 会话上下文
    let params: HashMap<String, String>     // 请求参数
    let router: Router                      // 导航器
    let pushFn: (Array<PatchEntryMsg>) -> Unit
    let sessionStates: HashMap<String, AppState>

    func push(patches: Array<PatchEntryMsg>): Unit
    func navigate(path: String): Unit
    func getState<T>(): T where T <: AppState
}
```

### PatchResult

```cangjie
public enum PatchResult {
    | ReRender                     // 触发重渲
    | Patch(Array<PatchEntry>)     // 颗粒 patch（框架预留）
}
```

## 序列化格式

组件树序列化为 JSON 发送到前端：

```json
{
  "type": "div",
  "attrs": { "class": "container_4507" },
  "actions": { "click": "_h42" },
  "children": [
    { "type": "text", "attrs": { "text": "内容" } },
    {
      "type": "div",
      "attrs": { "data-bind-id": "_b7", "class": "el-input__wrapper" },
      "children": []
    }
  ]
}
```

前端 CangjieUI 根据 `type` 创建 DOM，设置属性，绑定 action/bind，递归渲染。
