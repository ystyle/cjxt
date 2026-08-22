# cjxt — 仓颉全栈服务端驱动 UI 框架

## 仓颉语言
- 语法问题使用 `cangjie_docs` 工具查找，不要猜 API 和语法（包括 `ArrayList.sort`、`JsonWriter.writeNull` 等看似显然的 API，都先查再写）
- 实现不确定的功能时，先在项目已有代码里 `grep` 查找相似用法，确认 API 存在和签名
- 每完成一个阶段任务，在 AGENTS.md 的「代码总结」节记录该阶段遇到的问题和学到的东西
- 在提示语法错误时使用 `cangjie-mem` 加载语言级记忆, 阶段总结时使用`cangjie-mem`项目级记录
- 包名声明使用 `.` 分隔：`package cjxt`、`package cjxt.macros`

## 要求
- 每次需要失败的用例，需要添加到单元测试里，沉淀下来

## Git 工作流
- 新功能从 master 创建分支：`git checkout -b feat/功能名`
- 开发中可随时提交，但**不推送**到远程
- 完成开发后，使用 squash merge 合并回 master，提交记录压缩为一条：
  ```bash
  git checkout master
  git merge --squash feat/功能名
  git commit -m "feat: 功能名 — 简述"
  git branch -D feat/功能名   # 删除本地分支
  git push origin master       # 推送到远程
  ```

## 组件实现流程

参照 Element Plus(本地: ~/Projects/element-plus/) 的属性、样式和事件来设计和实现组件。

### 步骤

1. **查 Element Plus 文档**：确认组件的 Props、Slots、Events 三个维度
2. **类型定义**：在 `src/components/Types.cj` 中定义该组件的参数枚举类型
3. **框架能力确认**：现有框架是否支持本次实现需要的所有特性？（事件、CSS、信号绑定等）
4. **实现组件**：`src/components/<Name>.cj`，class `<: Component`（改名后）
5. **CSS**：Element Plus SCSS `public/scss/element-plus/`，编译到 `public/css/element-plus.css`（`@EmbedString` 编译时嵌入）。CSS module 在 `examples/public/css/bundle.css`。构建顺序：**先** `bash scripts/build-css.sh` 编译 EP 样式，**再** `cd examples && cjpm build`（含生成 CSS module）。
6. **Showcase 演示**：`examples/src/showcase.cj` 添加组件演示
7. **浏览器测试**：启动演示服务 → `agent-browser` 验证交互

### 确认过的 Cangjie API

| API | 位置 | 用法 |
|-----|------|------|
| `Int64.parse(raw, radix: 10)` | `std.convert` | 带 radix 命名参数 |
| `ArrayList.sort(fn)` | `std.sort` | 传 `(T, T) -> Int64` 比较函数 |
| `JsonWriter.writeNullValue()` | `stdx.encoding.json.stream` | 直接输出 JSON null |

## 项目结构

```
src/
├── main.cj                 入口
├── vnode.cj                ComponentNode 数据模型 + 标签辅助函数
├── component.cj            Component 接口 / 生命周期定义
├── action.cj               ActionContext / PatchResult / Router
├── signal.cj               Signal<T> 响应式信号 + SignalTracker 自动追踪
├── store.cj                Store<S> 基于 Signal 的状态管理
├── css.cj                  CssModule 结构 + cssModule 辅助函数
├── config.cj               AppConfig 应用配置
├── diff.cj                 diff / patch 引擎（已废弃，待移除）
├── session.cj              会话管理 / TTL（含 ulid ID 生成）
├── registry.cj             路由匹配 + 守卫/布局（@Page 宏运行时）
├── html.cj                 HTML 壳生成 + 内联前端 JS（CangjieUI）
├── ws.cj                   wsSendJson / wsSendText / wsClose
├── app.cj                  App 类 + 会话循环 + initSignals 信号集成
├── macros/                 宏定义目录（macro package）
├── demo/                   演示应用（demo 子包）
├── signal_test.cj          Signal / Store 单元测试
├── vnode_test.cj           vnode 单元测试
├── action_test.cj          action 单元测试
├── registry_test.cj        registry 单元测试
└── diff_test.cj            diff 单元测试
```

- `cjpm` 只扫描 `src/*.cj` 顶层文件，子目录仅 `macros/` 支持
- 所有源码使用 `package cjxt`（宏包使用 `macro package`）
- 测试文件放在 `src/` 下与源码同包

## 环境配置

使用 `cjvs` 管理仓颉版本。通过 `pty_spawn` 创建 zsh PTY 会话，先执行`cjenv` 加载核心库，再 `eval $(cjvs stdx env zsh)` 加载stdx的`LD_LIBRARY_PATH`环境变量，再执行仓颉命令：

```shell
eval "$(cjvs env zsh)"
eval "$(cjvs stdx env zsh)"
cjpm build

# 运行测试
cjpm test

# 清理
cjpm clean
```

- 日常开发只需 `cjpm build` 和 `cjpm test`
- 单独跑某个测试: `cjpm test --filter 'TestName.testMethod'`
- 使用 `@sass` 宏需要安装 `sass`：`npm install -g sass`
- 示例项目在 `examples/`，构建: `cd examples && cjpm build`，运行: `./target/release/bin/main`（从 examples 目录）

## 浏览器测试

使用 `agent-browser` 进行端到端测试。前置：构建后启动演示服务。

```shell
# 用 pty_spawn 启动演示服务（需 cjvs 环境）
pty_spawn:
  title: "Demo Server"
  command: zsh -c 'eval "$(cjvs env zsh 2>/dev/null)" && eval "$(cjvs stdx env zsh 2>/dev/null)" && exec ./target/release/bin/main'
  workdir: /home/ystyle/Projects/Cangjie/cjxt

# 浏览器交互
agent-browser open http://localhost:8080
agent-browser snapshot -i -c     # 查看交互元素
agent-browser click @e2          # 点击某个 ref
agent-browser eval "document.querySelector('p').textContent"  # 读取更新后的 DOM
```

## 已知仓颉约束

- 枚举变体名不能与类型名相同
- 方法名不能与字段名相同（`var fields` → 方法用 `setFields` 而非 `fields`）
- `struct` `class` 使用 `init` 关键字定义构造函数（不是 `func new`）
- `where`、`match`、`quote` 是仓颉关键字，方法名需要用反引号或用 `doMatch` 等变体
- 枚举不支持 `==`/`!=` 比较运算符，需使用 `match` 手动实现比较
- `T!` 是命名参数默认值语法：`func div(children: Array<ComponentNode>, attrs!: Option<Attributes> = None)`
- match arm 的 `=>` 块内不能写 `let` 或 `for` — 提取为独立函数
- `type` 和 `match` 是关键字，参数/变量名用 `typ`、`doMatch` 等变体
- `HashMap<K, V>` 使用 `add(key, val)` 添加、`get(key)` 返回 `Option<V>`、`remove(key)` 删除
- 不支持命名参数调用（仅支持带 `!` 的命名参数默认值，调用时按位置传参）
- `String` 拼接用字符串模板 `"${a}${b}"`；切片用 `str[start..end]`，无 `substring()`
- 枚举不支持 `==`/`!=`，需手动实现 `operator ==`
- lambda 不能捕获 `var` 可变变量，用 `Box<T>` 包装（`let captured = Box<Int64>(0)`，通过 `captured.value` 读写）
- 函数重载歧义：`(A) -> B` 和 `(A) -> Unit` 同时存在时，返回值的 lambda 导致歧义，需用 `let wrapped: ActionHandler = { ... }` 包装
- `macro package` 只能导出宏定义，不能导出 `public func`（但可以定义包内私有的辅助函数）
- `std.regex.Regex(pattern).find(input)` 返回 `Option<MatchData>`，可用作 FormRule.pattern 校验
- Cangjie 不支持三元运算符 `? :`，需用 `if/else`
- `!` 标记的命名参数调用时**必须按名传递**，不能按位置传
- match arm `=>` 后的 `{ }` 是 lambda 表达式，不是语句块；多语句需提取为独立函数或用链式调用
- `@EmbedString("public/css/element-plus.css")` 按**包根目录**（包含 `src/` 的目录）解析路径。embed 的 `getPackageRoot()` 通过 `-p` 参数中的 `/src` 定位包根。
- `@EmbedString` 在编译时嵌入 CSS，因此**必须先编译 SASS**，再编译仓颉。
- 正确顺序：`bash scripts/build-css.sh` → `cd examples && cjpm build`。
- `cjpm` 的 path 依赖会缓存编译产物到 `target/release/{包名}/`，修改依赖源码后需清理该缓存再 `cjpm build`。

