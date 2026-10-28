# cjxt 服务端渲染下的使用摩擦清单（实战复盘）

- **仓库**：`cjxt`（1.2.2）／消费方 `atelier-lumine` 的 Web 界面
- **发现于**：把桌面端（chui）的角色库/配装编辑整体搬到 Web（cjxt），
  实现角色库、详情页、三个选择弹窗、设置页、米游社同步
- **性质**：不是逐个 bug，而是**"按文档/示例的直觉写法做，会遇到什么"** 的清单
- **说明**：本文所有结论都带实测证据；**"我不确定"的地方会明确标注**，
  避免把个人误解写成框架缺陷

---

## 0. 先纠正一个我自己搞错的前提

我在实现过程中一度认为「**Signal 放在页面字段上没有用，活不过一次请求**」。
**这个结论是错的**，用它推导出的若干"设计问题"也就不成立。实测如下。

### 实测：页面字段上的 Signal 在 WS 交互中能持续累加

在 `@Page` 页面组件里加：

```cangjie
private var expCount: Signal<Int64> = Signal<Int64>(0)

// render() 里
let expH: ActionHandler = { _ =>
    this.expCount.set(this.expCount.get() + 1)
    PatchResult.ReRender
}
body.add(div([text("实验 Signal=${this.expCount.get()}")], attrs: Some(a("btn btn-sm"))).onClick(expH))
```

用 headless Chrome 真实点击：

```
初始      实验 Signal=0
点第1次   实验 Signal=1
点第2次   实验 Signal=2      ← 持续累加，页面实例被复用
点第3次   实验 Signal=3
刷新页面  实验 Signal=0      ← 只有整页重新加载才重置
```

### 更正二：cjxt 的表单本身就走 WS action，值在服务端

我原文把「表单」和「整页 POST」混为一谈了。查 `Form.cj` 与示例站后确认：

```cangjie
// FormItem 的值就是服务端的 Signal
FormItem([Input().bind(st.username)]).setProp("user").rule(...)

// 提交是普通 ActionHandler，不是 HTML form submit
let submitHandler: ActionHandler = { ctx =>
    if (form.validate()) { /* 服务端读 Signal 校验 */ }
    PatchResult.ReRender
}
PrimaryButton("提交").onClick(submitHandler)
```

**cjxt 表单的设计是「值在服务端 Signal + 提交走 WS action」**，页面实例复用，
不会丢状态。原文那条"表单必然重置"**不成立**。

那一开始为什么会遇到状态丢失？因为**我没用 cjxt 的 Form/Input，自己写了原生
`<form method="post" action="/act">`**（在 `number_field.cj`、`pages.cj`、
`settings.cj` 等 5 个文件里）。那种写法确实每次都是新 HTTP 请求、
`servePage` 会 `sessions.create` 新建实例 —— 但这是**我的实现选择**，不是框架行为。

我当时的理由：搜索/筛选要改整页内容（列表长度、空态、筛选胶囊），
用原生 form POST + 302 回跳比做增量补丁简单。这个取舍本身可以接受，
但代价（页面级状态全丢）我在文档里没算清，反而写成了"框架的问题"。

### 真正的分界线（修正版）

| 通道 | 页面实例 | 页面字段上的 Signal | 备注 |
|---|---|---|---|
| **WS action**（`onClick`/`ActionHandler`） | **复用** | ✅ 保持 | cjxt 的默认交互方式（含 Form 提交） |
| **原生 `<form method=post>`** | **新建** | ❌ 重置 | **框架不提供，是我自己加的** |

**我踩这个坑的三次，全部归因为用法：**

| 场景 | 实际原因 |
|---|---|
| 数值输入框 | 我自己用了原生 form POST → 实例必然重建。**我的选择** |
| 圣遗物草稿 | 走 WS action，Signal 本可保持；真正的问题是**草稿字段不是 Signal**。**我的错误** |
| 同步页状态 | 同上，普通字段。**我的错误** |

**结论：三次都不算框架缺陷。** 原文把第一次算作"设计摩擦"是错的 ——
框架并不要求你放弃 WS action 去做整页 POST，那是我的取舍。

---

## 1. 我认为确实是设计层面的问题

