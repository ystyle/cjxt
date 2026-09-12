// 会话上下文的响应式视图（uid / username / isAdmin / token …）
//
// 背景：`Session.context` 是鉴权权威存储（路由守卫与 `ActionContext.getContext()`
// 读的都是它），但它是一个裸 HashMap——渲染期读不到（`LifecycleContext` 不带它），
// 变化也无法订阅（登录 / 令牌恢复写完之后没人知道）。
//
// 本类型把它接进既有的「每会话 AppState」通道：与 `Session.context` 共享同一个
// HashMap 引用，另外挂一个 `Signal<Int64>` 版本号。读 key 时先读版本号 → 在 render
// 作用域内自动建立依赖；写入方（`ActionContext.setContext` / 令牌恢复 bump）写完后
// 版本 +1 → 订阅它的页面被标脏 → 走标准重渲染/补丁链路。
//
// 页面用法（渲染期判断"登录后才显示管理入口"这类需求）：
//   onMount: this.sctx = Some(ctx.getState<SessionContextState>())
//   render:  this.sctx.getOrThrow().isAdmin()
// 注意必须在 render() 里读，不要只在 onMount 里缓存成普通字段——令牌恢复后的
// 就地重渲（App.rerenderInPlace）不会重跑 onMount。
package cjxt

import std.collection.HashMap
import std.convert.*
import std.reflect.*

public class SessionContextState <: AppState {
    // 与 Session.context 共享同一实例（HashMap 是引用类型）：读写都落到会话上
    let data: HashMap<String, String>
    // 版本号：任何写入都 +1，驱动订阅者（页面组件）重渲染
    let version: Signal<Int64>

    public init(data: HashMap<String, String>) {
        this.data = data
        this.version = Signal<Int64>(0)
    }

    /// 状态注册键（与 LifecycleContext / ActionContext 的 getState<T> 反射键一致）
    public static func stateKey(): String {
        TypeInfo.of<SessionContextState>().qualifiedName
    }

    /// 读取上下文值。在 render 作用域内调用会订阅版本变化（上下文变更 → 重渲）
    public func get(key: String): Option<String> {
        this.version.get()
        this.data.get(key)
    }

    public func has(key: String): Bool {
        this.get(key).isSome()
    }

    /// 是否已登录的管理员（登录/令牌恢复写 isAdmin=1；登出写空串）
    public func isAdmin(): Bool {
        match (this.get("isAdmin")) {
            case Some(v) => v == "1"
            case None => false
        }
    }

    /// 当前用户 id（未登录 / 非法值返回 0）
    public func uid(): Int64 {
        let raw = match (this.get("uid")) {
            case Some(v) => v
            case None => return 0
        }
        match (Int64.tryParse(raw)) {
            case Some(n) => n
            case None => 0
        }
    }

    /// 当前用户名（未登录返回空串——框架不替业务编造默认值）
    public func username(): String {
        match (this.get("username")) {
            case Some(v) => v
            case None => ""
        }
    }

    /// 当前会话令牌（未登录返回空串）
    public func token(): String {
        match (this.get(TOKEN_KEY)) {
            case Some(v) => v
            case None => ""
        }
    }

    /// 上下文快照（副本，不建立订阅；供外部模块 / 日志读取）
    public func snapshot(): HashMap<String, String> {
        let c = HashMap<String, String>()
        for ((k, v) in this.data) {
            c[k] = v
        }
        c
    }

    /// 订阅上下文变化（返回订阅 id，可用 unsubscribe 退订）
    public func subscribe(fn: () -> Unit): Int64 {
        this.version.subscribe(fn)
    }

    // ---- 框架内部写入（应用请走 ActionContext.setContext / 令牌恢复钩子）----

    /// 单键写入 + 通知订阅者
    func write(key: String, value: String): Unit {
        this.data[key] = value
        this.bump()
    }

    /// 批量写入 + 通知订阅者（只 bump 一次，避免多次重渲）
    func writeAll(m: HashMap<String, String>): Unit {
        for ((k, v) in m) {
            this.data[k] = v
        }
        this.bump()
    }

    /// 通知订阅者（版本 +1）。不标 private：同包写入路径共用
    func bump(): Unit {
        this.version.update({ n => n + 1 })
    }
}

/// 从会话状态表取上下文状态并通知订阅者；未注册（测试态 / 未初始化会话）时 no-op。
/// `ActionContext.setContext` 与 App 的令牌恢复共用这一处，避免两边语义漂移。
func notifySessionContext(states: HashMap<String, AppState>): Unit {
    match (states.get(SessionContextState.stateKey())) {
        case Some(s) =>
            match (s) {
                case scs: SessionContextState => scs.bump()
                case _ => ()
            }
        case None => ()
    }
}