## 后续计划

> 组件一律参照 Element Plus（本地 `~/Projects/element-plus/`）的属性/样式/事件实现。

### P0 — 框架基础设施（已完成）
- [x] 路由参数 `[id]`：RouteRegistry 改用 RouteEntry.doMatch 匹配，支持 `/user/[id]`
- [x] Form 增强：校验体系（rules、validate、状态 class）
- [x] History API（Issue #1）：前端 pushState/popstate 全流程
- [x] onClick 简化重载：Button/MenuItem/Tag/Link 支持 `(ActionContext) -> Unit`
- [x] 优化组件样式导入：`@EmbedString` + `App.addCSS`/`UseComponent` 实现 CSS 编译时嵌入+运行时服务
- [x] Tooltip / Popover（客户端组件）
- [x] Progress / Avatar / Empty / Descriptions / Statistic / Result（数据展示组件）
- [x] 按键事件：稳定 handler id（路径派生）+ KeyEvent 模型（keydown/keyup/修饰键）

### P1 — ERP/Chat 第一批（业务最小可用）
- [x] Pagination 分页（Table 配套，Signal 驱动 currentPage/pageSize）
- [x] DatePicker / DateRange / Calendar（ERP 单据/报表日期字段）
- [x] Message / Notification / Loading / Skeleton（反馈体系）
- [x] Tabs 标签页（多标签工作台布局）
- [x] Markdown 渲染组件（Agent Chat 消息可读）
- [x] 聊天自动滚动（data-auto-scroll 贴底跟随）；流式性能优化并入 P2 补丁粒度

### P2 — 基础设施第二阶段（架构投入，影响面最大）
- [x] 补丁粒度细化：前端 keyed reconciliation（原位 reconcile，流式/大数据不再整页重建）
- [ ] 虚拟滚动（列表 / Table / 长消息流）
- [ ] #4 DOM 事务（DOM Transaction）：批量更新 + 过渡动画

### P3 — ERP/Chat 第三批（体验完整）
- [ ] Upload 附件、Tree/TreeTable、Dropdown、Cascader、Steps、Breadcrumb
- [ ] 图表集成、Excel/CSV 导出
- [ ] 无障碍（ARIA）、i18n、主题 token

### 不做先行
- HMR、code splitting — Cangjie 静态编译无需
- DevTools — 组件稳定后再做
- `@rpc` 宏 — 和 #3 客户端组件一起做

## 客户端组件（Client Component）架构决策

### 设计原则
- **JS 注册**：宏不负责 JS 注册。所有客户端组件 JS（Tooltip、Popover 等）统一在 `UseComponent()` 通过 `@EmbedString` 嵌入并注册 `App.addJS()`。宏生成的类只包含 Component 定义。
- **无 App.global()**：没有全局单例。JSRegistry 也被移除。
- **客户端事件走 Handler ID**：不对齐 `componentId` 体系。`ClientComponentNode.on()` 使用 `nextHid()` 生成标准 handler ID，`toJson` 输出 `actions: {"onShow": "_h1"}`，事件通过标准的 `type: "action"` / `state.handlers.get(id)` 链路派发。前端不再有 `client_event` 消息类型。
- **前端组件注册用 Class**：`window.__CJXT_COMPONENTS__[name] = class { create() {} update() {} destroy() {} }`。比字面量对象更规范，`destroy` 能访问类作用域的引用（解决 Popover document 级事件监听器泄漏）。
- **宏生成的类保持干净**：`@Prop` 返回空 token（不保留原字段声名），生成的类只有 `_props` + `init()` + `render()` → `ClientComponentNode(...)`。无死代码，无顶层 `let _cc_X = ...` 注册语句。
- **Props 类型支持**：`_props: HashMap<String, JsonSerializable>`，`@Prop` 字段可声明 `String` / `Int64` / `Bool` / `Float64` 等类型，宏生成带正确类型的构造器参数。`writeValue(this._props)` 输出正确 JSON 类型（数字、布尔值不会变字符串）。

## 代码总结

### 2026-06-25 Table 组件修复与状态持久化

**问题 1：排序表头渲染成了 `<button>`**
- 原因：为了让表头可点击，把 label 包在了 `<button>` 里。
- 修复：改为 `<th class="is-sortable">` 整体可点击，内部用 Element Plus 标准的 `<span class="caret-wrapper"><i class="sort-caret ascending"></i><i class="sort-caret descending"></i></span>` 渲染排序箭头；当前排序状态通过 `<th class="ascending / descending">` 激活 EP 的 `.ascending .sort-caret.ascending` 样式。
- 同时补齐了表头/单元格/汇总行里的 `.cell` wrapper，符合 EP DOM 结构，Padding 与对齐才正确。

**问题 4：表头与表体列宽不对齐**
- 原因：header/body/summary 是三张独立的 `<table>`，仅给 `<th>/<td>` 设置 `width` 时，浏览器在列宽总和超过容器时会按内容比例压缩，导致三张表压缩结果不一致。
- 修复：
  - 给每张内层 `<table>` 添加 `<colgroup>`，用 `<col style="width: Xpx">` 显式声明列宽；
  - 给 header/body/footer 的 `<table>` 统一设置 `style="width: ${totalWidth}px"`，让 `table-layout: fixed` 严格按指定宽度分配，不再依赖浏览器压缩；
  - 外层 `.el-table` 添加 `overflow-x: auto`，列宽总和超过容器时整体水平滚动，表头随表体一起滚动；
  - showcase 的 Address 列从 `minWidth(300)` 改为 `width(200)`，避免在当前卡片宽度下出现水平滚动。

**问题 2：`onClick` 返回值未接收**
- `VNode.onClick` 返回新的 VNode，旧代码直接调用 `th.onClick(...)` / `tr.onClick(...)` 没有赋值回变量，导致 DOM 没有 `data-action-click`，点击无响应。
- 修复：`var th = VNode(...)` 然后 `th = th.onClick(...)`；行高亮同理 `tr = tr.onClick(...)`。

**问题 3：组件内部 Signal 在父组件重渲染后丢失状态**
- 根因：cjxt 的组件实例不会被框架复用。父组件 `render()` 每次都会 new 出新的子组件；子组件内部 Signal（排序列、排序方向、选中行、当前行）会随旧实例一起失效。
- 修复：Table 把需要持久化的状态改为可选外部 Signal：
  - `Table.sortColumn(Signal<String>)`
  - `Table.sortOrder(Signal<SortOrder>)`
  - `Table.selectedRows(Signal<ArrayList<HashMap<String, String>>>)`
  - `Table.currentRow(Signal<Option<HashMap<String, String>>>)`
- 内部保留 fallback Signal，简单场景仍可直接用；但跨渲染持久化需由调用方提供外部 Signal。
- 结论：需要持久化状态的组件，状态信号应外置，不能依赖组件内部 Signal。

**验证**
- `cjpm test`：42 个单元测试全部通过。
- `agent-browser`：表头显示 EP 排序箭头；点击 Date 后箭头高亮且数据升序；点击行后当前行高亮背景保持。

### 2026-06-25 Table 功能增强 — 行/单元格回调 API + checkbox 修复

**新增 Table 回调 API：**
- `rowClassName((row, index) -> String)` — 自定义行 class
- `rowStyle((row, index) -> String)` — 自定义行 style
- `cellClassName((row, col, rowIdx, colIdx) -> String)` — 自定义单元格 class
- `cellStyle((row, col, rowIdx, colIdx) -> String)` — 自定义单元格 style
- `headerRowClassName((index) -> String)` — 自定义表头行 class
- `headerCellClassName((col, index) -> String)` — 自定义表头 cell class
- `headerRowStyle((index) -> String)` — 自定义表头行 style
- `headerCellStyle((col, index) -> String)` — 自定义表头 cell style

