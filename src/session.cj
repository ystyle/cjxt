package cjxt

import std.collection.{HashMap, ArrayList}
import std.time.{DateTime, TimeZone}
import std.sync.{Mutex, ReadWriteLock}
import stdx.net.http.WebSocket
import opencj::ulid.*

public enum WsState {
    | Connecting | Connected | Disconnected
}

public class Session {
    let id: String
    var page: IComponent
    var tree: IComponent
    var path: String
    var wsState: WsState
    // 当前出站通道（服务端推送用：外部线程通过 App.pushUpdate 推补丁）
    // 连接建立时设置，断开时清空。承载方式由 PageSink 决定（WS / 宿主绑定缓冲），
    // 会话本身不再假定页面一定是一条 WebSocket 连接。
    var sink: ?PageSink
    // 会话级 handler 注册表：startSession/pushUpdate/applyNav 渲染后
    // 统一写入这里，listenLoop 分发 action/bind 也查这里——保证异步
    // pushUpdate 渲染出的新 handler（如会话列表删除按钮）不丢失。
    var handlers: HashMap<String, ActionHandler>
    // 初始化窗口：onMount 早于初始渲染（页面在那里注入 states），此时客户端还没拿到页面，
    // 补丁发出去也无处可施。窗口内**回调照常同步执行**（调用方依赖它改状态），
    // 只把补丁压住，等初始树发下去再补一次。
    var pushSuspended: Bool = false
    var pendingPatch: Bool = false

    // 挂起的 DOM 事务续体：txId → (results) -> PatchResult（dom_result 到达后由 listenLoop 调用）
    var pendingTx: HashMap<String, (HashMap<String, String>) -> PatchResult>
    // 命名引用注册表：ref 名 → 树路径（DOM 事务寻址用，每次渲染后 refreshRefs 重建）
    var refPaths: HashMap<String, String>
    var createdAt: Int64
    var lastActiveAt: Int64

    /**
     * 本会话的执行锁：串行化**本会话**的 handler 执行与渲染。
     *
     * 分类：**D 类**（会话执行序，见 `docs/concurrency-model.md`）。
     *
     * 为什么是每会话而不是全局一把：
     * cjxt 每条 WS 连接一个执行体，同一会话的消息本身是串行的；
     * 需要防的是"本会话的渲染"与"本会话的其它入口（推送合并、DOM 事务续体）"
     * 交叉写 `tree` / 组件订阅。**不同会话之间没有共享的可变渲染状态**
     * （渲染上下文是 ThreadLocal、订阅表各有锁、捕获也是 ThreadLocal），
     * 所以全局锁纯属过度保护，还会把多用户吞吐压成串行。
     *
     * 但有两处仍需**跨会话**协调，见 App 的 pushFlushLock / 说明：
     *   · 推送合并 flush 会一次处理若干会话；
     *   · 巡检回收会 dispose 任意会话的组件订阅。
     * 这两处按"各自要碰的会话集合"取锁，不靠单一全局锁。
     */
    let renderLock = Mutex()
    let context: HashMap<String, String>
    var states: HashMap<String, AppState>
    // 会话上下文视图（框架契约，每会话唯一）：默认实现 SessionContextState，
    // 或应用通过 App.sessionContext<T>(factory) 注册的实现。
    // 按接口类型持有即可，不需要按类型名索引（AppState 那套反射键是给任意多份状态用的）
    var sessionContext: Option<SessionContext>
    // 会话状态是否已初始化：initStates 的幂等判据。
    // 不能用 states.size == 0 判断——应用可能一个 AppState 都不注册
    var statesInitialized: Bool
    // HTTP 阶段守卫未通过时渲染的是登录页占位，WS 连接（令牌恢复）后需按 path 重渲
    var deferred: Bool
    // 首屏 HTML 内联的那棵树的指纹（HTTP 渲染时算）。WS 连上后若服务端待发树与它一致，
    // 说明客户端手上已经是最终形态 → 跳过整树下发（避免刚显示就整棵替换，丢焦点/滚动/
    // 客户端组件局部状态）。置空表示"没有可用的内联基线"，此时一律正常下发。
    var inlinedTreeHash: String
    // 已同步给前端的 token（登录/登出后 context["token"] 变化时触发 AuthMsg）
    var syncedToken: String
    // 进行中的 WS 二进制上传（单流：binary 帧无元数据，同一连接一个活跃上传）
    var upload: Option<UploadState>
    // 当前页面树上的组件：路径 → 组件实例（渲染时登记）。
    // 用途：① 换页/重渲时退订旧组件——旧组件仍订阅着共享信号，被标脏后会按
    //       旧路径把旧页面内容补丁进新页面；
    //      ② 补丁只认本会话当前树上的组件，别的会话的脏标记不得套用本树路径。
    var components: HashMap<String, Component>
    // 是否曾经建立过 WebSocket。区分「真实页面会话」与「一次性 HTTP 请求」
    // （如健康检查 curl /）：后者不会走 WS 关闭路径，必须用短 TTL 回收，
    // 否则每次请求都会留下一棵树永久驻留。
    var connected: Bool

