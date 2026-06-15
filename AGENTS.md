# cjxt — 仓颉全栈服务端驱动 UI 框架

## 仓颉语言
- 语法问题使用 `cangjie_docs` 工具查找，不要猜 API 和语法
- 在提示语法错误时使用 `cangjie-mem` 加载语言级记忆
- 包名声明使用 `.` 分隔：`package cjxt`、`package cjxt.macros`

## 要求
- 每次需要失败的用例，需要添加到单元测试里，沉淀下来

## 项目结构

```
src/
├── main.cj                 入口
├── vnode.cj                ComponentNode 数据模型 + 标签辅助函数
├── component.cj            Component 接口 / 生命周期定义
├── action.cj               ActionContext / PatchResult / Router
├── diff.cj                 diff / patch 引擎
├── session.cj              会话管理 / TTL
├── registry.cj             路由匹配（@Page 宏运行时支持）
├── html.cj                 HTML 壳生成 + 内联前端 JS
├── app.cj                  App 类（host/port/serve + WS 会话循环）
├── ws.cj                   wsSendJson / wsSendText / wsClose
├── macros/                 宏定义目录（macro package）
├── demo/                   演示应用（demo 子包）
└── xxx_test.cj             测试文件（与源码同包）
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