**问题：checkbox 选择不响应点击**
- 根因：`renderCheckbox` 把 `onClick` 绑在 `<input class="el-checkbox__original">` 上，但 EP CSS 将该 input 设为 `opacity:0; width:0; height:0; z-index:-1`，用户点击不可见，事件永远不触发。
- 修复：将 `onClick` 从 `<input>` 移到 `<label>`。label 可见区域与 `el-checkbox__inner` 对齐，点击正常触发 cjxt action。
- 验证：`agent-browser click @ref` 和浏览器手动点击均正常工作。

### 2026-06-25 Table 视觉细节调优

**问题 1：排序表头 caret 在 label 之前**
- 根因：`buildSortableHeader` 先 add caret 再 add label text，EP 官方是先 label 后 caret（`.cell` 内 `position: absolute` + `left: 7px` 定位 caret）。
- 修复：交换添加顺序，label 在前 caret 在后。

**问题 2：缺少 `el-table--layout-fixed` class**
- EP 外层 `.el-table` 固定有 `el-table--layout-fixed`，我们的 Table 缺少这个 class。
- 修复：在 `render()` 的 cls 字符串中追加 `el-table--layout-fixed`。

**问题 3：`overflow-x: auto` 覆盖了 EP 的 `.el-table { overflow: hidden }`**
- EP 用 `.el-table { overflow: hidden }` 配合 `::after`/`::before` 伪元素实现外边框。
- 之前的代码在外层 `.el-table` 上加 `overflow-x: auto`，覆盖了 `overflow: hidden`，破坏了伪元素边框。
- 修复：将 `overflow-x: auto` 从外层 div 移到 `.el-table__inner-wrapper` 上，保留外层 `overflow: hidden`。

**问题 4：内层 `<table>` 缺少 `border/cellpadding/cellspacing` 属性**
- EP 的 header/body/footer table 都有 `border="0" cellpadding="0" cellspacing="0"`。
- 修复：在 `renderHeader`/`renderBody`/`renderSummary` 的 table attrs 中补齐。

**构建流程教训**
- `@EmbedString` 在编译时嵌入 `element-plus.css`，因此**必须先编译 SASS**，再编译仓颉。
- 正确顺序：`bash scripts/build-css.sh` → `cd examples && cjpm build`。
- `cjpm` 的 path 依赖会缓存编译产物到 `target/release/{包名}/`，修改依赖源码后需清理该缓存再 `cjpm build`。
- `@EmbedString` 按 `cjpm build` 时的**包根目录**解析路径（embed `getPackageRoot()` 通过 `-p` 参数中的 `/src` 定位包根）。之前 embed 宏的 `getPackageRoot()` 搜索 `/src/`（带尾部斜杠）匹配不到 `-p /.../src`，已修复为搜索 `/src`。
- 构建顺序：**先** `bash scripts/build-css.sh`，**再** `cd examples && cjpm build`。

**agent-browser 注意事项**
- 使用 `agent-browser click @ref` 在某些情况下 cjxt 前端不会捕获事件。
- 改用 `eval("element.dispatchEvent(new MouseEvent('click', {bubbles:true}))")` 确保 DOM 事件正确派发。

### 2026-06-26 Dialog 组件实现与 `@EmbedString` 路径陷阱

**实现功能**
- 新增 `Dialog.cj` 组件，支持 Props：`visible`、`title`、`width`、`top`、`showClose`、`closeOnClickModal`、`closeOnPressEscape`、`modal`、`center`/`alignCenter`、`fullscreen`、`destroyOnClose`、`beforeClose`、`header`/`footer` slots。
- 从 Element Plus 源码复制 `dialog.scss` 与 `overlay.scss` 到 `public/scss/element-plus/` 并引入 `element-plus.scss`。
- 在 `showcase.cj` 添加基础 Dialog 演示（打开按钮 + title + footer 取消/确认）。

**问题 1：Dialog 在浏览器中不可见**
- 根因：`@EmbedString("public/css/element-plus.css")` 按 `cjpm build` 时的**包根目录**解析路径（embed 的 `getPackageRoot()` 通过 `-p` 参数定位）。embed 宏的 `getPackageRoot()` 搜索 `/src/`（带尾部斜杠）匹配不到 `-p /.../src`，导致从 CWD 解析，而我们在 `examples/` 下执行 `cjpm build`，于是读取 `examples/public/css/element-plus.css`。
- 修复：修复 embed 宏的 `getPackageRoot()`（`indexOf("/src/")` → `indexOf("/src")` 并校验后续字符），改为本地 path 依赖后构建正常。

**问题 2：Dialog 关闭按钮的 `onClick` 编译歧义**
- 根因：`Button.onClick` 同时存在 `ActionHandler` 和 `(ActionContext) -> Unit` 两个重载，直接传返回 `PatchResult.ReRender` 的 lambda 会产生歧义。
- 修复：在 `showcase.cj` 用 `let handler: ActionHandler = { ... }` 显式类型包装后再传给 `.onClick(handler)`。

**问题 3：Dialog 高度被拉长为内容高度的 3-4 倍**
- 根因：dialog 外层 wrapper 使用了 `display: flex; justify-content: center`，而 flex 容器默认 `align-items: stretch`，导致 `.el-dialog` 被纵向拉伸到整个视口高度。
- 修复：将 wrapper 的 class 从 `el-overlay` 改为 `el-overlay-dialog`，并去掉 `display: flex; justify-content: center`；改为使用 EP 原生的 `margin: var(--el-dialog-margin-top) auto 50px` 居中。同时将 dialog 的 inline style 从 `width: X; margin-top: Y` 改为 CSS 变量 `--el-dialog-width: X; --el-dialog-margin-top: Y`，与 EP `.el-dialog` 规则完全对齐，也避免覆盖 `.is-align-center { margin: auto }`。

**问题 4：Showcase 左侧菜单高度不足、无法滚动**
- 根因：`.showcase-sidebar` 没有固定高度，只随内容撑开；菜单项多时无法滚动，且滚动页面后侧栏会消失。
- 修复：侧栏改为 `position: fixed; top: 90px; left: max(16px, calc(50% - 534px)); height: calc(100vh - 90px); overflow-y: auto`，主内容区加 `margin-left: 220px` 避让。90px 用于抵消顶部 tab 栏 + 容器 padding/margin。

**验证**
- `cjpm test`：42 个单元测试全部通过。
- `agent-browser`：Dialog 打开后高度从 490px 降到 136px，符合内容高度；白色弹窗、遮罩层、标题、内容区、footer 按钮均正常；点击关闭按钮可关闭。Showcase 左侧菜单固定于视口、高度为屏幕高减 tab 栏高度，可独立滚动。

### 2026-06-26 Drawer 抽屉组件

**实现功能**
- 新增 `Drawer.cj` 组件，Props：`visible`、`title`、`direction`（四方向）、`size`、`showClose`、`closeOnClickModal`、`modal`、`withHeader`、`beforeClose`、`header`/`footer` slots。
- 枚举 `DrawerDirection：LTR | RTL | TTB | BTT`。
- 从 EP 源码复制 `drawer.scss` 到 `public/scss/element-plus/` 并引入。
- Showcase 演示：基础弹出 + 方向切换菜单。

**问题 1：`MenuItem.onClick` 也有重载歧义**
- 跟 `Button.onClick` 一样的问题，lambda 返回 `PatchResult.ReRender` 时歧义。
- 修复：`let handler: ActionHandler = { ... }` 显式包装。

**问题 2：`Menu.add()` 接受 `MenuItem` 类型，不是 `IComponent`**
- 展示使用 `ArrayList<IComponent>` 存储菜单项，但 `Menu.add()` 签名是 `(item: MenuItem): Menu`。
- 修复：将 `dirOptions` 类型改为 `ArrayList<MenuItem>`。

**问题 3：Drawer 宽度不跟随 size**
- EP Vue 通过 inline style 设置 `width` 或 `height`（取决于方向），CSS 变量 `--el-drawer-size` 仅做参考。我们的 Drawer 只设了 CSS 变量没设 inline width/height。
- 修复：在 inline style 中根据方向追加 `width: ${size}` 或 `height: ${size}`。

### 2026-06-26 客户端组件（Client Component）系统