    public init(id: String, page: IComponent, tree: IComponent) {
        this.id = id
        this.page = page
        this.tree = tree
        this.path = "/"
        this.wsState = WsState.Connecting
        this.sink = None
        this.handlers = HashMap<String, ActionHandler>()
        this.pendingTx = HashMap<String, (HashMap<String, String>) -> PatchResult>()
        this.refPaths = HashMap<String, String>()
        this.createdAt = nowMillis()
        this.lastActiveAt = nowMillis()
        this.context = HashMap<String, String>()
        this.states = HashMap<String, AppState>()
        this.sessionContext = None
        this.statesInitialized = false
        this.deferred = false
        this.inlinedTreeHash = ""
        this.syncedToken = ""
        this.upload = None
        this.components = HashMap<String, Component>()
        this.connected = false
    }

    /// 是否曾经建立过 WebSocket（决定回收用长 TTL 还是短 TTL）
    public func everConnected(): Bool {
        this.connected
    }

    /**
     * 该组件是否属于本会话**当前**页面树（按路径查到的实例是不是它自己）。
     * 旧页面的组件即使路径与新页面某节点相同，实例也不同 → 不归本树。
     */
    public func ownsComponent(c: Component): Bool {
        match (this.components.get(c.getPath())) {
            case Some(cur) => cur.uid() == c.uid()
            case None => false
        }
    }

    /// 整页渲染后登记组件归属：不在本轮渲染结果里的旧组件全部退订作废
    public func adoptPageComponents(captured: ArrayList<Component>): Unit {
        this.adoptComponents(captured, "", true)
    }

    /// 子树补丁渲染后登记组件归属：只作废该子树路径下的旧组件
    /// （rootPath 为空 = 根组件重渲，渲染结果覆盖整棵树，按整页处理）
    public func adoptSubtreeComponents(rootPath: String, captured: ArrayList<Component>): Unit {
        this.adoptComponents(captured, rootPath, rootPath == "")
    }

    private func adoptComponents(captured: ArrayList<Component>, rootPath: String, wholePage: Bool): Unit {
        let keep = HashMap<Int64, Bool>()
        for (c in captured) { keep[c.uid()] = true }
        let stalePaths = ArrayList<String>()
        for ((p, old) in this.components) {
            if (keep.contains(old.uid())) { continue }
            if (wholePage || p == rootPath || p.startsWith("${rootPath}/")) {
                old.dispose()
                stalePaths.add(p)
            }
        }
        for (p in stalePaths) { this.components.remove(p) }
        this.registerComponents(captured)
    }

    // 登记本轮渲染出的组件：同路径的旧实例（组件实例不跨渲染复用）立即退订作废
    private func registerComponents(captured: ArrayList<Component>): Unit {
        for (c in captured) {
            match (this.components.get(c.getPath())) {
                case Some(prev) => if (prev.uid() != c.uid()) { prev.dispose() }
                case None => ()
            }
            this.components[c.getPath()] = c
        }
    }

    public func touch(): Unit {
        this.lastActiveAt = nowMillis()
    }

    /// 标记该会话已建立 WebSocket（此后按长 TTL 回收）。
    /// 与 `wsState = Connected` 同步调用，避免两处状态漂移。
    public func markConnected(): Unit {
        this.wsState = WsState.Connected
        this.connected = true
        this.touch()
    }

    /// 从会话树重建 handler 注册表（startSession/resumeSession/
    /// pushUpdate/applyNav 渲染后调用——统一写入会话级 handlers，
    /// 保证 listenLoop 分发 action/bind 时能看到全部 handler）。
    // 从树收集 data-ref → 路径（DOM 事务寻址）
    public func refreshRefs(tree: IComponent): Unit {
        this.refPaths.clear()
        collectRefsFromTree(tree, "", this.refPaths)
    }

    public func refreshHandlers(tree: IComponent): Unit {
        this.handlers.clear()
        RenderContext.collectHandlersFromTree(tree, this.handlers)
    }

    public func updatePage(page: IComponent, tree: IComponent): Unit {
        this.page = page
        this.tree = tree
        this.touch()
    }

    /**
     * 会话页面组件实例（外部模块访问用，如 harness 事件桥）
     */
    public func getPage(): IComponent {
        this.page
    }

