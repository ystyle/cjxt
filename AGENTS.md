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
5. **CSS**：Element Plus SCSS `public/scss/element-plus/`，编译到 `public/css/element-plus.css`（`@EmbedString` 编译时嵌入）。CSS module 在 `examples/public/css/bundle.css`。构建顺序：**先** `bash scripts/build-css.sh` 编译 EP 样式（同步输出到 `examples/public/css/element-plus.css`，因为 `@EmbedString` 按包根目录解析路径，embed 1.0.4 从编译器 `-p` 参数定位），**再** `cd examples && cjpm build`（含生成 CSS module）。
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
- `@EmbedString("public/css/element-plus.css")` 按**包根目录**（包含 `src/` 的目录）解析路径。embed 1.0.4 从编译器 `-p` 参数提取包根。cjpm 每个包单独编译，各自的 `-p` 指向各自的 `src/`：`cjxt` 包 → `.../cjxt/src` → 根 `.../cjxt/`，`examples` → `.../examples/src` → 根 `.../examples/`。`build-css.sh` 必须同步输出到 root 和 `examples/public/css/element-plus.css`。

## 后续计划

### P0 — 框架基础设施
- [x] 路由参数 `[id]`：RouteRegistry 改用 RouteEntry.doMatch 匹配，支持 `/user/[id]`
- [x] Form 增强：校验体系（rules、validate、状态 class）
- [x] History API（Issue #1）：前端 pushState/popstate 全流程
- [x] onClick 简化重载：Button/MenuItem/Tag/Link 支持 `(ActionContext) -> Unit`
- [x] 优化组件样式导入：`@EmbedString` + `App.addCSS`/`UseComponent` 实现 CSS 编译时嵌入+运行时服务。依赖 cjxt 的项目不再需要 `componentsCss` + `serveStatic` 服务独立 CSS 文件。`download-ep-css.sh` 保留供其他场景使用

### P1 — 组件完善
- [x] Table + TableColumn：数据驱动 / 排序 / 多选 / 高亮当前行 / 斑马纹 / 边框 / 固定列 / 汇总行
- [x] Dialog：模态框
- [x] Drawer：抽屉
- [ ] Tooltip / Popover：定位浮层
- [ ] Tabs：标签页
- [ ] Progress / Avatar / Empty：简单展示组件

### P2 — 基础设施第二阶段
- [x] #3 客户端组件（Client Component）：`@ClientComponent` 宏 + `ClientComponentNode` + 前端运行时 + Tooltip 示例
- [ ] #4 DOM 事务（DOM Transaction）：批量更新 + 过渡动画

### P3 — 剩余组件
- [ ] P0/P1 完成后的全部剩余组件（Dropdown / Pagination / Tree / DatePicker 等）

### 不做先行
- HMR、code splitting — Cangjie 静态编译无需
- DevTools — 组件稳定后再做
- `@rpc` 宏 — 和 #3 客户端组件一起做

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
- `@EmbedString("public/css/element-plus.css")` 按 `cjpm build` 时的**包根目录**解析路径（embed 1.0.4 从编译器 `-p` 参数定位）；在 `examples/` 下编译会读取 `examples/public/css/element-plus.css`。因此 `build-css.sh` 必须同步输出到 root 和 `examples/public/css/element-plus.css`。

**agent-browser 注意事项**
- 使用 `agent-browser click @ref` 在某些情况下 cjxt 前端不会捕获事件。
- 改用 `eval("element.dispatchEvent(new MouseEvent('click', {bubbles:true}))")` 确保 DOM 事件正确派发。

### 2026-06-26 Dialog 组件实现与 `@EmbedString` 路径陷阱

**实现功能**
- 新增 `Dialog.cj` 组件，支持 Props：`visible`、`title`、`width`、`top`、`showClose`、`closeOnClickModal`、`closeOnPressEscape`、`modal`、`center`/`alignCenter`、`fullscreen`、`destroyOnClose`、`beforeClose`、`header`/`footer` slots。
- 从 Element Plus 源码复制 `dialog.scss` 与 `overlay.scss` 到 `public/scss/element-plus/` 并引入 `element-plus.scss`。
- 在 `showcase.cj` 添加基础 Dialog 演示（打开按钮 + title + footer 取消/确认）。

**问题 1：Dialog 在浏览器中不可见**
- 根因：`@EmbedString("public/css/element-plus.css")` 按 `cjpm build` 时的**包根目录**解析路径（embed 1.0.4 从编译器 `-p` 参数定位）。我们在 `examples/` 下执行 `cjpm build`，它读取的是 `examples/public/css/element-plus.css`（旧缓存，不含 dialog 样式），而不是 root 的 `public/css/element-plus.css`。
- 修复：更新 `scripts/build-css.sh`，编译后同步复制 `public/css/element-plus.css` 到 `examples/public/css/element-plus.css`；清理 `target/release/cjxt/` 缓存后重新构建。
- 教训：组件新增 SCSS 后，必须确认嵌入的 CSS 文件确实包含新组件样式；通过浏览器 `document.styleSheets` 和 fetch CSS 内容可快速验证。

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
- Cangjie 属性宏的 attr 参数使用 `[...]` 语法：`@ClientComponent[js: "path"]`。
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

**问题 7：平坦参数函数（`Tooltip("a", "b")`）生成失败**
- `parseDecl(手动拼接的 Tokens)` 对参数列表的 token 序列解析有兼容性问题。尝试了直接拼接 token、`quote($(params))` 等方案均不行。
- 当前保留 `render(props: HashMap)` API。调用方需手动构造 HashMap。

**验证**
- `cjpm test`：42 个单元测试全部通过。
- `agent-browser`：Tooltip 渲染正确，hover 显示/隐藏正常。服务端注册 JS blob，前端动态加载后渲染。
