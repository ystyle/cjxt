# 路由系统

## @Page 宏

编译期注册路由：

```cangjie
// 基础用法
@Page["/showcase"]
class ShowcasePage <: Component { ... }

// 完整参数
@Page("/admin", "管理后台", adminGuard, sidebarLayout)
class AdminPage <: Component { ... }
```

`@Page` 接收 4 个参数：

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| path | String | 是 | 路由路径（精确匹配） |
| title | String | 否 | 页面标题 |
| guard | `(HashMap<String,String>) -> Bool` | 否 | 路由守卫函数 |
| layout | `(IComponent) -> IComponent` | 否 | 布局函数 |

编译期展开为：

```cangjie
// @Page["/showcase"]
// ↓ 编译后追加：
let __reg_ShowcasePage = RouteRegistry.global().register(
    "/showcase", { => ShowcasePage() }
)
```

## RouteRegistry

单例模式，使用 HashMap 精确路径匹配：

```cangjie
let reg = RouteRegistry.global()

reg.register("/counter", { => CounterPage() })
reg.register("/admin", { => AdminPage() }, "管理后台", adminGuard)
reg.register("/profile", { => ProfilePage() }, "个人中心", null, sidebarLayout)
```

### 创建页面

```cangjie
match (reg.create("/order/123")) {
    case Some(page) => render(page)
    case None => notFound()
}
```

### 守卫

守卫是函数，接收会话上下文返回布尔值：

```cangjie
func adminGuard(ctx: HashMap<String, String>): Bool {
    match (ctx.get("role")) {
        case Some(r) => r == "admin"
        case None => false
    }
}

reg.register("/admin", { => AdminPage() }, "管理后台", adminGuard)
reg.checkGuard("/admin", session.context)
```

### 布局

```cangjie
let sidebarLayout: LayoutFn = { page =>
    div([sidebar(), page])
}

reg.register("/dashboard", { => DashboardPage() }, "仪表盘", null, sidebarLayout)
match (reg.getLayout("/dashboard")) {
    case Some(layout) => layout(page)
    case None => page
}
```

### 页面标题

```cangjie
let title = reg.getTitle("/about")  // → "关于我们"
```

## RouteEntry 手动路径匹配

对于动态路径参数，使用 `RouteEntry` 手动解析：

```cangjie
let entry = RouteEntry("/user/[id]/post/[postId]")
match (entry.doMatch("/user/123/post/456")) {
    case Some(params) =>
        let userId = params.get("id")       // "123"
        let postId = params.get("postId")   // "456"
    case None => // 不匹配
}
```

匹配规则：
- 字面段必须完全匹配
- `[name]` 段匹配任意值并捕获
- 段数必须一致

## 路由导航

```cangjie
ctx.route.push("/about")
// 或
Router.push("/about")
```

## 导航流程

```
handleNavigate → state.page.onUnmount()
              → RouteRegistry.create(path)
              → applyNav → newPage.onMount()
              → renderWithScope → fullTree
```
