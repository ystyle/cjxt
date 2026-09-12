# 会话与 WebSocket

每个浏览器标签页对应一个 **Session**：`GET` 首屏时服务端创建会话（HTML 壳里带 `sessionId`），
前端用它建立 WebSocket；此后页面渲染、事件分发、令牌恢复都走这条连接。

- **会话数据**：`Session`（`context` 鉴权上下文 + `states` 应用状态）
- **渲染期读会话**：`SessionContextState`（`context` 的响应式视图）
- **刷新恢复**：`App.auth(validateToken)` 钩子 + 前端 `localStorage` 里的令牌

> **可运行示例**：`examples/src/session.cj`（路由 `/session`、`/session/login`、`/session/profile`）。
>
> ```shell
> bash scripts/build-css.sh
> cd examples && cjpm build && ./target/release/bin/main   # 默认 8080
> # 浏览器打开 http://localhost:8080/session
> ```
>
> 三个演示账号（密码均为 `123456`）：`admin`（管理员）、`editor`（内容编辑）、`viewer`（只读访客）。

---

## 一、完整示例：登录 → 守卫 → 角色渲染 → 登出

### 1. 注册「会话级状态」与「令牌校验钩子」

```cangjie
// main：会话状态每 session 一份；auth 钩子在 WS 带令牌重连时被调用
App()
    .state<SessionDemoState>({ => SessionDemoState() })
    .auth({ t => validateDemoToken(t) })
    .host("0.0.0.0").port(8080).serve()
```

令牌校验钩子由应用提供，框架不关心业务（验签、查库、校验用户是否启用都在这里）：

```cangjie
// 示例令牌格式 "demo:<username>"；真实项目应验签并查库
public func validateDemoToken(token: String): Option<HashMap<String, String>> {
    let prefix = "demo:"
    if (!token.startsWith(prefix)) {
        return None
    }
    let name = token[prefix.size..token.size]
    match (findDemoUser(name)) {
        case Some(u) => Some(demoContext(u))   // 返回要写入会话上下文的信息
        case None => None
    }
}

func demoContext(u: DemoUser): HashMap<String, String> {
    let m = HashMap<String, String>()
    m["uid"] = u.id.toString()
    m["username"] = u.username
    m["role"] = roleName(u.role)
    m["isAdmin"] = if (isAdminRole(u.role)) { "1" } else { "0" }
    m
}
```

### 2. 登录：把用户写进会话上下文

`ActionContext.setContext` 写入的就是 `Session.context`（鉴权权威）；写 `token` 时框架会
自动把令牌同步给前端（前端存 `localStorage`，下次连接回传）：

```cangjie
func doLogin(ctx: ActionContext): PatchResult {
    let s = this.state.getOrThrow()
    if (this.form.validate()) {          // 表单校验（FormRule required）
        this.tryLogin(s, ctx)
    }
    PatchResult.ReRender
}

func loginUser(s: SessionDemoState, ctx: ActionContext, u: DemoUser): Unit {
    if (u.password != s.password.get()) {
        s.setNotice("密码错误。示例密码均为 123456", "error")
        return
    }
    for ((k, v) in demoContext(u)) {     // uid / username / role / isAdmin
        ctx.setContext(k, v)
    }
    ctx.setContext(TOKEN_KEY, "demo:${u.username}")   // 框架同步给前端 localStorage
    ctx.route.push("/session/profile")                // 跳转，守卫读到的就是刚写入的上下文
}
```

密码框回车提交（前端 keydown 委托会把按键信息带回服务端）：

```cangjie
func onEnter(ctx: ActionContext): PatchResult {
    match (ctx.keyEvent) {
        case Some(ke) => if (ke.isEnter()) { return this.doLogin(ctx) }
        case None => ()
    }
    PatchResult.ReRender
}
```

### 3. 页面守卫

守卫签名是 `(HashMap<String, String>) -> Option<String>`：`None` 放行，`Some(path)` 拒绝并跳转。
框架把**当前会话上下文**传进来：

```cangjie
public func requireLogin(ctx: HashMap<String, String>): Option<String> {
    match (ctx.get("uid")) {
        case Some(v) => if (v == "") { Some("/session/login") } else { None }
        case None => Some("/session/login")
    }
}

// @Page 的第三个参数是守卫
@Page["/session/profile", "个人中心", requireLogin]
class SessionProfilePage <: Component { /* ... */ }
```

### 4. 渲染期读登录态：`SessionContextState`

页面要按登录态/角色渲染，必须在 **`render()` 里**读会话上下文。`SessionContextState` 与
`Session.context` 共享同一份数据，读取时会自动订阅变化（登录、登出、令牌恢复都会触发重渲）：

