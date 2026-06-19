# 会话与 WebSocket

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
    let context: HashMap<String, String>  // 会话上下文
    var states: HashMap<String, AppState> // AppState 实例

    func touch(): Unit                    // 刷新最后活跃时间
    func updatePage(page, tree): Unit     // 更新页面
    func isExpired(ttl: Int64): Bool      // 是否过期
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

| type | 触发时机 | 数据处理 |
|------|---------|---------|
| `connect` | WS 建立 | 握手确认 |
| `action` | 点击 `[data-action-click]` | `dispatchAction` → handler |
| `bind` | `input` 事件（300ms debounce） | `dispatchBind` → `signal.set()` |
| `navigate` | 路由跳转 | `handleNavigate` |
| `ack(mount)` | 初次渲染完成 | 触发 `onMount` |
| `ack(update)` | patch 应用完成 | 触发 `onUpdate` |

### 服务端 → 前端

| type | 用途 | 数据结构 |
|------|------|---------|
| `fullTree` | 全量替换 DOM | `{kind, tree: IComponent}` |
| `push` | 增量 patch | `{kind, patches: [{op, path, tree}]}` |
| `patch` | 批量 patch | `{kind, attrs, trees}` |
| `connected` | 连接确认 | `{kind}` |
| `title` | 页面标题 | `{kind, title}` |
| `deny` | 导航拒绝 | `{kind, reason}` |

### WS 辅助函数

```cangjie

wsSendJson<JsonSerializable>(ws, msg)  // JSON 序列化发送
wsSendText(ws, text)                    // 发送纯文本
wsClose(ws)                             // 发送关闭帧
```
