# Session 与用户 Token 绑定方案

## 目标
无状态 session → 用户登录后绑定 userId，后续请求鉴权。

## Session 扩展

```cangjie
class Session {
    let id: String
    var userId: Option<String> = None
    var token: Option<String> = None
    ...
}
```

## 流程

### 首次访问（未登录）

```
GET / → servePage() → sessions.create("sid_xxx")
     → HTML 嵌入 sid_xxx
     → 返回匿名 session
```

### 登录

```
WS action type: "login" { username, password }
  → 服务端验证凭证
  → 签发 JWT (sub: userId, exp, roles...)
  → session.userId = "u42"
  → session.token = "jwt..."
  → 返回 token 给前端
  → 前端存 localStorage
```

### 后续 WS 消息

前端每次发送：

```json
{ "sessionId": "sid_xxx", "token": "jwt...", "type": "action", ... }
```

服务端 `upgradeWS`：

```
收到 token → 解析 JWT → 校验签名+有效期
  → 有效：session.userId = jwt.sub
  → 无效/过期：DenyMsg("登录已过期")
```

### 新标签页

```
前端从 localStorage 读 token
新 HTTP 请求 → Authorization header 或 cookie
  → servePage() 解析 token
  → 创建新 session，绑定 userId
  → 直接渲染已登录页面
```

## 页面守卫

`@Page` 宏的守卫支持：

```cangjie
@Page["/admin", guard: "requireAuth"]
```

守卫函数检查 `session.userId != None`，不满足则返回空或跳转登录页。

## SessionManager 扩展

```cangjie
class SessionManager {
    // 现有
    func create(page, tree): Session
    func get(id): Option<Session>
    func remove(id): Unit
    func cleanup(): Unit

    // 新增
    func bindUser(sessionId: String, userId: String): Unit
    func findByUser(userId: String): Array<Session>
}
```

## Token 验证

```
JWT → 服务端用密钥验签
  → payload: { sub: userId, exp: timestamp, roles: [...] }
  → exp 校验：过期则返回 Deny
  → sub 提取：session.userId = payload.sub
```

## 不变的部分

- `execMutex` 继续保护全局数据结构
- WS action 系统不变，action 内可通过 `ctx.session` 获取 userId
- 路由注册不变，守卫逻辑由 route registry 统一处理
