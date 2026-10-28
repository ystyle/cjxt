# cjxt 并发状态分类总表

> 本文是框架并发约定的**单一出处**。
> 新增任何跨线程共享状态前，先在这里归类；归不进现有类别，说明需要重新设计。

## 一、执行体模型（为什么会有并发问题）
---

stdx HTTP server 的每个请求从**协程池**取一个协程处理（ServicePoolConfig），
而仓颉的 `spawn` 创建的是**仓颉线程**（M:N 用户态线程，非 OS 线程）。
对 cjxt 而言，并发执行体有这些：

  · HTTP 请求协程   —— 每次页面请求走 servePage → sessions.create
  · WS 连接协程     —— 每条连接一个 listenLoop；消息处理、断连回收都在这
  · 推送 flush 协程 —— pushCoalescer 合并后统一下发
  · 巡检协程        —— 每 30s 调用 sessions.cleanup()
  · 业务自起协程    —— 应用的 onMount / 定时任务等

它们**可能同时**访问同一份框架状态。下面把状态按「该串行化还是该隔离」分成四类：

  A 类 · 执行上下文（ThreadLocal）
  B 类 · 共享可变状态（每实例一把锁）
  C 类 · 会话拓扑（分片 + 每片读写锁）
  D 类 · 会话执行序（每会话一把锁）

## A 类 · 执行上下文 —— 用 ThreadLocal
---

**判据**：这个状态回答的是「**我这一轮**正在干什么」，而不是「全局是什么」。
它天然属于单次调用链，跨执行体共享毫无意义。

| 状态 | 位置 | 语义 |
|---|---|---|
| `scopeStack` | `SignalTracker.scopeStackTL` | 当前这条 render 链的自动追踪栈 |
| `collectorStack` | `SignalTracker.collectorStackTL` | computed/effect 重算时的依赖收集栈 |
| `batchDepth` / `batchChanged` | `SignalTracker.batchDepthTL` / `batchChangedTL` | 批量更新的嵌套深度与本轮待通知节点 |
| `untrackedDepth` | `SignalTracker.untrackedDepthTL` | untracked 嵌套深度 |
| 渲染捕获 `capture` / `captureSid` | `RenderContext.captureTL` / `captureSidTL` | 本轮渲染产出了哪些组件 |

**为什么必须线程局部**（2026-10 修复的真实事故）：
这些栈曾是进程级静态变量。A 执行体 `enterScope` 后，B 执行体 `exitScope`
执行 `remove(size-1..size)` 会弹掉 **A 的** 栈帧 → 组件被登记到**错误的会话**
名下、订阅错乱 → `notify` 里调空指针 → **进程 SIGSEGV**。

**前提约束**：ThreadLocal 成立的前提是「一次 handler 执行从头到尾在同一条
仓颉线程上」。仓颉没有 async/await，渲染链路（`renderWithScope` → `render`
→ `expandTree`）全是同步调用、没有让出点，因此成立。
⚠️ 若将来引入任何会让出执行的机制（用户态调度/回调续体），A 类必须改成
显式传递的上下文对象（作为参数一路传下去），否则会静默串台。

## B 类 · 共享可变状态 —— 每实例一把 Mutex
---

**判据**：这个状态被**多个执行体**读写，但它的语义是「一份共享数据」，
不能按执行体或按会话拆开。

| 状态 | 锁 | 说明 |
|---|---|---|
| `ReactiveNode.subs` | `ReactiveNode.subsLock` | 同一 Signal 被多执行体订阅/退订/通知 |
| `SignalTracker.dirtyComponents` | `SignalTracker.dirtyLock` | 脏组件队列：sendPatch 按会话挑自己的 |
| `PushCoalescer.pending` / `armed` | `PushCoalescer.lock` | 任意 pushUpdate 调用方并发 mark |

**共同模式**：`notify` 一类「遍历并回调」的操作必须
**锁内取快照、锁外回调** —— 回调里会再进来 subscribe/unsubscribe
（effect 重跑、组件重渲），持锁回调会自锁。

## C 类 · 会话拓扑 —— 分片 + 每片 ReadWriteLock
---

即 `SessionManager`：会话注册表。被 HTTP（建）、WS（查/删）、巡检（遍历+删）
三方并发访问。裸 `HashMap` 在「一边遍历一边增删」下会**让进程卡死**
（实测：测试整轮超时、日志一行为空）或 SIGSEGV。

**为什么不做 Go 式 Hub**（单执行体独占 map + 消息投递）：
仓颉标准库**没有 Channel**，只能自建「投递 → 等回传 → 被唤醒」机制，
而 chan-bench 实测该往返是 **1130–1610 ns/次**
（`chan-bench-cj/docs/patterns.md` §5），且正是其「反模式」表里
「用队列传任务」一项。会话查找在每个 WS 消息的热路径上，不该付这个代价。

**采用分片**（同 patterns 模式 D）：按会话 id 哈希分 16 片，
每片一把 `ReadWriteLock` + 一张表：
  · 查找/统计走读锁 → 不同分片可并发；
  · 建/删/回收走写锁 → 只锁 1/16 的写域；
  · `cleanup` 各片在自己的写锁内完成「遍历 + 删除」，无跨片锁顺序问题。

代价：`size()` / `cleanup()` 要遍历全部 16 片；且不是原子的全局快照
（「回收过期」允许这点误差）。

## D 类 · 会话执行序 —— 每会话一把 Mutex
---

即 `Session.renderLock`：串行化**本会话**的 handler 执行与渲染，
保护 `session.tree`、组件订阅、`session.handlers` 等会话内可变状态。

**为什么是每会话而不是全局一把**（2026-10 改动）：
早期用 `SignalTracker.execMutex`（全进程一把），把**所有会话的渲染串行化**，
多用户时是硬瓶颈。而不同会话之间**没有共享的可变渲染状态**——
渲染上下文是 A 类（线程局部）、订阅表是 B 类（各有锁）、捕获也是 A 类。
所以全局锁纯属过度保护。

覆盖范围（原来用全局锁的四处）：
  · `runAction`（action 处理）
  · `dispatchBind`
  · `dispatchDomResult`（DOM 事务续体）
  · `pushUpdate` 单会话推送

**跨会话场景的处理**：
  · 推送合并 flush 一次处理**多个**会话 → 逐个会话各取自己的 `renderLock`，
    不整批持锁（不同会话 flush 互不阻塞）；
  · 巡检回收只动会话拓扑（C 类已加锁），**不需要** D 类锁。

## 二、新增状态时的自查清单
---

1. 它回答的是「我这一轮在干什么」吗？           → A 类（ThreadLocal）
2. 它是一份被多执行体共享的数据吗？             → B 类（每实例 Mutex）
3. 它是「哪些会话存在」这类拓扑吗？             → C 类（分片读写锁）
4. 它是「某个会话内部的执行顺序」吗？           → D 类（每会话 Mutex）
5. 都不属于 → **停下来重新设计**，不要随手加一把全局锁。

三个高频错误：
  · 用全局锁保护本该按会话隔离的状态（性能崩，且掩盖真实的共享点）；
  · 把执行上下文放进静态变量（→ SIGSEGV / 数据串台）；
  · 「遍历 + 修改」同一个容器而不加锁（→ 卡死 / SIGSEGV）。
