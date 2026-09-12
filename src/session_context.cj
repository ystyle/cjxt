// 会话上下文的响应式视图（uid / username / isAdmin / token …）
//
// 背景：`Session.context` 是鉴权权威存储（路由守卫与 `ActionContext.getContext()`
// 读的都是它），但它是一个裸 HashMap——渲染期读不到（`LifecycleContext` 不带它），
// 变化也无法订阅（登录 / 令牌恢复写完之后没人知道）。
//
// 本文件提供**一个接口 + 一个默认实现**：
//   - `SessionContext`：框架契约（只读视图 + 变化通知），应用可换成自己的实现；
//   - `SessionContextState`：默认实现，与 `Session.context` 共享同一个 HashMap 引用，
//     另挂 `Signal<Int64>` 版本号实现响应式。
//
// 每会话只有一个上下文，所以框架**按接口类型直接持有**（`Session.sessionContext`），
// 不走 `AppState` 那套按类型名索引的表——注册用泛型约束
// `App.sessionContext<T>(...) where T <: SessionContext` 即可，全程不需要反射。
//
// 注意边界：本接口抽象的是**视图与通知**，不是存储——权威存储始终是
// `Session.context`（守卫签名 / `ActionContext.getContext()` / `AuthHooks`
// 都是 HashMap）。自定义实现拿到的是同一个 map（工厂入参）。
//
// 页面用法（渲染期判断"登录后才显示管理入口"这类需求）：
//   onMount: this.sctx = ctx.getSessionContext()   // 面向接口，与具体实现解耦
//   render:  this.sctx.getOrThrow().isAdmin        // 属性读（无括号）
// 注意必须在 render() 里读，不要只在 onMount 里缓存成普通字段——令牌恢复后的
// 就地重渲（App.rerenderInPlace）不会重跑 onMount。
package cjxt

import std.collection.HashMap
import std.convert.*

/// 会话上下文视图（框架契约）。应用可实现本接口替换默认实现
/// （见 `App.sessionContext<T>(factory)`）；框架按本接口类型持有实例。
public interface SessionContext {
    // ==================== 必须实现的成员 ====================

    /// 读取上下文值。实现方应在此读取自己的响应式源（如版本信号）以建立订阅，
    /// 否则上下文变化不会触发页面重渲。
    func get(key: String): Option<String>

    /// 权威上下文（框架持有；约定只读，不要在这里写鉴权信息）
    prop raw: HashMap<String, String>

    /// 框架在上下文被写入后调用（登录 / 登出 / 令牌恢复）。响应式实现应在此通知
    /// 订阅者；不需要响应式的实现可以留空。
    func onContextChanged(): Unit

    /// 订阅上下文变化（返回订阅 id，可用于 unsubscribe）
    func subscribe(fn: () -> Unit): Int64

    // ==================== 默认实现（按需覆写） ====================

    func has(key: String): Bool {
        this.get(key).isSome()
    }

    /// 上下文快照（副本，不建立订阅；供日志 / 外部模块读取）
    func snapshot(): HashMap<String, String> {
        let c = HashMap<String, String>()
        for ((k, v) in this.raw) {
            c[k] = v
        }
        c
    }

    /// 是否已登录的管理员（登录/令牌恢复写 isAdmin=1；登出写空串）
    prop isAdmin: Bool {
        get() {
            match (this.get("isAdmin")) {
                case Some(v) => v == "1"
                case None => false
            }
        }
    }

    /// 当前用户 id（未登录 / 非法值返回 0）
    prop uid: Int64 {
        get() {
            let rawUid = match (this.get("uid")) {
                case Some(v) => v
                case None => return 0
            }
            match (Int64.tryParse(rawUid)) {
                case Some(n) => n
                case None => 0
            }
        }
    }

    /// 当前用户名（未登录返回空串——框架不替业务编造默认值）
    prop username: String {
        get() {
            match (this.get("username")) {
                case Some(v) => v
                case None => ""
            }
        }
    }

    /// 当前会话令牌（未登录返回空串）
    prop token: String {
        get() {
            match (this.get(TOKEN_KEY)) {
                case Some(v) => v
                case None => ""
            }
        }
    }

}

/// 默认实现：与 `Session.context` 共享同一 HashMap 引用 + 版本信号。
/// 应用不调用 `App.sessionContext(...)` 时框架自动使用本实现。
public class SessionContextState <: SessionContext {
    // 与 Session.context 共享同一实例（HashMap 是引用类型）：读写都落到会话上
    let data: HashMap<String, String>
    // 版本号：任何写入都 +1，驱动订阅者（页面组件）重渲染
    let version: Signal<Int64>

    public init(data: HashMap<String, String>) {
        this.data = data
        this.version = Signal<Int64>(0)
    }

    public func get(key: String): Option<String> {
        this.version.get()
        this.data.get(key)
    }

    public prop raw: HashMap<String, String> {
        get() {
            this.data
        }
    }

    /// 通知订阅者（版本 +1）
    public func onContextChanged(): Unit {
        this.version.update({ n => n + 1 })
    }

    public func subscribe(fn: () -> Unit): Int64 {
        this.version.subscribe(fn)
    }

    // ---- 框架内部写入（应用请走 ActionContext.setContext / 令牌恢复钩子）----

    /// 单键写入 + 通知订阅者
    func write(key: String, value: String): Unit {
        this.data[key] = value
        this.onContextChanged()
    }

    /// 批量写入 + 通知订阅者（只通知一次，避免多次重渲）
    func writeAll(m: HashMap<String, String>): Unit {
        for ((k, v) in m) {
            this.data[k] = v
        }
        this.onContextChanged()
    }
}

/// 通知会话上下文变化（框架写入路径调用）；未注入时 no-op。
/// `ActionContext.setContext` 与 App 的令牌恢复共用这一处，避免两边语义漂移。
func notifySessionContext(sc: Option<SessionContext>): Unit {
    match (sc) {
        case Some(c) => c.onContextChanged()
        case None => ()
    }
}
