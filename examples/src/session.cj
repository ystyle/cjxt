// 用户会话管理完整示例（文档《会话与 WebSocket》配套，可直接跑）
//
// 覆盖一条完整主线：
//   登录（表单校验 + 回车提交）→ 写会话上下文 → 路由守卫 → 按角色渲染
//   → 操作级权限校验 → 刷新带 token 恢复 → 切换账号 / 登出
//
// 三个示例账号（密码均为 123456）：
//   admin  / 系统管理员（admin）—— 全部操作
//   editor / 内容编辑（editor）—— 可编辑资料，不可用户管理
//   viewer / 只读访客（viewer）—— 只能看
//
// 关键约定：渲染期判断登录态/角色必须读 SessionContext（并在 render() 里读，
// 不要只在 onMount 缓存快照）；Session.context 才是鉴权权威，UI 隐藏按钮不算安全。
// 本示例还把默认的 SessionContextState 换成了自定义实现 SessionDemoContext。
package examples

import cjxt.*
import cjxt.macros.*
import cjxt.components.*
import examples.showcase.*
import std.collection.{HashMap, ArrayList}

// ==================== 角色与示例用户表 ====================

public enum DemoRole {
    | Admin | Editor | Viewer
}

func roleName(r: DemoRole): String {
    match (r) {
        case DemoRole.Admin => "admin"
        case DemoRole.Editor => "editor"
        case DemoRole.Viewer => "viewer"
    }
}

func isAdminRole(r: DemoRole): Bool {
    match (r) {
        case DemoRole.Admin => true
        case _ => false
    }
}

func parseRoleName(v: String): DemoRole {
    match (v) {
        case "admin" => DemoRole.Admin
        case "editor" => DemoRole.Editor
        case _ => DemoRole.Viewer
    }
}

// 角色权重：操作级校验用（admin 3 > editor 2 > viewer 1 > 未登录 0）
func roleRank(name: String): Int64 {
    if (name == "admin") { return 3 }
    if (name == "editor") { return 2 }
    if (name == "viewer") { return 1 }
    0
}

public struct DemoUser {
    let id: Int64
    let username: String
    let password: String
    let role: DemoRole
    let title: String

    public init(id: Int64, username: String, password: String, role: DemoRole, title: String) {
        this.id = id
        this.username = username
        this.password = password
        this.role = role
        this.title = title
    }
}

// 示例用内存用户表（真实项目查库，并校验用户仍启用）
let demoUsers: Array<DemoUser> = [
    DemoUser(1, "admin", "123456", DemoRole.Admin, "系统管理员"),
    DemoUser(2, "editor", "123456", DemoRole.Editor, "内容编辑"),
    DemoUser(3, "viewer", "123456", DemoRole.Viewer, "只读访客"),
]

func findDemoUser(name: String): Option<DemoUser> {
    for (u in demoUsers) {
        if (u.username == name) { return Some(u) }
    }
    None
}

// 把用户写成会话上下文（守卫、操作级校验、渲染期读的都是它）
func demoContext(u: DemoUser): HashMap<String, String> {
    let m = HashMap<String, String>()
    m["uid"] = u.id.toString()
    m["username"] = u.username
    m["role"] = roleName(u.role)
    m["isAdmin"] = if (isAdminRole(u.role)) { "1" } else { "0" }
    m
}

// ==================== 会话上下文：换成应用自己的实现 ====================
//
// 框架默认用 SessionContextState；这里演示换实现：
//   - 保留默认行为（get 里读版本信号 → 渲染期自动订阅；onContextChanged 里通知）
//   - 加类型化角色属性 role（接口只约定 get/isAdmin/uid/username/token）
//   - 加上下文变更审计（onContextChanged 钩子：登录 / 登出 / 令牌恢复都会触发）
// 注册方式见 entry.cj：.sessionContext<SessionDemoContext>({ m => SessionDemoContext(m) })
public class SessionDemoContext <: SessionContext {
    let data: HashMap<String, String>
    let version: Signal<Int64>
    // 上下文变更次数（自定义审计）
    var changes = Signal<Int64>(0)