**实现功能**
- `@ClientComponent` 属性宏 + `@Prop`/`@Event`/`@Method` 内层宏（嵌套宏，`setItem`/`getChildMessages` 通信模式，参考 storm-cj 和 kux-cj 实现）
- `ClientComponentNode` VNode 类型 + 序列化 + expandTree 叶子节点
- `JSRegistry` + `App.global()` 静态 JS 注册
- 前端 `cangjie-ui.js` 扩展：`client:xxx` 渲染分支、`__CJXT_COMPONENTS__` 注册表、动态 JS 加载、`CJXT.triggerEvent`、patch 替换时 destroy 清理
- 后端 `client_event` WS 消息处理
- Tooltip 作为第一个示例客户端组件（hover 显示/隐藏）

**问题 1：嵌套宏 `setItem`/`getChildMessages` 可行，但内外宏必须分文件**
- 参考 storm-cj（`@Model` + `@Id`/`@Index`）和 kux-cj（`@Crud` + `@BeforeCreate`），展开顺序为内层先展开，外层用 `getChildMessages(key)` 收集（参数为内层宏名）。
- **坑**：内外宏必须在**不同文件**（同 `macro package` 不同 `.cj` 文件）。全放同一个文件时 `getChildMessages` 返回空。storm-cj 和 kux-cj 也是分文件的，这隐含了 Cangjie 编译器的处理顺序约束。

**问题 2：`@ClientComponent` 是属性宏，用方括号传参**
- `@ClientComponent` 是 plain macro，不需要 `[]`。
- `parseJSPath` 解析 attr 中的 key-value 对。

**问题 3：`export default` 不兼容 `<script>` 标签**
- cjxt 的 JS 通过 `<script src>` 加载，不支持 ES Module。
- 改为 IIFE + `window.__CJXT_COMPONENTS__` 全局注册。

**问题 4：embed 1.0.5 下 JS 模板字符串 `${}` 不展开**
- embed 1.0.5 改用 `MULTILINE_RAW_STRING` token 嵌入 JS，`\${ev}` 保留原样进入浏览器。JavaScript 引擎对 `\$` 的处理存在兼容性问题，导致 `${ev}` 不展开。
- 修复：JS 中所有涉及 `\${}` 的模板字符串改为字符串拼接 `'prefix-' + var`。

**问题 5：组件 JS 注册时机**
- 宏生成的 `render()` 在组件首次渲染时才调用，此时 `App.global().addJS()` 注册 JS blob。
- 但初始页面 `<script>` 标签在渲染前已生成，不会包含新注册的 JS。
- 修复：前端 `renderClientComponent` 发现组件未注册时，动态创建 `<script>` 标签加载 JS。

**问题 6：`@Event`/`@Method` 的 `FuncDecl` 可正常解析带函数体的声明**
- `func onShow(): Unit {}` 带空体的声明可以被 `FuncDecl` 正确解析。无异常。

**问题 7：平坦参数函数（`Tooltip("a", "b")`）生成成功**
- 手动拼接 Token（`IDENTIFIER` + `COLON` + `IDENTIFIER` + `COMMA` + ...）再传给 `parseDecl` 是可行的。之前的失败是因为 `@Prop` 的内外层宏没分文件导致 `getChildMessages` 返回空数据。
- 生成 `init(content: String, triggerText: String)` 构造函数，`Tooltip("提示", "悬停我")` 直接调用构造器。

**问题 8：类需要 `public` + `<: Component` 才能被外部包使用**
- 宏生成的类必需是 `public`，否则其他包无法引用。
- 宏生成的类必需有 `Component` 超类型，否则不能作为 `IComponent` 传入 `div()`。

**验证**
- `cjpm test`：42 个单元测试全部通过。
- `agent-browser`：Tooltip 渲染正确，hover 显示/隐藏正常。服务端注册 JS blob，前端动态加载后渲染。
- `cjpm test`：42 个单元测试全部通过。
- `agent-browser`：Tooltip 渲染正确，hover 显示/隐藏正常。服务端注册 JS blob，前端动态加载后渲染。

### 2026-06-28 Stage 3 数据展示组件与视觉修复

**实现功能**
- 新增 6 个数据展示组件：Progress、Avatar、Empty、Descriptions、Statistic、Result。
- 从 Element Plus theme-chalk 复制对应 SCSS 并引入 `element-plus.scss`。
- 在 `Types.cj` 定义相关枚举：`ProgressKind`、`ProgressStatus`、`AvatarShape`、`AvatarFit`、`DescriptionsDirection`、`DescriptionsAlign`、`ResultIcon`。
- Showcase 添加对应演示与 Props 面板。

**问题 1：Progress 环形/仪表盘进度条碎成小段**
- 根因：`buildCirclePath` 接受 `String r`，模板字符串中 `${r * 2}` 被 Cangjie 解释为字符串重复（`"47.000000" * 2 = "47.00000047.000000"`），导致 SVG path 数据错误。
- 修复：将 `buildCirclePath` 改为 `Float64` 参数，先计算 `r * 2.0` 再 `toString()`。

**问题 2：Progress 状态颜色与 Element Plus 不一致**
- 根因：`getStatusColor` 返回旧版 Element UI 的硬编码 hex（`#13ce66`、`#ff4949` 等），与 EP 的 CSS 变量主题色不同。
- 修复：无自定义 `color` 时返回 `var(--el-color-success)` / `var(--el-color-danger)` / `var(--el-color-warning)` / `var(--el-color-primary)`。

**问题 3：Progress 演示项紧贴**
- 根因：线形与环形进度条直接堆叠在 flex 容器内，间距不足。
- 修复：showcase 中把线形、环形分别放入 `progress-line-group` / `progress-circle-group`，并新增对应 CSS 控制 `gap` 与对齐。

**问题 4：Empty / Result 的 SVG 图标不显示**
- 根因：组件把 SVG 字符串放在 `innerHTML` 属性上，但 `cangjie-ui.js` 渲染器对所有属性统一调用 `setAttribute`，导致 SVG 被当作普通字符串属性写到 DOM 上，无法解析为 SVG 元素。
- 修复：在渲染器的属性处理循环中检测 `innerhtml`（不区分大小写），改为设置 `el.innerHTML`。

**问题 5：Result 图标前景与背景同色导致不可见**
- 根因：自定义 SVG 把背景圆/三角和前景图标都填成 `currentColor`，同颜色叠加后前景消失。
- 修复：背景路径用 `currentColor`，前景路径（对勾、叉、感叹号、信息号）用 `#fff` 白色。

**验证**
- `cjpm test`：42 个单元测试全部通过。
- `agent-browser`：Progress 线形/环形/仪表盘、Avatar、Empty、Descriptions、Statistic、Result 均正常渲染，Result 图标前景清晰可见。

### 2026-06-28 Descriptions / Statistic DOM 结构对齐 EP

**问题 1：Descriptions 标题未加粗、带边框版本不显示边框**
- 根因 1：header 直接把 title/extra 文本作为子节点，缺少 `el-descriptions__title` / `el-descriptions__extra` 包裹 div，EP 的 flex + space-between 标题样式未生效。
- 根因 2：边框表格类名写错成 `is-border`，EP SCSS 实际使用 `is-bordered`。
- 修复：header 内 title/extra 分别包进对应 class 的 div；边框表格使用 `is-bordered`。

**问题 2：Descriptions 列宽（colspan）计算错误**
- 根因：border 模式下 content cell 用了 `colspan="span"`，非 border 水平模式下用了 `colspan="span*2"`，与 EP 规则不符。
- EP 规则：
  - border 水平：label colspan=1，content colspan=`span*2-1`；
  - 非 border 水平：合并 cell colspan=`span`；
  - vertical：label/content colspan=`span`。
- 修复：按上述规则重新计算 colspan。

**问题 3：Statistic 数值样式未生效**
- 根因：数值 span 使用了 `el-statistic__number`，而 EP SCSS 只定义了 `el-statistic__value`。
- 修复：数值元素类名改为 `el-statistic__value`。

**问题 4：Showcase 中 Statistic 间距不足、Descriptions 属性面板文字重叠**
- 修复：新增 `statistic-row`（gap: 48px）替代通用 `row`；缩短 `Descriptions.add(DescriptionsItem)` 属性名为 `add(item)`，避免超出列宽。

**验证**
- `cjpm test`：42 个单元测试全部通过。
- `agent-browser`：Descriptions 标题加粗、边框表格正常；Statistic 标题/数值垂直排列、间距合理。

