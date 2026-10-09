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
@Page["/about", "关于我们"]
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

@Page["/admin", "管理后台", adminGuard]
class AdminPage <: Component { ... }
```

## 布局

```cangjie
func sidebarLayout(page: IComponent): IComponent {
    div([sidebar(), page])
}

@Page["/dashboard", "仪表盘", null, sidebarLayout]
class Dashboard <: Component { ... }
```

完整参数：`@Page[path, title?, guard?, layout?]`。

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

## 把页面放进子包（务必读）

`@Page` 展开出的注册代码**落在定义它的那个包里**（`RouteRegistry.global().register(...)`）。而 `cjpm` 只把**从根包 import 可达**的包链进产物 —— 如果页面所在子包没有被任何包 import，它不会进入链接图，其包初始化不会执行，页面就**静默 404**：

- `cjpm build` 成功，**没有任何警告**；
- 二进制里连该页面的符号都没有；
- 访问该路由得到 404。

```bash
src/
├── main.cj             # package myapp        ← 根包
└── ui/
    ├── ui.cj           # package myapp.ui     ← 中间层必须有 .cj，否则子目录不被扫描
    ├── admin/
    │   └── page.cj     # package myapp.ui.admin
    └── public/
        └── page.cj     # package myapp.ui.public
```

上面这个结构里，`myapp.ui.admin` / `myapp.ui.public` 必须被 import 到，否则两个页面都不会注册。

### 方式一：根包显式 import（小型项目）

```cangjie
// src/main.cj
package myapp

import myapp.ui.*
import myapp.ui.admin.*    // ← 少了这行，/admin 就 404
import myapp.ui.public.*   // ← 少了这行，公开页就 404
```

**只要 `import` 就够，不需要调用该子包里的任何函数**：import 会让它进入链接图，包初始化随之执行。

> 链接需求是**模块级**的：只要有一个「会被链接的包」import 了它就行，不必非在根包。但根包是唯一必然被链接的包，把聚合点放在根包最省心，也最不容易漏。

### 方式二：构建前自动生成（子包多 / 频繁加页面，推荐）

手写的 import 清单会腐烂，而腐烂的表现是**静默 404**、不是报错。把清单交给脚本生成：存为 `scripts/gen-page-imports.sh`，扫描 `src/` 下所有含 `@Page` 的包，在根包生成聚合 import 文件。

```bash
#!/usr/bin/env bash
# 扫描 src/ 下所有含 @Page 的包，在根包生成聚合 import 文件。
# 作用：让含 @Page 的子包进入链接图 —— 否则其包初始化不执行，页面静默 404。
#
# 用法：
#   bash scripts/gen-page-imports.sh           # 生成/更新 src/page_packages.cj
#   bash scripts/gen-page-imports.sh --check   # 校验生成物是最新的（CI 用，过期退出码 1）
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$(sed -n 's/^name[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$ROOT/cjpm.toml" | head -1)"
[ -n "$MOD" ] || { echo "无法从 cjpm.toml 解析模块名" >&2; exit 1; }

OUT="$ROOT/src/page_packages.cj"
pkgs="$(grep -rl --include='*.cj' '@Page\[' "$ROOT/src" 2>/dev/null \
        | xargs -r grep -h -m1 '^package ' \
        | sed 's/^package[[:space:]]*//; s/[[:space:]]*$//' \
        | sort -u | grep -vx "$MOD" || true)"

render() {
  echo "// 由 scripts/gen-page-imports.sh 生成，请勿手改。"
  echo "// 作用：把含 @Page 的子包纳入链接图（否则其包初始化不执行，页面静默 404）。"
  echo "package ${MOD}"
  echo
  printf '%s\n' "$pkgs" | while IFS= read -r p; do
    [ -n "$p" ] && echo "import ${p}.*"
  done
}

if [ "${1:-}" = "--check" ]; then
  tmp="$(mktemp)"
  render > "$tmp"
  if ! cmp -s "$tmp" "$OUT"; then
    echo "✗ $OUT 已过期 —— 请运行 bash scripts/gen-page-imports.sh 后提交" >&2
    rm -f "$tmp"; exit 1
  fi
  rm -f "$tmp"
  echo "✓ $OUT 是最新的"
  exit 0
fi

render > "$OUT"
echo "已生成 $OUT"
```

生成的 `src/page_packages.cj` 形如：

```cangjie
// 由 scripts/gen-page-imports.sh 生成，请勿手改。
package myapp

import myapp.ui.admin.*
import myapp.ui.public.*
```

**把生成物提交进 git**（而不是只在构建钩子里临时生成）：这样 IDE / LSP 能正常索引，code review 时「新页面忘了加进来」也看得见。再在 CI 里加一道：

```bash
bash scripts/gen-page-imports.sh --check   # 生成物过期则失败
```

### 方式三：路由守卫（部署前兜底）

方式一、二都保证「清单正确」，但缓存、构建参数等原因仍可能让页面不通。最稳的兜底是从源码抽出全部 `@Page` 路径、逐条 HTTP 探测：

```bash
# 从源码提取路由
grep -rho '@Page\["[^"]*"' src | sed 's/@Page\["//; s/"$//' | sort -u
# 逐条 curl，任一 404 即失败
```

### 两个容易踩的判断错误

- **不要用 `nm` / 符号表判断页面有没有注册**。未 import 的子包根本不在链接图里，其符号**不在**二进制中；反过来，即使符号在（比如借助 `--whole-archive` 强行塞入 `.a`），包初始化**依然不会执行**。判据要取运行时路由表（`RouteRegistry.global().create(path).isSome()`）或直接 HTTP 探测。
- **中间层目录必须有 `.cj` 文件**。上例中若缺 `src/ui/ui.cj`，`cjpm` 会提示 `there is no '.cj' file in directory 'src/ui', and its subdirectories will not be scanned`，其下所有子包直接不参与编译。