    /**
     * 会话当前出站通道（外部模块访问用，如服务端推送）。
     * 需要底层 WS 连接（读取/心跳等 WS 专属路径）时用 `getWebSocket()`。
     */
    public func getSink(): ?PageSink {
        this.sink
    }

    /**
     * 底层 WebSocket（仅 WS 承载下非空）。
     * WS 专属操作（读帧、pong、closeConn）走这里，其余下发路径一律用 sink。
     */
    public func getWebSocket(): ?WebSocket {
        match (this.sink) {
            case Some(s: WebSocketSink) => Some(s.underlying())
            case _ => None
        }
    }

    /** `getWebSocket()` 的旧名（跨包接缝，保留兼容） */
    public func getWs(): ?WebSocket {
        this.getWebSocket()
    }

    /**
     * 会话上下文只读快照（uid/username/isAdmin/token 等）。
     * 返回**副本**：外部模块可读，但改副本不影响会话（防外部篡改鉴权态）；
     * 渲染期请用 `SessionContextState`（响应式，变化会触发重渲）。
     */
    public func getContext(): HashMap<String, String> {
        let c = HashMap<String, String>()
        for ((k, v) in this.context) {
            c[k] = v
        }
        c
    }

    /// 是否已过期。`ttlMillis <= 0` 表示**立即过期**（用于「一次性请求的会话用完即回收」
    /// 这类语义，也让边界可测：否则 `now - lastActive > 0` 在同一毫秒内恒为 false）。
    public func isExpired(ttlMillis: Int64): Bool {
        if (ttlMillis <= 0) { return true }
        nowMillis() - this.lastActiveAt > ttlMillis
    }
}

// 会话表分片。
//
// 分类：**C 类**（会话拓扑，见 `docs/concurrency-model.md`）。
//
// 每片自带一把 ReadWriteLock 与一张表：读（查找/统计）走读锁可并发，
// 写（建/删/回收）走写锁独占**本片**。会话 id 是 ulid（高位是时间戳、
// 低位随机），取低位做分片能均匀打散。
class SessionShard {
    let rw = ReadWriteLock()
    let table = HashMap<String, Session>()

    public init() {}

    func add(id: String, s: Session): Unit {
        synchronized(rw.writeLock) {
            table.add(id, s)
        }
    }

    func get(id: String): Option<Session> {
        synchronized(rw.readLock) {
            table.get(id)
        }
    }

    func remove(id: String): Unit {
        synchronized(rw.writeLock) {
            table.remove(id)
        }
    }

    func size(): Int64 {
        synchronized(rw.readLock) {
            Int64(table.size)
        }
    }

    func allIds(): ArrayList<String> {
        synchronized(rw.readLock) {
            let ids = ArrayList<String>()
            for ((id, _) in table) { ids.add(id) }
            ids
        }
    }

    func removeAll(): Unit {
        synchronized(rw.writeLock) {
            table.clear()
        }
    }

    // 回收本片的过期会话。遍历 + 删除都在**同一把写锁**内完成，
    // 不会出现「边遍历边改表」。
    func sweep(ttlMillis: Int64, detachedTtlMillis: Int64): Int64 {
        synchronized(rw.writeLock) {
            let expired = ArrayList<String>()
            for ((id, session) in table) {
                let ttl = match (session.wsState) {
                    case WsState.Connected => continue
                    case WsState.Disconnected => ttlMillis
                    case WsState.Connecting =>
                        if (session.everConnected()) { ttlMillis } else { detachedTtlMillis }
                }
                if (session.isExpired(ttl)) { expired.add(id) }
            }
            for (id in expired) { table.remove(id) }
            Int64(expired.size)
        }
    }
}

/**
 * 会话表：按 id 分片，每片一把 ReadWriteLock。
 *
 * 分类：**C 类**（见 `docs/concurrency-model.md` 的总表与判据）。
 *
 * ## 为什么分片而不是单锁 / 不用 Go 式 Hub
 *
 * 会话表被三类执行体并发访问：HTTP 请求（`create`）、WS 连接（`get`/`remove`）、
 * 巡检（`cleanup` 遍历+删除）。裸 `HashMap` 在「一边遍历一边增删」下行为未定义，
 * 实测会让进程**卡死**（迭代器在扩容/搬移中迷路）或 SIGSEGV。
 *
 * Go 的 hub 模式（单 goroutine 独占 map + channel 投递）在仓颉上不成立：
 * 标准库没有 `Channel`，只能自建「投递 → 等回传 → 被唤醒」机制，而实测该往返
 * 是 1130–1610 ns/次；会话查找处在每次 WS 消息的热路径上，不该付这个代价
 * （数据见 chan-bench-cj/docs/patterns.md §5，其"反模式"表也明确列了用队列传任务）。
 *
 * 采用分片 + 每片读写锁（同 patterns 模式 D：多消费者各用私有结构，
 * 比共享单锁快约 1.5x，且天然没有惊群/唤醒错人）：
 *   · 读读并发：不同会话的查找互不阻塞；
 *   · 写只锁一片：建会话不阻塞查别的片；
 *   · `cleanup` 各片独立回收，无跨片锁顺序问题（代价：不是原子的全局快照，
 *     但"回收过期"本就允许这点误差）。
 */