### 2026-08-18 App.pushUpdate 服务端推送（harness 融合接缝）

**实现功能**
- `App.pushUpdate(sid, update)`：跨线程服务端推送。在 SignalTracker.execMutex 锁内执行 update 回调（更新 Signal），返回 ReRender 时走与 runAction 完全同构的脏追踪/补丁链路。
- `Session.ws: ?WebSocket`：会话持有当前连接引用（startSession/resumeSession 设置，listenLoop 断开清空），作为推送目标。

**问题 1：仓颉枚举不支持 `!=`**
- `session.wsState != WsState.Connected` 编译报错，改用 match。

**问题 2：stdx.net.http 的 WS 握手需要 stdx.crypto.digest，但全局 link-option 传染宏包**
- 测试代码引用 `WebSocket.upgradeFromClient`（客户端升级 → SHA1 accept key）后，测试二进制链接报 `DYN_SHA1/MallocDynMsg/FreeDynMsg` 未定义。
- `[package] link-option` 会透传给所有动态库/可执行产物（含宏包 .so），而宏包链接命令没有 stdx 的 `-L` 路径 → `cannot find -lstdx.crypto.digest`。
- `package-configuration` 只支持 output-type/compile-option，不支持 link-option。
- 修复：link-option 移到 `[target.x86_64-unknown-linux-gnu]` 级，`-L${CANGJIE_STDX_PATH} -lstdx.crypto.digest`（对齐 mcp-cj/atelier；cangjie_stdx 也用 target 级）。target 级不传染宏包链接。

**问题 3：真实 WS 端到端测试需要 digest 链接，与宏包冲突**
- 客户端升级（upgradeFromClient）测试留在 harness-cj 的 harness_tests（无宏包，可自由配链接）；cjxt 主包只保留守卫路径单测（会话不存在/未连接/无 ws 引用）。

**问题 4：Thread 不在 std.thread**
- `import std.thread` 报"not added as a dependency"；Thread 类在 std.core，但无法构造（仅 Future.thread / currentThread）。创建线程用 `spawn {}` 表达式（std.core 自动可用）。

**问题 5：RouteFactory 是 `() -> IComponent`**
- 零参 lambda 必须写 `{ => PushTestPage() }`（带 `=>`）。

**验证**
- `cjpm test`：46 个单元测试全部通过（42 原有 + 4 新增 pushUpdate 守卫路径）。

### 2026-08-20 按键事件 + 稳定 handler id（回车发送修复 + 完整 KeyEvent 模型）

**实现功能**
- 完整 KeyEvent 模型：`KeyEvent` 结构（key/code/keyCode/ctrl/shift/alt/meta + `isEnter()/isEscape()/isCtrlEnter()`），`ActionContext.keyEvent: Option<KeyEvent>`，`VNode.onKeydown/onKeyup` 便捷 API。
- 前端按键委托泛化：`attachKeyDelegate` 改为 keydown+keyup 委托，params 回传 key/code/keyCode/修饰键；`keydown_enter`（回车命令）向后兼容保留。
- 服务端解析 action 的 params：`readActionParams`（从 WS 原始 JSON 提取 `"params":{}` 对象）+ `parseKeyEvent`，action 的 params 不再被丢弃（点击的 `data-*` 参数也一并可用）。
- examples todo 页改用它做演示：回车添加 / Esc 清空（`on("keydown", ...)` + `ctx.keyEvent`）。

**问题 1（根因）：handler id 每次重渲染都变 → 事件失效（回车用不了）**
- `VNode.on/bind/onClick` 用全局计数 `nextHid()/nextBid()` 生成 id；服务端每次重渲染（bind 触发、push 更新）都重新 render → 全新 id。
- 前端 `applyTreePatches` 对绑定 input 只更新 value、不更新 `data-action-*` 属性（保 IME 状态）→ DOM 上的旧 id 过期 → `dispatchAction` 查不到 handler → 回车/点击无响应。
- 修复：`RenderContext.expandTree` 里 `stabilizeVNodeHandlers` 把 handler id 从全局计数改为**节点路径 + 事件**派生（`h:${path}:${ev}` / `b:${path}:bind`），重渲染后 id 不变。只对 `_handlers` 里存在的真 handler id 重映射，字面量命名 action（`button(actions:{"click":"submit"})`）保持原样。
- 坑：重映射后必须记录已消费的原始 id（`consumed`），否则"保留未引用 handler"的逻辑会把原始 `_h1` 加回来导致一个 handler 重复收集（`testExpandActionIdsConsistent` 就因此挂过一次）。

**问题 2：Escape 清空命令不更新聚焦输入框的 DOM value**
- `applyTreePatches` 原来对聚焦的绑定 input 一律跳过 value 更新（防覆盖正在输入的内容）→ 服务端清了信号，DOM 还显示旧文本。
- 修复：仅在**值确实变化**时应用，且跳过 IME 组合中（`data-composing`）与输入未提交（`data-bindDirty`）两种情况；`bindDirty` 的清理从补丁前移到补丁应用后。
- `attachBind` 的 compositionstart/end 现在把组合状态写到元素 `data-composing`，供 `applyTreePatches` 读取。

**问题 3：`' '` 单引号空格字面量被 Cangjie 解析成 String**
- `s[i] == ' '` 编译报 `invalid binary operator '==' on type 'UInt8' and 'Struct-String'`。
- 修复：JSON 解析器的字符比较一律用字节字面量（`32u8`/`58u8`/`34u8`/`123u8` 等），对齐 `define_css.cj` 的 `46u8` 写法。

**问题 4：WS 新建会话总是解析 `/` 根路由**
- 调试 WS 时用全新 sessionId 连接拿到的不是当前 URL 的页面，而是根页面。要先 GET 目标路径拿 sessionId，再带 sessionId 连 WS `resumeSession` 恢复对应会话。

**验证**
- `cjpm test`：58 个单元测试全部通过（49 原有 + 3 稳定性 + 9 KeyEvent/params 解析）。
- agent-browser（examples /todo）：回车添加、Esc 清空、点击添加、输入后立即回车全部正常；受控单次 keydown 派发 = 单次 action（`agent-browser press Enter` 会多次派发 keydown 导致误加，属工具行为）。
- 注：harness-cj 构建有**预先存在**的依赖冲突（`bstorm 1.4.0` 要求 `gjson = 1.1.1`，harness 用 path 依赖 `gjson-cj 1.2.1`），清 cjxt 缓存触发重解析才暴露；00:31 能构建是 bstorm 有缓存。与本次改动无关，需单独解决。

### 2026-08-20 Pagination 分页组件（ERP 第一批 #1）

**实现功能**
- 完整 Pagination 组件，对齐 Element Plus：`prev/pager/next/total/sizes/jumper` 六段布局（layout 字符串控制顺序）、pagerCount 折叠省略号、background/small/disabled/hideOnSinglePage、prevText/nextText。
- 纯逻辑抽到 `src/pager.cj`（package cjxt）：`computePageCount`（向上取整）、`computePager`（对齐 EP pager.vue 的 pagers 算法：showPrevMore/showNextMore + 中间页数组）、`clampPage`——10 个单测覆盖。
- 状态外置：`currentPage(Signal<Int64>)` / `pageSize(Signal<Int64>)`（对齐 Table 实践，跨重渲染持久化）。
- 事件：`onCurrentChange` / `onSizeChange` / `onChange`（页变化触发；先写信号再回调）。
- sizes 复用 Select 组件（给 Select 加了可选 `onChange(h)`：选项选中后回调，值已写入信号）。
- jumper 输入框：不 bind，直接 `onKeydown`，通过增强后的 `collectParams`（表单控件附带 `value`）在回车 action 里拿到页码。
- 新增 "more" 图标（EP MoreFilled 三点路径）到 Icons.cj。

**问题 1：子组件 `.render()` 内联会破坏脏追踪作用域（sizes 下拉打不开）**
- 坑：`buildSizes` 里写 `VNode("span", [sel.render()], ...)`（内联 Select 的渲染结果），导致 Select 不是独立 Component 节点，`_open` 信号被订阅到**父组件 Pagination** 上；点开下拉 → `_open.set(true)` → Pagination 重渲染 → new 出全新 Select（`_open=false`）→ 下拉永远打不开。
- 修复：把 `Select(...)`（Component 本身）作为 span 的 children 传入，不调 `.render()`。expandTree 会把它当 `case b: Component` 处理 → 自己的 renderWithScope → 正确的脏追踪。
- 结论：**组件树里内联 `.render()` 会破坏子组件的独立脏追踪/信号状态，应把组件实例作为 children 节点传入**。