### 1.1 `PatchResult.ReRender` 只补丁脏组件，没有 handler 级的"整页重渲"

`sendPatch` 只处理 `RenderContext.collectOwnedDirty(session)` 收集到的脏组件；
`rerenderInPlace` 存在但是 `private`，handler 里调不到。

**后果**：当"写数据的地方"和"显示数据的地方"不在同一棵子树时（很常见 ——
弹窗写、详情页显示），必须**自己造一个版本号 Signal 做跨区域通知**：

```cangjie
// 弹窗里写完
st.qVersion.set(st.qVersion.get() + 1)

// 详情页要包一层并读它，才会跟着重渲
body.add(SignalView({ =>
    let _ = st.qVersion.get()
    detail(...)
}))
```

实测：不这么做的话，存档已经写对了，界面还显示旧值 ——
用户看到的就是"点了没反应"。

**建议**：`PatchResult` 加一个 `ReRenderPage`（或 handler 拿得到 `ctx.reloadPage()`）。
这比让每个使用者自己发明"版本号 Signal"要干净。

### 1.2 缺"客户端状态"的落点

下拉展开态、聚焦、滚动位置这类**纯浏览器状态**，在 SSR 里默认跟着组件实例走；
而组件每帧重建时就会重置。要保住它只能塞进 AppState（服务端会话），
每次展开/收起都要一次 WS 往返。

我这次为 `Select` 加了 `bindOpen` 才能让"点击展开"可用：

```cangjie
// 现在的写法：展开态必须由调用方放进 AppState
public var qSetOpen: Signal<Bool> = Signal<Bool>(false)
Select(opts).bind(value).bindOpen(qSetOpen)
```

**建议**：考虑 `ClientState<T>`（只存浏览器、不进服务端会话），
让展开/焦点这类状态不必来回跑。

### 1.3 长任务没有原语

从 handler 里起后台任务、按 id 查进度，全靠使用者自己拼。
`atelier-lumine` 的米游社同步要几十秒（几十次 HTTP 往返），
我自建了 `SyncManager`（线程 + jobId + 进度查询）+ meta refresh 轮询。

这类需求在管理后台很常见（导出、批量操作、同步），
`cjxt` 如果能提供 `task.start()` / `task.poll(id)` 会省掉每个项目各写一遍。

### 1.4 两套交互模型并存，但"怎么选"没写

表单 POST 和 WS action 都能"执行一个动作"，但对状态的影响完全不同（见 §0）。
现有文档与示例里，两者混着出现，没有一句话说明选择依据。

---

## 2. 已确认的 bug（本次已修，列出备查）

### 2.1 `Select` filterable 时点击自我抵消

输入框在 wrapper 内部，两者都绑了 click：点输入框时先触发 input 的"打开"，
冒泡到 wrapper 又触发"切换"——一开一合，净结果等于没变。
**非 filterable 正常**（没有 input 那一层）。

修法：展开/收起统一由 wrapper 负责，input 只保留搜索与键盘导航。
（`7c893a6`）

### 2.2 `Select.findLabel` 分组遍历只查第一个分组

```cangjie
// 错
case g: SelectOptionGroup => return this.labelInGroup(g, value)
```

`return` 在循环里，**第一个分组就返回**。选中项属于后面的分组时永远找不到 label，
输入框显示成占位符。

修法：找不到就继续查后面的分组。（`86b5d48`）

两条都补了回归测试，并验证过"注入旧写法即 FAILED"。

---

## 3. 文档/示例可以补的几点

这几条我**一开始就理解错了**，但现有文档确实没正面写：