```cangjie
class SessionHomePage <: Component {
    var sctx: Option<SessionContextState> = None

    public func onMount(ctx: LifecycleContext): Unit {
        // 只取引用；不要在 onMount 里把上下文缓存成普通字段
        this.sctx = Some(ctx.getState<SessionContextState>())
    }

    public func render(): IComponent {
        let s = this.ctxOf()
        let logged = s.uid() > 0
        let role = s.get("role")           // 读取即订阅
        // ... 按 logged / role 渲染入口与按钮
    }
}
```

可用方法：`get(key)` / `has(key)` / `isAdmin()` / `uid()` / `username()` / `token()` /
`snapshot()`（副本，不订阅）/ `subscribe(fn)`。

### 5. 操作级权限校验（服务端权威）

**UI 隐藏按钮只是体验，真正的拦截在 handler 里**——上下文是权威来源：

```cangjie
func sessionRole(ctx: ActionContext): String {
    match (ctx.getContext().get("role")) {
        case Some(v) => v
        case None => ""
    }
}

func allowAtLeast(ctx: ActionContext, need: String): Bool {
    roleRank(sessionRole(ctx)) >= roleRank(need)   // admin 3 > editor 2 > viewer 1 > 未登录 0
}

func auditOperation(ctx: ActionContext, label: String, need: String): Unit {
    let s = this.state.getOrThrow()
    if (allowAtLeast(ctx, need)) {
        s.setNotice("${label}：已执行（当前角色 ${sessionRole(ctx)}）", "success")
    } else {
        s.setNotice("${label}：拒绝——需要 ${need} 及以上权限，当前角色为「${sessionRole(ctx)}」", "error")
    }
}
```

### 6. 登出与切换账号

清空上下文即可（`token` 清空后框架会发 `auth` 消息，前端据此删掉 `localStorage` 里的令牌）：

```cangjie
func clearSession(ctx: ActionContext): Unit {
    for (k in ["uid", "username", "role", "isAdmin", TOKEN_KEY]) {
        ctx.setContext(k, "")
    }
}

// 切换账号 = 登出 + 跳登录页；登出 = 登出 + 跳公开页
func doSwitch(ctx: ActionContext): PatchResult {
    clearSession(ctx)
    this.state.getOrThrow().setNotice("请用另一个账号登录", "warning")
    ctx.route.push("/session/login")
    PatchResult.ReRender
}
```

### 7. 三条链路的时序

```text
① 首屏（无凭据）
   GET /session ──► 创建 Session（context 为空）──► 渲染 HTML 壳 + sessionId
                    前端连 WS(connect{token?}) ──► 无令牌：保持匿名渲染

② 登录
   点击「登 录」──► action ──► handler: setContext(uid/role/isAdmin/token)
                              └─ push("/session/profile") ──► 守卫读上下文 ✅ ──► 渲染新页
   框架 ──► auth{token} ──► 前端 localStorage.setItem("cjxt_token", token)

③ 刷新带令牌恢复
   GET /session/profile ──► 守卫无凭据 ❌ ──► 先渲染登录页占位（session.deferred = true）
   前端连 WS(connect{token}) ──► validateToken ──► 写 Session.context
                              ├─ deferred：按 path 重新解析渲染（守卫这次通过）
                              └─ 公开页：就地重渲一次（否则沿用首屏的未登录版本）
```

---

## 二、不同权限用户的切换

示例有三个角色，权限从高到低：`admin` > `editor` > `viewer`（未登录 = 0）。

| 账号 | 角色 | 受保护页可见操作 | 越权调用「用户管理」 |
|---|---|---|---|
| `admin` | 管理员 | 编辑资料、用户管理 | 执行成功 |
| `editor` | 内容编辑 | 编辑资料 | 拒绝（需要 admin） |
| `viewer` | 只读访客 | 无 | 拒绝（需要 admin） |

页面按角色裁剪按钮（体验层）：

```cangjie
if (roleRank(role) >= roleRank("editor")) {
    actions.add(Button([text("编辑资料（editor+）")]).kind(ButtonKind.Primary).onClick(doEdit))
}
if (roleRank(role) >= roleRank("admin")) {
    actions.add(Button([text("用户管理（仅 admin）")]).kind(ButtonKind.Danger).onClick(doManage))
}
// 所有角色都可见：用来验证「UI 隐藏不算安全」，viewer 点击会被服务端拒绝
actions.add(Button([text("模拟越权调用「用户管理」")]).onClick(doManage))
```

**动手验证**（都可在 `/session` 完成）：

1. 直接打开 `/session/profile` → 被守卫拦到登录页；
2. 用 `admin` 登录 → 个人中心显示 `uid=1 / role=admin`，出现 2 个角色按钮，点「用户管理」→ 已执行；
3. 点「切换账号」→ 用 `viewer` 登录 → 角色按钮变成 0 个；
4. 点「模拟越权调用『用户管理』」→ 服务端返回 **拒绝（需要 admin 及以上权限，当前角色为 viewer）**；
5. 停在 `/session` 刷新页面 → 仍显示「已登录 / viewer」（公开页也会按恢复后的上下文重渲）。

---

## 三、约定与常见坑