**问题 2：Cangjie 约束**
- match arm `=> {}` 块内不能写 `let`：`case Some(fn) => { let _ = fn(ctx); () }` 编译报错。提取为 `func runCb(fn, ctx): Unit { let _ = fn(ctx); () }`。
- `Int64.parse` 需 `import std.convert.*`（Pagination.cj 里漏过一次）。
- `String.trim` 未确认，用字节级 `trimKey`（跳过 32u8/9u8）替代。
- `VNode.attr()/className()/style()` 是**整表替换** attrs，不是合并——jumper 输入框的 class/type/value 必须一次构造进 attrs。

**验证**
- `cjpm test`：70 个单元测试全部通过（60 原有 + 10 Pagination 纯逻辑）。
- agent-browser（examples /showcase → Pagination）：prev/next、页码点击、省略号快退快进、jumper 回车跳页、sizes 下拉改每页条数（50 条 → 页码正确 clamp）、共享信号跨实例同步、hideOnSinglePage/small/background 全部正常。
- 注：工作区有**并行会话**的未提交改动（app.cj 的 App.stop()/finally unlock、registry.cj、session.cj），提交时需只 add 自己的文件，避免误并。

### 2026-08-20 execMutex 静态锁泄漏 + RouteRegistry 同路径替换（harness 融合稳定性修复）

**实现功能**
- `App.stop()`：停 tang 服务器 + `SessionManager.clearAll()` 清会话（测试清理/生命周期管理用）。
- `SignalTracker.execMutex` 解锁移入 `finally`：runAction/pushUpdate/dispatchBind 三处。
- `RouteRegistry.register` 同路径重复注册改为**替换**（后注册者生效），新增 `removeEntry` 私有方法 + `entriesSize()`。

**问题 1（根因）：handler 抛非 Error 异常 → execMutex 永久泄漏 → 全量单测间歇死锁**
- 旧代码 `try { ... } catch (e: Error) { ... } SignalTracker.execMutex.unlock()`——`catch (e: Error)` 只捕获 `Error` 子类，handler 抛普通 `Exception`（如 WS 已关闭时 `wsSendJson` 抛的 socket 异常）时**跳过 unlock**。
- `execMutex` 是 `SignalTracker` 的 **static** 锁，跨所有 App 实例共享 → 泄漏后**所有**会话/测试的 `pushUpdate` 永久阻塞。
- 表现：harness 全量单测里 `testFullChain`（WS 推送 e2e）间歇性挂起——先跑 ChatLayout e2e（`refreshSessions` 异步 pushUpdate 写已关闭的 WS 抛 Exception）就泄漏锁，后续任何 pushUpdate 死锁；单独跑/成对跑通过是因为时序不同。
- 修复：解锁移入 `finally`（无论异常与否都执行）。Cangjie 的 try 表达式支持 `finally` 块。
- 回归测试：`testThrowingPushUpdateReleasesExecMutex`（harness_tests）——先触发一次抛 Exception 的 pushUpdate，再执行正常 pushUpdate 断言能拿到锁（旧代码此处死锁）。

**问题 2：RouteRegistry.global() 是进程级单例，register 追加导致陈旧路由残留**
- 旧代码 `entries.add(...)` 追加；多个 App/测试在同一进程注册同一路径时，`resolve` 取**第一个**匹配 → 先注册的陈旧工厂（绑定了已停的 host）残留，后续连接解析到错误页面/挂死。
- 修复：register 先 `removeEntry(path)` 删同路径旧条目再 add（后注册者生效），与 `titles/guards/layouts` 的覆盖语义一致。
- 回归测试：`testRegisterReplacesSamePath` / `testRegisterReplaceKeepsOtherPaths`（registry_test.cj）。

**验证**
- `cjpm test`：70 个单元测试全部通过（60 原有 + 2 新注册替换 + Select.cj 的 match-arm 修复让全新编译通过）。
- harness-cj 全量 `cjpm test`：80 个测试全部通过（此前全量挂起 600s 超时，修复后稳定通过）。

### 2026-08-20 DatePicker / DateRangePicker 日期组件（ERP 第一批 #2）

**实现功能**
- `DatePicker` 单选日期：el-date-editor 输入框（日历前缀图标 + clearable 清除）+ 日历弹层（年/月导航、42 格月历、今天/选中高亮、prev/next-month 补位）。
- `DateRangePicker` 区间：双月面板（is-left/is-right）、start/end/in-range 高亮、反向选择自动交换、clearable/disabled。
- 纯逻辑抽到 `src/calendar.cj`（package cjxt）：`isLeap/daysInMonth/firstWeekday/addMonths/monthGrid/formatDate/pad2/parseDate/dateToDays/compareDate/isToday/nowDateKey` —— 12 个单测。
- 值格式 "yyyy-MM-dd"（Signal<String> 绑定）；今天高亮用 `DateTime.now().format("yyyy-MM-dd")`。
- EP date-picker scss（picker/picker-panel/date-picker/date-table/date-range-picker/utils）复制并调整 `@use` 相对路径，编译嵌入。
- 新增 "calendar" 图标。

**问题 1（关键坑）：区间首次点选写外部信号 → 面板关闭**
- 首次点选把 start 写进外部 Signal → 父组件（showcase）读该信号 → 重渲染 → new 出全新 DateRangePicker（`_open=false`）→ 面板关闭，没法点第二次选 end。
- 修复：首次点选**只写内部 `_pendingStart`**（内部信号变更只重渲染 DateRangePicker 自身实例，面板保持打开）；两端都选齐才写外部 start/end 并关闭。
- 显示用 `displayStart/displayEnd`：pendingStart 已设时显示待选起点、end 置空。

**问题 2：`None` 字面量歧义**
- 包内多个枚举有 `None` 变体（SortOrder.None / ResultStatus.None / AvatarFit.None 等），值位置传裸 `None` 给 `Option<T>` 参数报 "find multiple constructor 'None'"。
- 修复：用全限定 `Option<(String, String)>.None`（对齐 Radio.cj 的 `Option<Signal<String>>.None` 写法）；match 模式的 `case None` 不受影响。

**问题 3：日期字符串比较**
- 不确定 String 是否支持 `<`/`>`，日期 key（"yyyy-MM-dd"）统一用 `dateKeyLess/dateKeyLessOrEq`（parseDate + compareDate 数值比较）。

**问题 4：agent-browser 并发**
- 仓库有并行会话也用 agent-browser；务必用独立 `AGENT_BROWSER_SOCKET_DIR` + `AGENT_BROWSER_SESSION`（命名会话）隔离，避免抢同一浏览器实例。

**验证**
- `cjpm test`：82 个单元测试全部通过（70 原有 + 12 日历纯逻辑）。
- agent-browser（独立会话，examples /showcase → DatePicker）：单日期打开/选中/清除/今天高亮；区间双月面板、首次点选面板保持打开、二次点选完成并关闭、start/end/in-range 高亮、反向选择自动交换、disabled 全部正常。

### 2026-08-20 Session 级 handler 注册表修复（异步 pushUpdate 渲染的 handler 丢失）

**实现功能**
- `Session` 增加 `handlers: HashMap<String, ActionHandler>`（会话级共享注册表）+ `refreshHandlers(tree)`。
- `SessionState` 移除 `handlers` 字段；`dispatchAction`/`dispatchBind`/`sendPatch` 全部改查/写 `session.handlers`。
- 所有渲染点（startSession/resumeSession/pushUpdate/applyNav）统一 `session.refreshHandlers(tree)`。
- 新增 `session_test.cj`：3 个单测（rebuild/不累积/bind 收集）。

**问题（根因）：异步 pushUpdate 渲染出的 handler 找不到 → 点击无响应**
- 旧架构：`handlers` 存在 `SessionState` 里，而 `startSession` 和 `pushUpdate` **各自 new 一个 SessionState**。
  - `startSession` 创建的 state 传给 `listenLoop` 用于分发 action。
  - `pushUpdate`（如 ChatPage.refreshSessions 异步填充会话列表）创建**另一个** state，其 `sendPatch` 把 handler 写进**自己**的 state.handlers。
  - → 异步渲染的新 handler（如会话列表的**删除按钮**）只进了临时 state，`listenLoop` 查的旧 state.handlers 里没有 → 点击删除无反应。