| 项 | 实际情况 |
|---|---|
| **Dialog 的 `visible=false` 返回 `EmptyVNode`** | 于是"先渲染好、靠 Signal 控制显隐"不成立，必须**外层包一层每帧重建的组件**（`SignalView`）才能重新求值 visible |
| **`onClick` 有 `(String)` 与 `(ActionHandler)` 两个重载** | 直接传 lambda 会 ambiguous，要先声明 `let h: ActionHandler = {...}` 再传 |
| **`SignalView` 不是 cjxt 提供的** | `cjreg` 里有个同名类，是那个项目自己写的工具；用它之前要自己实现（只有 render 转发） |
| **枚举不能用 `==` 比较** | 要走 `match`（语言层，但组件返回值里枚举不少，容易撞） |
| **表单 POST vs WS action 对状态的影响** | 见 §0，这一条最该写 |
| **Signal 的生存期由「定义位置」决定** | 页面实例字段其实能活整个 WS 会话（我原以为只活一次请求）；`render()` 里 new 的才只活一帧；包级 `let` 是进程级。设计文档原来只写了"Component 字段或模块级"，没说清这三者的差别 |
| **`Store` 与 `AppState` 不是同一类东西** | `Store` 是普通类、框架完全不认识，作用域 = 它的存放位置（包级 → 跨会话共享，实测新标签页能读到）；`AppState` 是零行标记接口 + 框架注册机制，固定每会话一份。原文档对 `Store` 只有"薄封装"一句，没写作用域 |

---

## 4. 我**不确定**、需要一起看的

| # | 事项 | 现状 |
|---|---|---|
| 4.1 | **双段路由 `[name]/[idx]`** | 实测 `@Page["/quick/[name]/[idx]"]` 访问 `/quick/名字/0` 返回 404。但 `RouteEntry.doMatch` 的代码看起来是支持多段的 —— 我没查清是注册阶段还是匹配阶段的问题，最后绕成单段 `[spec]`（"名字~下标"）。**这可能是我用法有问题，不是框架缺陷。** |
| 4.2 | ~~**`@Page` 的 `layout` 参数**~~ | **已查清并修复**（`a8ba04f`）。真实缺陷不是"二次包裹"，而是**两条路径不一致**：HTTP 首渲完全没调 `applyLayout`（首屏没有外壳），而 WS 恢复时又对已渲染的 tree 套了一次。叠加结果：首屏无 layout、连上 WS 后突然出现、且因形态不同导致指纹永远对不上、每次连接都白下发整树。修法：首渲在渲染入口套一次，`resumeSession` 只 expandTree。已补回归用例 `src/layout_once_e2e_test.cj`。 |
| 4.3 | **`Select` 选中值在"每次重建组件"场景下的正确姿势** | 我用的是「值放 AppState 的 Signal + 每次新建 Select」，能工作。但示例站 `ShowcaseState` 也是这么写的吗？有没有更省事的写法（比如组件内部按 key 找回状态），我没确认。 |

---

## 5. 建议优先级

如果要排期，我的建议是：

1. **§0 的通道差异写进文档** —— 零成本，能挡掉最容易掉进去的坑
2. **§1.1 整页重渲** —— 收益最大，能删掉一堆"版本号 Signal"的变通写法
3. **§1.2 客户端状态** —— 交互体验的根子问题
4. **§1.3 后台任务** —— 让每个项目少写一遍同一套东西
5. **§4 的三条先查清** —— 避免把"我用法不对"当成"框架该改"

---

## 6. 已同步修订到设计文档的内容

以下几项已直接写进 `docs/design.md` §3.11（不必再单独讨论）：

- **§3.11 总表**：从三层扩成四层，增加「谁管生命周期」一列 ——
  `Signal` / `Store` 是**使用者**管，`AppState` / `SessionContext` 是**框架**管。
  这是选型时第一个要分清的事。
- **§3.11.1 新增「Signal 的生存期」小节**：给出四类定义位置的对照表
  （页面实例字段 = 整个 WS 会话 / AppState 字段 = 跨整页刷新 / 函数内 = 一帧 /
  包级 = 进程），并明确「把 Signal 放页面实例字段上是有效的」——
  原文没有这句，容易被误读成"必须放 AppState"。
- **§3.11.2 新增「Store 与 AppState 不是同一类东西」小节**：对比表 + 各自用法 +
  「Store 的作用域就是它被存放的位置」，并注明它目前只被单测使用。

## 附：本次为 cjxt 提交的改动

| 提交 | 内容 |
|---|---|
| `7c893a6` | filterable 时 input 不再单独绑 click；新增 `Select.bindOpen` |
| `f8589b2` | 回归测试：点击只由一个 handler 负责、bindOpen 的展开语义 |
| `86b5d48` | 修 `findLabel` 分组遍历只查首个分组 |

产品侧改动见 `atelier-lumine` 的 `web/`（角色库、详情页、三弹窗、设置页、同步页）。
