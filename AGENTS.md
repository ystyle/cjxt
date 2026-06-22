# cjxt — 仓颉全栈服务端驱动 UI 框架

## 仓颉语言
- 语法问题使用 `cangjie_docs` 工具查找，不要猜 API 和语法（包括 `ArrayList.sort`、`JsonWriter.writeNull` 等看似显然的 API，都先查再写）
- 实现不确定的功能时，先在项目已有代码里 `grep` 查找相似用法，确认 API 存在和签名
- 每完成一个阶段任务，在 AGENTS.md 的「代码总结」节记录该阶段遇到的问题和学到的东西
- 在提示语法错误时使用 `cangjie-mem` 加载语言级记忆
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
5. **CSS**：Element Plus SCSS `public/scss/element-plus/`，编译到 `public/css/element-plus.css`（项目根 + `examples/public/css/` 各一份）。CSS module 在 `examples/public/css/bundle.css`。构建顺序：先 `cd examples && cjpm build` 生成 CSS module，再 `./scripts/build-css.sh` 编译 EP 样式。
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

## 后续计划

### P0 — 框架基础设施
- [ ] 路由参数 `[id]`：RouteRegistry 改用 RouteEntry.doMatch 匹配，支持 `/user/[id]`
- [ ] Form 增强：校验体系（rules、validate、状态 class）
- [ ] 优化组件样式导入：依赖库自动分发 EP 样式（中央库/git 依赖均可），当前 download-ep-css.sh 为临时方案

### P1 — 组件完善
- [ ] Table + TableColumn：数据驱动 / 排序 / 筛选
- [ ] Dialog：模态框
- [ ] Drawer：抽屉
- [ ] Tooltip / Popover：定位浮层
- [ ] Tabs：标签页
- [ ] Progress / Avatar / Empty：简单展示组件

### P2 — 基础设施第二阶段
- [ ] #3 客户端组件（Client Component）：前端 JS 组件系统
- [ ] #4 DOM 事务（DOM Transaction）：批量更新 + 过渡动画

### P3 — 剩余组件
- [ ] P0/P1 完成后的全部剩余组件（Dropdown / Pagination / Tree / DatePicker 等）

### 不做先行
- HMR、code splitting — Cangjie 静态编译无需
- DevTools — 组件稳定后再做
- `@rpc` 宏 — 和 #3 客户端组件一起做