- 表现：聊天页「发送」正常（bind/enter 同连接同步处理），但「删除会话」按钮点击无响应（handler 是异步 refreshSessions 渲染的）。
- 修复：handlers 提升到 Session 级（所有渲染/分发共享同一 map），彻底消除 startSession 与 pushUpdate 的 state 分裂。

**验证**
- `cjpm test`：85 个单元测试全部通过（82 原有 + 3 Session 注册表）。
- agent-browser（独立 socket 目录 + 命名会话）实测聊天页：发送消息 → 会话列表出现项 → 点删除按钮 → 回欢迎页 + 自动新建会话，全链路正常。
- 注：agent-browser 在并行会话环境下必须 `AGENT_BROWSER_SOCKET_DIR=<可写目录>` + 命名会话隔离，否则 target 漂移（eval 打到 about:blank）。

### 2026-08-21 Message / Notification / Loading / Skeleton 反馈体系（ERP 第一批 #3）

**实现功能**
- `MessageHost`：绑定 `Signal<ArrayList<MessageItem>>`，顶部居中 toast 堆叠；点任意处关闭 + 3s 自动消失；`MessageQueue.success/warning/error/info(text)` 服务端推送。
- `NotificationHost`：右上角通知（标题+内容），4.5s 自动消失；`NotificationQueue.success(title, text)` 等。
- `Loading`：绑定 `Signal<Bool>`，EP 加载遮罩（circular spinner + 文案），fullscreen。
- `Skeleton`：骨架屏（首行 + rows 段落），animated/noAnimated。
- 前端新增 `data-auto-dismiss="ms"` 机制（JS setTimeout → dispatch click → 关闭 action）。
- toast 队列纯逻辑抽到 `src/toast.cj`（package cjxt）：`nextToastId`（模块级单调 id）/ `toastPush` / `toastRemoveAt` —— 5 个单测。
- EP message/notification/loading/skeleton/skeleton-item scss 复制编译嵌入。

**问题 1（关键坑）：EmptyVNode 在 children 中不产生 DOM 节点 → 补丁替换落空**
- MessageHost 列表为空时返回 `EmptyVNode()` → 服务端树里占 index N，但 JS 渲染 `empty` 不创建 DOM 节点 → 实际 DOM 少一个槽位 → 补丁 path 指向的 index 不存在 → `parentEl.childNodes[idx]` 为 undefined → 替换被跳过 → toast 永远不出现。
- 修复：MessageHost/NotificationHost 的容器 div **始终渲染**（空时是无内容 fixed div，无碍）；Loading 的 mask 也始终渲染（隐藏时 `display:none`）。
- 结论：**树路径按 children 索引定位 DOM，任何会切换成 EmptyVNode 的组件都要保证始终有一个稳定 DOM 槽位**，否则补丁对不上。

**问题 2（关键坑）：方法名遮蔽顶层函数 → 无限递归 OOM**
- `Loading` 有方法 `text(v: String)`；`Loading.render()` 里 `text(this._text)` 本意调顶层 `text(content): TextNode`，但**类方法优先解析** → 返回 `this`（Loading 自身）→ 作为 `VNode("p", [Loading], ...)` 的子节点 → expandTree 递归处理 Loading → 再调 text → 无限递归 → `OutOfMemoryError`（服务端 action 被 catch 吞掉，页面卡死）。
- 修复：方法改名 `label`。错误类型是 `OutOfMemoryError`（msg 空），用 `TypeInfo.of(e).name` + `e.getStackTrace()` 定位。
- 教训：**组件方法名不要与 cjxt 顶层辅助函数同名**（text/div/span/input 等），否则类内同名调用会被方法遮蔽。

**验证**
- `cjpm test`：90 个单元测试全部通过（85 原有 + 5 toast 队列）。
- agent-browser（独立命名会话）：Message 三条堆叠 + 点击关闭 + 3s 自动消失；Notification 标题内容 + 自动消失；Loading 切换遮罩/spinner/文案；Skeleton rows/动画；全部正常。

### 2026-08-21 Tabs 标签页组件（ERP 第一批 #4）

**实现功能**
- `Tabs` + `TabPane`：line / card / border-card 三种类型、top/bottom/left/right 位置（EP scss 按 root class 驱动布局）。
- 激活标签外置 `Signal<String>`（跨重渲染持久化），`onChange` 事件；禁用标签点击 no-op。
- 仅渲染激活 pane 内容；active 不在 panes 时回退首个 pane（`resolveActiveTab` 纯逻辑 + 4 单测）。
- 激活项高亮（`el-tabs__item.is-active`）；v1 省略滑动 active-bar（需客户端测量定位）。
- EP tabs.scss 复制编译嵌入。

**问题 1：`type` 是仓颉关键字**
- `public func type(...)` 编译报错（type 保留字），方法改 `tabType`。

**问题 2：TabPane 作为"数据载体"不单独渲染**
- TabPane 是 Tabs 的 children，Tabs.render() 消费其 name/label/children；TabPane.render() 返回稳定空 `div([])`（防 EmptyVNode 槽位错位——上一阶段教训）。

**验证**
- `cjpm test`：94 个单元测试全部通过（90 原有 + 4 tab 逻辑）。
- agent-browser（独立命名会话）：line/card/border-card 三种类型切换 + 内容更新、禁用标签 no-op、共享信号联动、active 名不匹配回退首个 pane，全部正常。

### 2026-08-21 Markdown 渲染组件（ERP 第一批 #5，Agent Chat 消息可读）

**实现功能**
- `Markdown` 组件：服务端 markit 解析 markdown → HTML 字符串，`innerhtml` 属性输出（支持 content 或 bind Signal<String>）。
- `src/markdown.cj` 纯逻辑：`renderMarkdown(text)`（GFM bundle）+ `escapeHtmlText`（解析失败回退）——7 个单测。
- `.el-markdown` 排版样式（标题/段落/代码块/行内代码/列表/引用/表格/链接/删除线/hr）编译嵌入。
- 选用 **markit v0.0.4**（对比 pulldown4cj v0.1.0）：
  - cjc-version 1.1.0 与 cjxt 完全一致（pulldown4cj 要 1.1.3，静态库 ABI 有风险）；
  - `Markit().use(GFMBundle()).parse(text).document.toHtml()` 一步到位（pulldown4cj 是事件流，要自建 HTML 渲染器）；
  - GFM bundle 支持表格/任务列表/删除线/自动链接。

**经验**
- 中心仓新包拉取：沙箱下 `~/.cjpm/repository` 只读，cjpm 无法写索引下载新包；registry API 401。可用 `cjpm build` 的一次性提权（danger-full-access）让 cjpm 完成下载（沙箱只读是真实 denial，可提权）。
- 评估依赖用 `Markit().use(StandardMarkdownBundle())` 时**表格不渲染**——表格是 GFM 扩展，须用 `GFMBundle()`。
- markit 依赖 `seajson`，`output-type=static`，编译正常。

**验证**
- `cjpm test`：123 个单元测试全部通过（116 原有 + 7 markdown）。
- agent-browser（独立命名会话）：h1/h2、加粗/斜体/删除线、行内代码、fenced 代码块、无序列表、引用、GFM 表格（th/td）、链接 href 全部渲染正常。

### 2026-08-22 聊天自动滚动（data-auto-scroll 贴底跟随）（ERP 第一批 #6）

**实现功能**
- 前端 `data-auto-scroll` 机制：`applyTreePatches` 末尾调用 `autoScrollAll()`——对 `[data-auto-scroll]` 容器，**仅当接近底部（dist < 80px）时贴底跟随**（回看历史时不打断）。
- showcase `AutoScroll` 演示：模拟流式消息逐条追加 + 滚动容器 + 消息计数。
- 流式消息性能优化的框架层已就绪：脏追踪本就只重渲染脏组件（sendPatch 按路径）；聊天页把 `messages` 信号下沉到消息列表子组件（harness 侧）+ P2 补丁粒度细化才是真正的大头。