    public init(data: HashMap<String, String>) {
        this.data = data
        this.version = Signal<Int64>(1)
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

    public func onContextChanged(): Unit {
        this.version.update({ n => n + 1 })
        this.changes.update({ n => n + 1 })
    }

    public func subscribe(fn: () -> Unit): Int64 {
        this.version.subscribe(fn)
    }

    /// 自定义扩展：类型化角色（调换角色名 → 枚举）
    public prop role: DemoRole {
        get() {
            match (this.get("role")) {
                case Some(v) => parseRoleName(v)
                case None => DemoRole.Viewer
            }
        }
    }
}

// ==================== 令牌校验钩子（App.auth 注册）====================

// 真实项目：验签 + 查库 + 校验用户存在且启用；示例令牌格式 "demo:<username>"
public func validateDemoToken(token: String): Option<HashMap<String, String>> {
    let prefix = "demo:"
    if (!token.startsWith(prefix)) {
        return None
    }
    let name = token[prefix.size..token.size]
    match (findDemoUser(name)) {
        case Some(u) => Some(demoContext(u))
        case None => None
    }
}

// ==================== 页面守卫 ====================

// 未登录 → 登录页。GuardFn 拿到的就是会话上下文 HashMap（框架传引用）
public func requireLogin(ctx: HashMap<String, String>): Option<String> {
    match (ctx.get("uid")) {
        case Some(v) => if (v == "") { Some("/session/login") } else { None }
        case None => Some("/session/login")
    }
}

// ==================== 会话读写工具（服务端权威侧）====================

func sessionRole(ctx: ActionContext): String {
    match (ctx.getContext().get("role")) {
        case Some(v) => v
        case None => ""
    }
}

// 操作级权限校验：UI 隐藏按钮只是体验，真正的拦截在这里
func allowAtLeast(ctx: ActionContext, need: String): Bool {
    roleRank(sessionRole(ctx)) >= roleRank(need)
}

// 登录：写会话上下文 + 令牌（框架自动把 token 同步给前端 localStorage）
func loginAs(ctx: ActionContext, u: DemoUser): Unit {
    for ((k, v) in demoContext(u)) {
        ctx.setContext(k, v)
    }
    ctx.setContext(TOKEN_KEY, "demo:${u.username}")
}

// 登出：清空上下文（token 清空后框架会通知前端删掉 localStorage 里的令牌）
func clearSession(ctx: ActionContext): Unit {
    for (k in ["uid", "username", "role", "isAdmin", TOKEN_KEY]) {
        ctx.setContext(k, "")
    }
}

// ==================== 会话级应用状态（每会话一份）====================

public class SessionDemoState <: AppState {
    // 登录表单（bind 到 Input）
    var username = Signal<String>("")
    var password = Signal<String>("")
    // 操作反馈
    var notice = Signal<String>("登录前请先看说明：三个示例账号密码均为 123456")
    var noticeKind = Signal<String>("info")

    public func setNotice(msg: String, kind: String): Unit {
        this.notice.set(msg)
        this.noticeKind.set(kind)
    }

    public func noticeAlertKind(): AlertKind2 {
        if (this.noticeKind.get() == "success") { return AlertKind2.Success }
        if (this.noticeKind.get() == "error") { return AlertKind2.Error }
        if (this.noticeKind.get() == "warning") { return AlertKind2.Warning }
        AlertKind2.Info
    }
}

// ==================== 1. 公开首页：按登录态渲染入口 ====================

@Page["/session", "会话示例"]
class SessionHomePage <: Component {
    var state: Option<SessionDemoState> = None
    var sctx: Option<SessionContext> = None

    public func onMount(ctx: LifecycleContext): Unit {
        this.state = Some(ctx.getState<SessionDemoState>())
        // 面向接口取用：换成自己的实现也不必改页面代码
        this.sctx = ctx.getSessionContext()
    }

