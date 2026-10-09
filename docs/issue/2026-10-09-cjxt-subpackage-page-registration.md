# cjxt：子包里的 `@Page` 静默失效（子包未进链接图 → 包初始化不执行，路由 404 且无任何报错）

- **仓库**：`cjxt`（1.1.0）／涉及 `cjpm` 的链接与包初始化语义
- **发现于**：把 `cjreg` 的 `ui` 包按站点面拆成子目录（`src/ui/public/`、`src/ui/admin/`）
- **严重度**：高 —— 失败模式是**静默 404**：编译通过、没有任何警告，只是页面消失
- **根因（2026-10-09 实测复核）**：cjpm 只链接「从根包 import 可达」的包；未被引用的子包
  不进链接图，其包初始化不执行。**不是**"链接了但没初始化"——详见下文「结论」

## 现象

`@Page` 是宏，注册代码落在**定义它的那个包**里（宏展开成对该包内 `RouteRegistry.global().register(...)` 的调用）。
当页面文件被移进子目录（= 子包）后，如果没有任何包 import 它：

| 检查 | 结果 |
|---|---|
| `cjpm build` | ✅ 成功，无警告 |
| 二进制符号（`nm -C target/release/bin/ystyle::cjreg \| grep -ci probe`） | ✅ 173 处命中 —— **假证据**：这来自本仓既有的"上游连通性探测"功能（`upstream_probe.cj`），与页面无关；按本最小复现实测未 import 时为 **0**。详见下文「结论」 |
| 运行时 `curl /probe-subpkg` | ❌ **404** |

加一行引用后立刻正常：

```cangjie
// src/main.cj
import ystyle::cjreg.ui.*
import ystyle::cjreg.ui.probe.*   // ← 只加这一行
```

→ `curl /probe-subpkg` 返回 **200**，页面正常渲染。

## 最小复现

```shell
mkdir -p src/ui/probe
cat > src/ui/probe/probe_page.cj <<'EOF'
package ystyle::cjreg.ui.probe

import cjxt.*
import cjxt.macros.*
import cjxt.components.*

@Page["/probe-subpkg"]
class ProbeSubPkgPage <: Component {
    public init() {}

    public func render(): IComponent {
        div([text("probe-subpkg-ok")])
    }
}
EOF

cjpm build -j 16
./target/release/bin/ystyle::cjreg serve -d <数据目录> -p 18099 &
curl -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18099/probe-subpkg   # 404
```

再在 `src/main.cj` 里加 `import ystyle::cjreg.ui.probe.*`、重新构建，同样的 `curl` 得到 **200**。

## 期望行为

> 注：本节与下节「可能的方向」写于**根因未查清时**，其中的前提（"子包既然被编译并链接进了产物"、
> "包被链接但 `cjinit` 不执行"）已被实测**证伪** —— 未引用的子包**根本没进链接图**。
> 保留原文以便对照，结论以下文「结论」节为准。

二者其一即可：

1. **子包里的 `@Page` 也能注册**（推荐）—— 子包既然被编译并链接进了产物，其包初始化就应当执行；
2. 或者**报出来**：编译期/启动期给出"该包含 `@Page` 但未被引用、页面不会注册"的提示，别让它在运行时变成 404。

## 可能的方向（供参考，未验证）

1. **cjxt 侧**：让 `@Page` 宏不只写本包的注册调用，同时把 `(路径, 工厂)` 汇总到一个**根包可见的清单**（例如宏在根包生成 `__cjxtPageRoutes()`，或提供一个 `pages()` 注册表由根包在启动时消费）。这样页面放哪个包都不影响注册。
2. **cjpm / 编译器侧**：确认"包被链接但 `cjinit` 不执行"是不是有意的——若包在产物里，静态初始化似乎理应执行；如果这是刻意优化（只初始化可达包），那么第 1 条就是 cjxt 该自己兜住的。
   *（实测：前提不成立，包没被链接。此条改为"cjpm 可否提示『已编译但未进链接图』"，见结论节末。）*
3. **使用侧规避**（cjreg 现在这么做）：拆包后必须在根包显式 `import` 每个含页面的子包，并加一条"路由清单"守卫（逐路由 HTTP 探测，404 即失败），防止后来者再踩。

## 结论（2026-10-09 实测复核，已修正原始判断）

**根因不是"包被链接但初始化没跑"，而是"这个包压根没被链接"。** 原文的三条方向里，第 2 条的
前提（"符号确实被链接进去了"）**不成立**，是取样失误。

### 实测证据

1. **失败现象可稳定复现**（无 cjxt 依赖的最小工程，`src/core/` + `src/a/` 两子包）：

   | 工程形态 | `Registry.global().size()` | `nm -C bin \| grep -c __reg` |
   |---|---|---|
   | `a` 子包无人 import | **0** | **0** |
   | 根包加一行 `import fc.a.*` | **1** | >0 |

2. **`nm \| grep -ci probe` 的那 173 处命中是假证据**：`cjreg` 本来就有"上游连通性探测"
   功能（`src/server/upstream_probe.cj` 等），符号名里天然带 `probe`。按原文最小复现
   （子包 `probe_page.cj`、类名 `ProbeSubPkgPage`）实测，未 import 时
   `nm -C bin | grep -ci probe` = **0**。**符号在不在二进制里，取决于包进没进链接图**。

3. **cjpm 的行为**：`src/` 下所有包都会被编译成 `lib<pkg>.a`（实测子包产物
   `libpagerepro.pages.a` 125 KB 确实生成），但**只有从根包 import 可达的包**才会以
   `-l<pkg>` 出现在链接命令行上；不可达的子包根本不进链接图。用 `cjpm build -V` 抓
   真实链接行可核对：未 import 时没有 `-lpagerepro.pages`。