| 事项 | 约定 |
|---|---|
| 渲染期读登录态 | 用 `SessionContextState`，且**必须在 `render()` 里读**；`onMount` 里只存引用 |
| 为什么不能缓存在 `onMount` | 令牌恢复后的就地重渲**不会重跑 `onMount`**（避免重置页面级信号），缓存下来的快照会是脏的 |
| 鉴权权威 | 永远是 `Session.context`（守卫与 `ctx.getContext()` 读它）；`SessionContextState` 只是它的响应式视图（共享同一份数据） |
| 外部模块读上下文 | `App.getSession(sid).getContext()`，返回**副本**，改副本不影响会话鉴权态 |
| 前端令牌存放 | `localStorage["cjxt_token"]`（框架自动写入/清除），不要在业务代码里直接读写 |
| 首屏一定没有登录态 | 令牌只在前端 `localStorage`，HTTP 阶段拿不到 → 公开页首屏按未登录渲染，WS 校验令牌后再重渲一次（两段式） |
| 状态注册时机 | 自定义 `AppState` 由 `App.state<T>()` 注册；`SessionContextState` 由框架每会话自动注入 |

---

## Session

每 WebSocket 连接对应一个 Session：

```cangjie
public class Session {
    let id: String                        // ULID 格式会话 ID
    var page: IComponent                  // 当前页面组件
    var tree: IComponent                  // 展开后的组件树
    var path: String                      // 当前路由路径
    var wsState: WsState                  // Connecting / Connected / Disconnected
    var createdAt: Int64                  // 创建时间戳
    var lastActiveAt: Int64               // 最后活跃时间
    let context: HashMap<String, String>  // 会话上下文（鉴权权威，包内可见）
    var states: HashMap<String, AppState> // AppState 实例（含框架注入的 SessionContextState）
    var deferred: Bool                    // HTTP 阶段被守卫拒绝，WS 令牌就绪后需重渲
    var syncedToken: String               // 已同步给前端的令牌

    func touch(): Unit                    // 刷新最后活跃时间
    func updatePage(page, tree): Unit     // 更新页面
    func isExpired(ttl: Int64): Bool      // 是否过期
    func getContext(): HashMap<String,String>  // 上下文副本（外部模块读）
}
```

## WsState

```cangjie
public enum WsState {
    | Connecting
    | Connected
    | Disconnected
}
```

## SessionManager

```cangjie
public class SessionManager {
    // TTL 毫秒，默认 300000（5 分钟）
    public init(ttlMillis: Int64)

    // 创建新 session，自动生成 ULID ID
    func create(page, tree): Session

    // 以指定 ID 保存
    func save(id, page, tree): Session

    // 获取 session
    func get(id): Option<Session>

    // 删除
    func remove(id): Unit

    // 清理过期 session
    func cleanup(): Unit

    // 生成 ULID
    func generateId(): String
}
```

## WebSocket 消息协议

### 前端 → 服务端

| type | 触发时机 | 服务端处理 |
|------|---------|-----------|
| `connect` | WS 建立（携带 `sessionId` + `token`） | 恢复会话：令牌有效则写上下文并重渲 |
| `action` | 点击 `[data-action-click]` / 按键 | `dispatchAction` → handler |
| `bind` | `input` 事件（300ms debounce，blur/Enter 立即） | `dispatchBind` → `signal.set()` |
| `navigate` | 路由跳转 | `handleNavigate`（先跑守卫） |
| `ack(mount)` | 首次渲染完成 | 不重复调 `onMount`（首屏已由服务端渲染时调用） |
| `ack(update)` | patch 应用完成 | `onUpdate` |
| `dom_result` | DOM 事务查询结果 | `dispatchDomResult` → 续体 |
| `upload_begin` | WS 二进制上传开始 | 进入单流上传状态（后续为 binary 帧） |

### 服务端 → 前端

| kind | 用途 | 数据结构 |
|------|------|---------|
| `connected` | 连接确认 | `{kind}` |
| `fullTree` | 全量替换 DOM（导航/恢复） | `{kind, tree, path}` |
| `patch` | 批量 patch | `{kind, attrs, trees}` |
| `push` | 服务端主动推送（`ctx.push` / `App.pushUpdate`） | `{kind, patches}` |
| `title` | 页面标题 | `{kind, title}` |
| `deny` | 导航拒绝（守卫返回跳转目标） | `{kind, reason, path}` |
| `auth` | 令牌同步（登录/登出） | `{kind, token}`，空串表示清除 |
| `dom_command` | DOM 事务命令/查询 | `{kind, txId, commands, needResult}` |
| `upload_progress` | 上传块级 ack（背压） | `{kind, id, received}` |
| `upload_error` | 上传失败 | `{kind, id, message}` |

### WS 辅助函数

```cangjie
wsSendJson<JsonSerializable>(ws, msg)  // JSON 序列化发送
wsSendText(ws, text)                    // 发送纯文本
wsClose(ws)                             // 发送关闭帧
```