    // 在 render() 里读上下文：令牌恢复后的就地重渲不重跑 onMount
    func ctxOf(): SessionContext {
        match (this.sctx) {
            case Some(s) => s
            case None => throw Exception("会话上下文未注入")
        }
    }

    func textOf(key: String): String {
        match (this.ctxOf().get(key)) {
            case Some(v) => if (v == "") { "-" } else { v }
            case None => "-"
        }
    }

    func doLogout(ctx: ActionContext): PatchResult {
        clearSession(ctx)
        this.state.getOrThrow().setNotice("已登出：会话上下文已清空，前端令牌同步删除", "warning")
        ctx.route.push("/session")
        PatchResult.ReRender
    }

    public func render(): IComponent {
        let s = this.ctxOf()
        let logged = s.uid > 0
        let notice = this.state.getOrThrow()

        let actions = ArrayList<IComponent>()
        if (logged) {
            let goProfile: ActionHandler = { c =>
                c.route.push("/session/profile")
                PatchResult.ReRender
            }
            let goSwitch: ActionHandler = { c =>
                clearSession(c)
                notice.setNotice("请用另一个账号登录（admin / editor / viewer）", "warning")
                c.route.push("/session/login")
                PatchResult.ReRender
            }
            actions.add(Button([text("进入个人中心")]).kind(ButtonKind.Primary).onClick(goProfile))
            actions.add(Button([text("切换账号")]).onClick(goSwitch))
            actions.add(Button([text("登出")]).onClick(doLogout))
        } else {
            let goLogin: ActionHandler = { c =>
                c.route.push("/session/login")
                PatchResult.ReRender
            }
            actions.add(Button([text("去登录")]).kind(ButtonKind.Primary).onClick(goLogin))
        }

        let sessionRows = ArrayList<IComponent>()
        sessionRows.add(infoRow("登录态", if (logged) { "已登录" } else { "未登录（匿名会话）" }))
        sessionRows.add(infoRow("uid", this.textOf("uid")))
        sessionRows.add(infoRow("username", this.textOf("username")))
        sessionRows.add(infoRow("role", this.textOf("role")))
        // 自定义实现的扩展能力：向下转型拿审计计数（接口本身不约定它）
        let changes = match (this.sctx) {
            case Some(c) => match (c) {
                case d: SessionDemoContext => d.changes.get()
                case _ => 0
            }
            case None => 0
        }
        sessionRows.add(infoRow("上下文变更", "${changes} 次（自定义实现的审计钩子）"))

        div([
            renderTabs("/session"),
            div([
                div([text("会话与权限示例")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
                Alert()
                    .title("本页是公开页（无守卫）")
                    .description("HTTP 首屏没有凭据（token 在前端 localStorage），所以一定按「未登录」渲染；WS 连上并校验令牌后，框架会按新上下文就地重渲一次。下面是渲染期读 SessionContext（接口）的结果：")
                    .kind(AlertKind2.Info)
                    .showIcon(),
                div(sessionRows.toArray(), attrs: Some(HashMap<String, String>([("class", cls("card"))]))),
                div(actions.toArray(), attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
                Alert()
                    .title("操作反馈")
                    .description(notice.notice.get())
                    .kind(notice.noticeAlertKind())
                    .showIcon(),
                div([text("受保护页：/session/profile（页面守卫 requireLogin）；操作级校验在服务端 handler 里，UI 只隐藏按钮。")], attrs: Some(HashMap<String, String>([("class", cls("desc"))]))),
            ], attrs: Some(HashMap<String, String>([("class", cls("card"))]))),
        ], attrs: Some(HashMap<String, String>([("class", cls("container"))])))
    }
}

// 一行「标签 + 值」
func infoRow(label: String, value: String): IComponent {
    div([
        spanText(label, cls("label")),
        spanText(value, ""),
    ], attrs: Some(HashMap<String, String>([("class", cls("row"))])))
}

func spanText(v: String, extraCls: String): IComponent {
    let style = if (extraCls == "") { "flex:1" } else { "flex:0 0 96px;color:#909399" }
    VNode("span", [text(v)], attrs: Some(HashMap<String, String>([("style", style)])))
}

// ==================== 2. 登录页：写会话上下文 ====================

@Page["/session/login", "登录"]
class SessionLoginPage <: Component {
    var state: Option<SessionDemoState> = None
    var form = Form([])

    public func onMount(ctx: LifecycleContext): Unit {
        this.state = Some(ctx.getState<SessionDemoState>())
    }

    // 密码框回车提交（KeyEvent 由前端 keydown 委托回传）
    func onEnter(ctx: ActionContext): PatchResult {
        match (ctx.keyEvent) {
            case Some(ke) => if (ke.isEnter()) { return this.doLogin(ctx) }
            case None => ()
        }
        PatchResult.ReRender
    }

    func doLogin(ctx: ActionContext): PatchResult {
        let s = this.state.getOrThrow()
        if (this.form.validate()) {
            this.tryLogin(s, ctx)
        }
        PatchResult.ReRender
    }

    func tryLogin(s: SessionDemoState, ctx: ActionContext): Unit {
        match (findDemoUser(s.username.get())) {
            case Some(u) => this.loginUser(s, ctx, u)
            case None => s.setNotice("用户不存在。可用账号：admin / editor / viewer（密码均为 123456）", "error")
        }
    }

    func loginUser(s: SessionDemoState, ctx: ActionContext, u: DemoUser): Unit {
        if (u.password != s.password.get()) {
            s.setNotice("密码错误。示例密码均为 123456", "error")
            return
        }
        // 写会话上下文：守卫/操作级校验/渲染期读的都是它
        loginAs(ctx, u)
        s.setNotice("登录成功：${u.username}（${roleName(u.role)}，uid=${u.id}）", "success")
        ctx.route.push("/session/profile")
    }

    public func render(): IComponent {
        let s = this.state.getOrThrow()
        let form = Form([
            FormItem([Input().bind(s.username).placeholder("用户名：admin / editor / viewer")])
                .label("用户名")
                .bindValue({ => s.username.get() })
                .rule(FormRule(required: true, message: "请输入用户名")),
            FormItem([Input().bind(s.password).password().placeholder("密码：123456").on("keydown", onEnter)])
                .label("密码")
                .bindValue({ => s.password.get() })
                .rule(FormRule(required: true, message: "请输入密码")),
        ]).labelTop()
        this.form = form

        div([
            renderTabs("/session"),
            div([
                div([text("登录")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
                Alert()
                    .title("登录做了什么")
                    .description("ctx.setContext 写 uid/username/role/isAdmin + token（框架把 token 同步给前端 localStorage）；随后 route.push 跳转，守卫读到的就是刚写入的上下文。")
                    .kind(AlertKind2.Info)
                    .showIcon(),
                form,
                div([
                    Button([text("登 录")]).kind(ButtonKind.Primary).size(ButtonSize.Large).onClick(doLogin),
                ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
                Alert()
                    .title("提示")
                    .description(s.notice.get())
                    .kind(s.noticeAlertKind())
                    .showIcon(),
            ], attrs: Some(HashMap<String, String>([("class", cls("card"))]))),
        ], attrs: Some(HashMap<String, String>([("class", cls("container"))])))
    }
}

// ==================== 3. 受保护页：按角色渲染 + 操作级校验 ====================

@Page["/session/profile", "个人中心", requireLogin]
class SessionProfilePage <: Component {
    var state: Option<SessionDemoState> = None
    var sctx: Option<SessionContext> = None

    public func onMount(ctx: LifecycleContext): Unit {
        this.state = Some(ctx.getState<SessionDemoState>())
        this.sctx = ctx.getSessionContext()
    }

    func ctxOf(): SessionContext {
        match (this.sctx) {
            case Some(s) => s
            case None => throw Exception("会话上下文未注入")
        }
    }

    func textOf(key: String): String {
        match (this.ctxOf().get(key)) {
            case Some(v) => if (v == "") { "-" } else { v }
            case None => "-"
        }
    }

    // 操作级校验：即使按钮被前端伪造触发，服务端依然按上下文拒绝
    func auditOperation(ctx: ActionContext, label: String, need: String): Unit {
        let s = this.state.getOrThrow()
        if (allowAtLeast(ctx, need)) {
            s.setNotice("${label}：已执行（当前角色 ${sessionRole(ctx)}）", "success")
        } else {
            s.setNotice("${label}：拒绝——需要 ${need} 及以上权限，当前角色为「${sessionRole(ctx)}」", "error")
        }
    }

    func doEdit(ctx: ActionContext): PatchResult {
        this.auditOperation(ctx, "编辑资料", "editor")
        PatchResult.ReRender
    }

    func doManage(ctx: ActionContext): PatchResult {
        this.auditOperation(ctx, "用户管理", "admin")
        PatchResult.ReRender
    }

    func doLogout(ctx: ActionContext): PatchResult {
        clearSession(ctx)
        this.state.getOrThrow().setNotice("已登出", "warning")
        ctx.route.push("/session")
        PatchResult.ReRender
    }

    func doSwitch(ctx: ActionContext): PatchResult {
        clearSession(ctx)
        this.state.getOrThrow().setNotice("请用另一个账号登录", "warning")
        ctx.route.push("/session/login")
        PatchResult.ReRender
    }

    public func render(): IComponent {
        let s = this.ctxOf()
        let notice = this.state.getOrThrow()
        let role = this.textOf("role")

        // 按角色渲染（体验层）：admin ≥ editor ≥ viewer
        let actions = ArrayList<IComponent>()
        var gatedCount: Int64 = 0
        if (roleRank(role) >= roleRank("editor")) {
            actions.add(Button([text("编辑资料（editor+）")]).kind(ButtonKind.Primary).onClick(doEdit))
            gatedCount++
        }
        if (roleRank(role) >= roleRank("admin")) {
            actions.add(Button([text("用户管理（仅 admin）")]).kind(ButtonKind.Danger).onClick(doManage))
            gatedCount++
        }
        // 对所有角色可见：用于验证「UI 隐藏不算安全」——viewer 点它会被服务端拒绝
        actions.add(Button([text("模拟越权调用「用户管理」")]).onClick(doManage))
        actions.add(Button([text("切换账号")]).onClick(doSwitch))
        actions.add(Button([text("登出")]).onClick(doLogout))

        let rows = ArrayList<IComponent>()
        rows.add(infoRow("uid", this.textOf("uid")))
        rows.add(infoRow("username", this.textOf("username")))
        rows.add(infoRow("role", role))
        rows.add(infoRow("isAdmin", this.textOf("isAdmin")))

        div([
            renderTabs("/session"),
            div([
                div([text("个人中心（受守卫保护）")], attrs: Some(HashMap<String, String>([("class", cls("card-title"))]))),
                Alert()
                    .title("这个页面由页面守卫保护")
                    .description("@Page[\"/session/profile\", \"个人中心\", requireLogin]：未登录访问会被守卫拦到登录页；刷新页面时 HTTP 阶段没有凭据，先渲染登录页占位，WS 带上令牌校验通过后由框架重新渲染本页。")
                    .kind(AlertKind2.Success)
                    .showIcon(),
                div(rows.toArray(), attrs: Some(HashMap<String, String>([("class", cls("card"))]))),
                div(actions.toArray(), attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
                Alert()
                    .title("操作反馈（服务端权威）")
                    .description(notice.notice.get())
                    .kind(notice.noticeAlertKind())
                    .showIcon(),
                div([text("按角色裁剪的操作按钮：${gatedCount} 个；「模拟越权调用」按钮对所有角色可见，用来验证服务端二次校验（viewer 点击会被拒绝）。")], attrs: Some(HashMap<String, String>([("class", cls("desc"))]))),
            ], attrs: Some(HashMap<String, String>([("class", cls("card"))]))),
        ], attrs: Some(HashMap<String, String>([("class", cls("container"))])))
    }
}