**验证**
- `cjpm test`：123 个单测全过。
- agent-browser：`autoScrollAll` 贴底守卫逻辑隔离验证正确（scrollTop=0 远离底部时不跟随）；AutoScroll demo 容器多次成功渲染（含 data-auto-scroll 属性）。
- 完整"跟随滚动"交互验证受 **agent-browser 会话不稳定**限制（页面经多次 eval 后退化空白、`window.ui` 不可达）——已隔离验证核心 JS 逻辑，演示渲染正常。

### 2026-08-22 前端 keyed reconciliation 补丁粒度细化（P2 #1）

**实现功能**
- `applyTreePatches` 的整页重建（`innerHTML=''` + `renderTree` 全杀）与子树替换（`replaceChild`）改为 **keyed reconciliation 原位更新**：
  - `reconcileChildren(parentEl, nodes)`：位置对齐 + 按 tag/类型复用现有 DOM 节点（fragment 先平铺）。
  - `reconcileNode(el, node)`：同类型元素原位更新 attrs/actions/children；text/style 更新文本；empty 槽位保留。
  - `matchesNode` / `createNode` / `applyAttrs` / `applyActions`：新建/复用/更新统一。
  - bound input 的 value 更新带 `data-composing`/`data-bind-dirty` 守卫（保留 IME/输入）。
- 效果：流式/大数据更新只改**变化部分**，不再整页 DOM 重建——焦点/滚动/IME 保留，DOM 抖动大幅下降。
- 协议不变（服务端仍发子树 JSON）；`renderTree`/`renderSubtree` 保留（初始渲染用）。

**验证**
- `cjpm test`：123 个单测全过（服务端未改）。
- agent-browser：全页 reconcile 切换 demo 内容正确（Tabs 3 个、Pagination 3 个、Table 4 行数据）；AutoScroll 追加 reconcile 无 JS 异常（`window.onerror` 捕获为空）且滚动容器保留。
- 受 agent-browser 会话不稳定限制（~5 次 eval 后退化），交互细节验证受限；核心 reconcile 逻辑 + 渲染正确性已确认。

### 2026-08-22 全特性响应式核心——Computed / Effect / batch / untracked / 相等性 / 订阅生命周期（P2 前置地基）

**实现功能**
- `SignalTracker` 扩展：`batchDepth`（批量延迟通知）+ `untrackedDepth`（不追踪读取）+ `collectorStack`（computed/effect 重算时收集依赖以便退订）。
- `Signal<T>`：可选相等性（相同值不通知，防无限循环/多余重渲染）；`get` 支持 untracked 读取；`set` 支持 batch 合并（多次 set 一次通知）；订阅按 id 精确退订（`subscribe -> Int64` + `unsubscribe(id)`）。
- `Computed<T>`：惰性派生值（首次 get 计算 + 缓存；依赖变化自动失效并通知下游；支持链式依赖与 `dispose` 退订）。
- `Effect`：自动运行的副作用（init 立即跑一次，依赖变化重跑；`dispose` 退订依赖）。
- 顶层 API：`batch<T>(fn)`（流式/多字段更新合并为一次渲染）、`untracked<T>(fn)`。
- `notify()` 迭代**快照**——修复 effect 通知期间退订/改订阅破坏迭代导致的死循环。

**Cangjie 约束（本轮踩坑）**
- lambda 多参数**不带括号**：`{ a, b => ... }`（`{ (a, b) => ... }` 报错）。
- 零参 block lambda 必须 `{ => ... }`（`{` 后紧跟 `=>`）。
- 被 lambda 捕获的可变绑定必须 `let`（`var` 绑定不能进闭包）；可变性用 `Box<T>.value`。
- 类继承用 `<:` 不是 `:`。
- **构造函数/字段初始化器里不能创建捕获 `this` 的闭包**（"not allowed to be accessed before all member variables are initialized"）——用顶层辅助函数把依赖作为参数传入 lambda。

**验证**
- `cjpm test`：140 个单元测试全过（123 原有 + 17 新响应式：相等性/untracked/batch/Computed 惰性缓存与链式/Effect 跟随与 dispose/unsubscribe）。
- showcase Reactive 演示：`+1` → count=1、Computed 派生 ×2=2、Effect 同步=1（WS 端到端验证）。

### 2026-08-22 前端 keyed reconciliation 补丁粒度细化（P2 #1）

### 2026-08-22 pushUpdate 推送合并——流式多 token 一次下发（补丁粒度闭环）

**实现功能**
- `PushCoalescer`（src/push_coalescer.cj）：服务端推送合并状态机——首个 pushUpdate 标记会话并"武装"flush（返回 true），窗口内后续 pushUpdate 只追加（去重），flush 时 beginFlush 一次性取走。6 个单测。
- `App.pushUpdate` 的 ReRender 路径改为延迟下发：`markPushPending(sid)` → `spawnPushFlush()`（后台线程 sleep `config.pushFlushMs`（默认 15ms）后加锁逐个 `flushSessionPush` → `sendPatch`）。
- `AppConfig.pushFlushMs`：合并窗口配置。
- `App.sendPatchCount`：sendPatch 调用计数（诊断/测试）。
- 用户触发的 `runAction` **不受影响**（仍即时下发）；只有服务端推送合并。

**端到端验证（cjxt 内真实 WS）**
- `push_coalesce_e2e_test.cj`：启动真实 App + `WebSocket.upgradeFromClient` 建会话 → 5 次 pushUpdate 突发 → `sendPatchCount == 1` + 客户端收到单帧 patch 且含 `n=5`。**147 个单测全过。**
- 关键：cjxt 测试里做 WS 客户端需 `import stdx.crypto.kit.*`（否则 "Global crypto kit is not set"）；`upgradeFromClient` 依赖 target 级 digest link-option。
- Cangjie 坑：`for (i in 1..5)` 是**半开区间** `[1,5)` 只跑 4 次——闭区间用 `1..=5`。

**效果**：聊天流式每 token 的 pushUpdate 从"各自 sendPatch（整页重渲染+下发）"变为"一个窗口合并为一次 sendPatch"——配合 keyed reconciliation，流式从"每 token 整页重建"到"每窗口一次局部更新"的完整闭环。

### 2026-08-22 响应式缺口闭合：组件用上 computed/effect + Effect 重入保护 + 客户端组件 update-on-reconcile

**缺口 #2：组件用上 computed/effect（脏追踪穿透 + Readable 接口）**
- `Readable<T>` 接口（get()）：`Signal` 与 `Computed` 都实现——组件/框架的**只读输入统一接受** Signal 或 Computed。
- `Markdown.bind` 改为接受 `Readable<String>`（Computed 可驱动内容；Signal 天然兼容）。
- `reactive_component_test.cj`：**关键集成测试**——组件渲染读 Computed，依赖信号变化 → computed 失效 → 组件标脏（脏追踪穿透 computed，含链式/共享/effect 驱动）。4 + 1 测试。
- 教训：测试触发 markDirty 后必须 `RenderContext.clearDirty()`，否则残留的全局 dirtyComponents 污染并行/后续测试（`testCollectDirtyParentOverrideChild` 间歇失败根因）。

**缺口 #3：Effect 重入保护**
- `Effect` 加 `running/pending` 状态：执行中依赖又变 → 标 pending，**本次结束后统一重跑一次**（而非递归）——防自写依赖的 effect 栈溢出。
- 测试：自写 +1 有界收敛不栈溢出；写回相同值（相等性）只跑一次；dispose 后不再重跑。

**缺口 #4：客户端组件 update-on-reconcile（瞬时状态跨 patch 保留）**
- 原缺陷：客户端组件（Tooltip/Popover）reconcile 时**总是 destroy+重建**，`update()` 契约从未被调用——父组件重渲染（如流式 patch）会关闭已打开的 tooltip/popover。
- 修复：`createNode` client 分支返回实际元素（统一 `__cjxtComp` 位置）；`matchesNode` 按组件名匹配（**大小写敏感**，用原始 type）；`reconcileNode` client 分支调 `comp.update(props, el)` + 同步 data-action-*。
- 验证：Node + 最小 DOM stub 逻辑测试（createNode 标记/matchesNode 匹配与区分/reconcile 调 update + actions 同步/非 client 不调 update）全过——比 flaky 的 agent-browser 更可靠。

**验证**
- `cjpm test`：155 个单测全过。