public class SessionManager {
    // 16 片：读写冲突概率降到 1/16，同时片数不至于多到遍历成本变高
    static const SHARD_BITS: Int64 = 4
    static const SHARD_COUNT: Int64 = 16

    let shards: Array<SessionShard>
    let ttlMillis: Int64
    // 未建立 WebSocket 的会话（一次性 HTTP 请求，如健康检查）用更短的 TTL。
    // 这类会话不会走 WS 关闭路径（remove 只在 WS 断开时调用），若不单独回收
    // 就会长期驻留 —— 而每个会话持有一整棵渲染树（生产实测 ~338KB/会话），
    // 高频探活下会累积到撑爆堆（2026-10-16 忆时塔生产事故的根因）。
    let detachedTtlMillis: Int64

    public init(ttlMillis: Int64, detachedTtlMillis!: Int64 = 60000) {
        this.ttlMillis = ttlMillis
        this.detachedTtlMillis = detachedTtlMillis
        this.shards = Array<SessionShard>(SessionManager.SHARD_COUNT, { _ => SessionShard() })
    }

    // 会话 id 的高位是 ulid 时间戳（短时间内生成的 id 高位相同），
    // 取**低位**字符做分片才能打散到各片。
    func shardOf(id: String): SessionShard {
        if (id.size == 0) {
            return this.shards[0]
        }
        // 取最后 4 个字符当 16 进制（ulid 是 Crockford base32，这里只求均匀，不求精确）
        var h: Int64 = 0
        var n = 0
        var i = id.size - 1
        while (i >= 0 && n < 4) {
            h = h * 31 + Int64(UInt32(id[i]))
            i--
            n++
        }
        if (h < 0) { h = -h }
        this.shards[h % SessionManager.SHARD_COUNT]
    }

    public func create(page: IComponent, tree: IComponent): Session {
        let id = this.generateId()
        let session = Session(id, page, tree)
        this.shardOf(id).add(id, session)
        session
    }

    public func save(id: String, page: IComponent, tree: IComponent): Session {
        let session = Session(id, page, tree)
        this.shardOf(id).add(id, session)
        session
    }

    public func get(id: String): Option<Session> {
        this.shardOf(id).get(id)
    }

    public func remove(id: String): Unit {
        this.shardOf(id).remove(id)
    }

    /// 清空全部会话（服务器停止 / 测试清理用）
    public func clearAll(): Unit {
        for (s in this.shards) {
            s.removeAll()
        }
    }

    /// 回收过期会话（由 App 的后台巡检协程周期调用，也可手动调用）。
    ///
    /// 三类会话的判据（详见 `SessionShard.sweep`）：
    /// 1. **当前仍连着**（`wsState == Connected`）：**永不回收**。不能按 lastActiveAt 判 ——
    ///    用户开着页面只读不动（不发消息）时 lastActiveAt 不更新，按时间判会误杀活跃会话。
    /// 2. **曾连接、现已断开**：ttlMillis。客户端断线后每 3s 自动重连（复用同一 sessionId），
    ///    故必须留宽限期；超过宽限仍未回来（关页面/刷新后不再回来）即可回收。
    /// 3. **从未连接**（一次性 HTTP 请求，如健康检查 curl /）：detachedTtlMillis，
    ///    这类请求不会走 WS 关闭路径，必须靠短 TTL 回收。
    ///
    /// 各片独立回收：每片在自己的写锁内完成「遍历 + 删除」，互不干扰。
    public func cleanup(): Int64 {
        var total: Int64 = 0
        for (s in this.shards) {
            total += s.sweep(this.ttlMillis, this.detachedTtlMillis)
        }
        total
    }

    /// 当前会话数（监控/测试用）
    public func size(): Int64 {
        var n: Int64 = 0
        for (s in this.shards) {
            n += s.size()
        }
        n
    }

    public func generateId(): String {
        nextId()
    }
}

func nowMillis(): Int64 {
    DateTime.nowUTC().toUnixTimeStamp().toMilliseconds()
}