4. **不是"进了产物却不初始化"**：每个包有 `_CGP<pkg>iiHv` 初始化入口，**只有被链接进来的包
   才会被模块初始化链调用到**（实测可达包的 `_CGP...iiHv` 能在反汇编里找到 caller，
   而未被引用的包连符号都不在二进制里）。把子包 `.a` 用链接器参数
   `--whole-archive lib<pkg>.a --no-whole-archive` 强行塞进二进制后，
   `nm` 能查到 12 个 `ProbeSubPkgPage` 符号，**但运行时注册依然为 0** ——
   符号在、初始化仍不执行。所以**不能拿 `nm` 判定链接成功**，判据要取运行时路由表
   （`RouteRegistry.global().create(path).isSome()` 或直接 HTTP 探测）。

### 可行的解决路径

**① 使用侧显式 import（立即可用，cjreg 已在用）** —— 纯 `import` 足够，**不需要调用任何函数**：
实测"只 import、绝不调用该包任何函数"时 registry 仍为 1，因为 import 让包进入依赖链，
链接器会拉入该包并执行其初始化。这是当前唯一零成本、确定有效的做法。

**② 构建前自动生成 import（推荐给 cjxt 使用方，已验证可行）** —— 扫描 `src/` 下所有含 `@Page`
的包，在根包生成一个只含 import 的聚合 `.cj`（如 `src/page_packages.cj`）。实测有效：多子包
（`ui/admin`、`ui/public`、`feature/deep`）全部由 404 转为可达（真实 cjxt 工程实测路由数 1 → 3）。
要点：

- **两种触发方式**：① 存成 `scripts/gen-page-imports.sh` 手动/CI 调用；② 挂到 cjpm `build.cj`
  的 `pre-build` 钩子（在编译源码**之前**执行，生成物会被正常纳入编译）。
- **推荐把生成物提交进 git**（而非只在钩子里临时生成）：IDE / LSP 能正常索引、review 时
  「新页面忘了加进来」看得见。配一个 `--check` 模式在 CI 校验生成物是否最新（过期退出码 1）。
- 中间层目录（如 `src/ui/`）**必须有 `.cj` 文件**，否则 cjpm 报
  "there is no '.cj' file in directory ... its subdirectories will not be scanned"，子包直接不参与编译。
- **可直接复制的脚本 + `--check` 用法**见 `docs-site/docs/basics/routing.md` 的
  「把页面放进子包」节（该脚本已在真实 cjxt 工程端到端验证）。

**③ cjxt 侧无法自动修复；只能给"可能失效"的启发式告警（建议放弃方向 1）** —— 三个硬约束：

- **宏不能生成 `import`**：仓颉要求 import 必须在包声明之后、其他声明之前；宏展开体插在
  顶层会报 `expected declaration, found keyword 'import'`（实测报错）。所以"宏顺带 import 根包"
  这条路走不通。
- **子包不能反向 import 模块根包**：`output-type = "executable"` 时，子包 import 根包会直接
  编译失败（实测 `package 'repro.a' imports root package 'repro' ..., but root package is not
  compiled as a lib`）。因此"子包注册时顺手把路由塞给根包"也没有通道。
- **宏能知道自己所在包的路径，但仍不知道是否被根包 import**：`getCommandLine()` 里的
  `-p <包目录>` 可解析出 `.../src/sub`（`embed-cj` 的 `getPackageRoot()` 就是这么做的，实测
  可用），所以"这个 `@Page` 在不在子包里"是可判定的；但编译是**按包**进行的，宏看不到
  整个模块的 import 图，"根包到底有没有 import 我"在宏里无从得知。
- 结论：方向 1（宏在根包生成 `__cjxtPageRoutes()`）**不可行**，是语言机制不允许；
  可行的最多是**启发式告警**——`@Page` 用 `diagReport(WARNING, ...)` 在"包路径 ≠ 模块根"
  时提示"本页位于子包，请确认根包已 import 该子包"（实测 `diagReport` 能出标准
  warning 格式）。代价：正确的用法也会被警告，噪音大，是否值得做成 cjxt 的开关由维护者定。

**④ 精确的"漏 import"检测只能在**构建/部署**侧做** —— 编译期做不到精确判定（编译器按包编译，
不掌握"根包该 import 谁"的意图）；运行期也做不到——框架**看不到那些根本未被链接的包**，
路由表非空时无从知道"少了几条"。因此真正能兜住"部分页面静默消失"的是 **HTTP 路由守卫**
（cjreg `scripts/check-routes.sh` 已实现：从源码抽全部 `@Page` 路径逐个探测，404 即失败），
或 ② 那种构建前生成 import 的做法从源头消除。附带的廉价兜底：`App.setupRoutes()` 启动时
若路由表为空，打一条明确日志（能覆盖"整体忘配"这种粗错）。

### 与 cjpm / 编译器侧的关系

不是 bug，是"按可达性链接"的正常语义（否则所有包都进产物，包初始化顺序与体积都不可控）。
值得向上游提的只有一条：**当 `src/` 下的包被编译成 `.a` 却未进链接图时，cjpm 可以提示**
"包 xxx 已编译但未被任何包引用，其包初始化不会执行"——这是 `cjpm build -V` 里已经能算出来的
信息，属体验改进，不是缺陷。

## cjreg 的落地做法

- `src/ui/` 拆成三层：根（框架层）、`public/`（公开端 + 用户门户）、`admin/`（管理端）；
- `src/main.cj` 显式 import 两个子包（附注释说明原因）；
- 新增路由守卫脚本：从源码抽出全部 `@Page` 路径，逐个 HTTP 探测，任一 404 即失败 —— 这样"漏 import 导致页面消失"会在检查里现形，而不是上线后才发现。
