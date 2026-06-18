# cjxt — 仓颉全栈服务端驱动 UI 框架

## 仓颉语言
- 语法问题使用 `cangjie_docs` 工具查找，不要猜 API 和语法（包括 `ArrayList.sort`、`JsonWriter.writeNull` 等看似显然的 API，都先查再写）
- 实现不确定的功能时，先在项目已有代码里 `grep` 查找相似用法，确认 API 存在和签名
- 每完成一个阶段任务，在 AGENTS.md 的「代码总结」节记录该阶段遇到的问题和学到的东西
- 在提示语法错误时使用 `cangjie-mem` 加载语言级记忆
- 包名声明使用 `.` 分隔：`package cjxt`、`package cjxt.macros`

## 要求
- 每次需要失败的用例，需要添加到单元测试里，沉淀下来

## 组件实现流程

参照 Element Plus(本地: ~/Projects/element-plus/) 的属性、样式和事件来设计和实现组件。

### 步骤

1. **查 Element Plus 文档**：确认组件的 Props、Slots、Events 三个维度
2. **类型定义**：在 `src/components/Types.cj` 中定义该组件的参数枚举类型
3. **框架能力确认**：现有框架是否支持本次实现需要的所有特性？（事件、CSS、信号绑定等）
4. **实现组件**：`src/components/<Name>.cj`，class `<: Component`（改名后）
5. **CSS**：Element Plus SCSS `public/scss/element-plus/`，编译后进 `bundle.css`（构建顺序：先 `cjpm build` 生成 CSS module 内容，再 `./scripts/build-css.sh` 追加 Element Plus 全局样式到同一 bundle.css）
6. **Showcase 演示**：`examples/src/showcase.cj` 添加组件演示
7. **浏览器测试**：启动演示服务 → `agent-browser` 验证交互

### 现状

当前已实现的组件（Button/Card/Input/Radio/Switch 等）是按旧流程做的，较简陋。之后按此流程重新完善。

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

## 进度

### Signal 响应式系统 — ✅ 100%

| 组件 | 状态 |
|------|------|
| `Signal<T>` get/set/update/subscribe | ✅ |
| `SignalTracker` scopeStack / enterScope/exitScope / currentSub | ✅ |
| `Store<S>` | ✅ |
| `Component.renderWithScope(path)` 组件级 Signal 依赖追踪 | ✅ |
| `Component.markDirty()` 组件级脏标记 + dirtyRegistry | ✅ |
| `sendPatch` 只重渲脏组件，砍掉 diffTree | ✅ |
| `serializeSubtree` 一体化序列化（JSON + handlerMap） | ✅ |
| 状态实例一致性（servePage/applyNav 补 `onMount`） | ✅ |
| `--static` 编译 (examples) | ✅ |
| 前端点击事件委托 + SVG namespace | ✅ |
| **Input bind value 修复**（el.value 替代 setAttribute） | ✅ |

### 待办 Issue

| Issue | 标签 | 简述 |
|-------|------|------|
| #7 | `低` `优化` `服务端` | `readField` 多遍字符串解析统一为单次 JSON 解析 |
| #9 | `中` `架构` | execMutex / scopeStack session-local 改造 |
| #10 | `低` `优化` `前端` | 前端颗粒 diff 时 attachBind 事件解绑/重绑 |

### 已知约束

- `ActionContext.getState<T>()` vs 闭包捕获：当前 TodoPage/InputsPage 用 `ctx.getState`，建议改用闭包捕获保持一致
- `renderHTTP` 始终渲染 `/` 路径，其他路由仅通过 WS 导航

## 代码总结

### 2024-06-18 IME 输入修复

**问题**：新架构用 subtree replace 替换 input/textarea DOM，IME 组合状态被杀死，中文输入被打断。
**解决**：`src/html.cj` 前端 patch 处理加入三层保护：
1. `compositionstart`/`compositionend` 追踪 IME 状态，组合期间不触发 debounce send；
2. patch 更新时若目标为当前 `document.activeElement`，跳过 `.value` 覆盖；
3. 绑定 input 只更新 `.value` 不 `replaceChild`，保留 DOM 节点与事件监听器。
**提交**：`bc26e7e`

### 2024-06-18 Menu 组件样式补全

**问题**：`Menu.cj` 已存在但 `public/scss/element-plus/` 缺少 `menu.scss`，左侧边栏仍显示浏览器默认 `<ul>` 小黑点。
**解决**：
1. 从本地 `~/Projects/element-plus/packages/theme-chalk/src/menu.scss` 复制样式，加入 `element-plus.scss` 入口；
2. 修正 `build-css.sh` 输出到 `bundle.css`（追加模式），`entry.cj` 去掉 `componentsCss`，Element Plus 样式统一进 bundle.css；
3. 构建顺序：先 `cjpm build`（CSS module → bundle.css），再 `./scripts/build-css.sh`（Element Plus 全局样式 → bundle.css）。
**教训**：页面级 CSS（`style.css` 通过 `@importCSS`）经过 CSS module hash，如果选择器混合了 hash 过的 class 和 Element Plus 全局 class（如 `.showcase-sidebar .el-menu`），后者的 hash 选择器不会匹配 DOM 中的纯 class。这种跨域样式应全量放在全局 CSS 管道。
**提交**：`8e1f332`、`21e62f0`、`cb43c5a`
