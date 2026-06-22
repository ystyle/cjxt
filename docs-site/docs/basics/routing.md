# 路由系统

## @Page 宏注册

```cangjie
@Page["/"]
class HomePage <: Component { ... }

@Page["/about"]
class AboutPage <: Component { ... }
```

## 页面标题

```cangjie
@Page("/about", "关于我们")
class AboutPage <: Component { ... }
```

## 路由守卫

```cangjie
func adminGuard(ctx: HashMap<String, String>): Bool {
    match (ctx.get("role")) {
        case Some(r) => r == "admin"
        case None => false
    }
}

@Page("/admin", "管理后台", adminGuard)
class AdminPage <: Component { ... }
```

## 布局

```cangjie
func sidebarLayout(page: IComponent): IComponent {
    div([sidebar(), page])
}

@Page("/dashboard", "仪表盘", null, sidebarLayout)
class Dashboard <: Component { ... }
```

完整参数：`@Page(path, title?, guard?, layout?)`。

## 路由导航

```cangjie
ctx.route.push("/about")
// 或
Router.push("/about")
```

## 手动注册

```cangjie
let reg = RouteRegistry.global()
reg.register("/counter", { => CounterPage() })
reg.register("/admin", { => AdminPage() }, "管理后台", adminGuard)
reg.register("/dashboard", { => DashboardPage() }, "仪表盘", null, sidebarLayout)
```

## 路径匹配

`RouteRegistry` 使用精确路径匹配。对于动态路径，可通过 `RouteEntry` 手动解析：

```cangjie
let entry = RouteEntry("/user/[id]")
match (entry.doMatch("/user/123")) {
    case Some(params) =>
        let id = params.get("id")  // "123"
    case None => // 不匹配
}
```
