# API 索引

## App

```cangjie

App()
    .host("0.0.0.0")                    // 绑定地址
    .port(8080)                          // 端口
    .configure(AppConfig(...))           // 应用配置
    .state<MyState>({ => MyState() })    // 注册共享状态
    .addCSS(css)                         // 嵌入 CSS（编译时嵌入的字符串）
    .addJS(js)                           // 嵌入 JS（编译时嵌入的字符串）
    .UseComponent()                      // 注册 cjxt 组件库的 EP 样式 + 前端 JS
    .serveStatic("/css", "public/css")   // 静态文件服务
    .serve()                             // 启动 HTTP + WS
```

## Embed（编译时资源嵌入）

依赖 [embed-cj](https://atomgit.com/ystyle/embed-cj) 库，在编译时将文件内容嵌入为字符串或字节数组：

```cangjie
import embed.macros.*

// 嵌入文本文件为 String
let css = @EmbedString("public/css/element-plus.css")
let js  = @EmbedString("public/js/cangjie-ui.js")

// 嵌入二进制文件为 Array<Byte>
let data = @EmbedBytes("assets/image.png")

// 嵌入整个目录为 EmbedFS
let assets = @EmbedDir("public/assets")
```

嵌入后的字符串可通过 `App.addCSS()` / `App.addJS()` 注册，框架自动生成 hash URL 并添加 `<link>` 或 `<script>` 标签。

## AppConfig

所有参数有默认值：

```cangjie
AppConfig(
    title: "cjxt App",
    favicon: "/favicon.ico",
    links: [("rel", "href")],         // 额外 <link> 标签
    scripts: ["/js/analytics.js"],    // 额外 <script> 标签
    primaryColor: "#409eff",
    fontFamily: "-apple-system, ...",
    borderRadius: "6px",
    cssBundle: "/css/bundle.css?v=2",
    componentsCss: "",                // 旧式 EP 样式路径（推荐改用 UseComponent()）
)
```

## Signal / Store

```cangjie

Signal<T>(value)                        // 创建信号
s.get()                                 // 读值
s.set(v)                                // 设值
s.update(fn: (T) -> T)                  // 计算更新
s.subscribe({ () => ... })              // 订阅
s.clearSubs()                           // 清订阅

// SignalTracker
SignalTracker.enterScope({ () => ... })  // 进入追踪作用域
SignalTracker.exitScope()                // 退出
SignalTracker.pendingRender              // 重渲标记
SignalTracker.dirtyComponents            // 脏组件列表
SignalTracker.execMutex                  // 执行互斥锁


Store<S>(initial)                        // 创建 store
store.get()                              // 读值
store.set(fn: (S) -> S)                  // 更新
store.subscribe({ () => ... })           // 订阅
```

## IComponent / Component

```cangjie

interface IComponent <: JsonSerializable
    render(): IComponent                 // 渲染（必须）
    markDirty() / isDirty() / clearDirty()
    renderWithScope(path: String)
    getActions(): HashMap<String, ActionHandler>
    onMount / onUnmount / onUpdate / onError
    toJson(w: JsonWriter)
    collectHandlers(out)

abstract class Component <: IComponent
    on(ev: String, h: ActionHandler): Component   // 注册事件

struct LifecycleContext
    getState<T>(): T where T <: AppState

struct ErrorContext
    let sessionId: String
    let actionName: String
    let error: Error

interface AppState   // 空接口，状态标记
```

## VNode / DSL

```cangjie

VNode(tag, children, attrs?, key?, actions?, handlers?)
    .attr(k, v)           // 设单个属性
    .attrs(map)           // 全量替换属性
    .style(v)             // 设 style
    .className(v)         // 设 class
    .key(k)               // 设差分 key
    .children(c)          // 替换子节点
    .onClick(h)           // 绑定点击
    .onClick(name)        // 通过名字绑定
    .on(ev, h)            // 泛用事件绑定
    .bind<T>(signal)      // 双向数据绑定

// 标签函数
div / span / button / input / a / p / h1 / h2 / h3
form / image / i / ul / li / text / Fragment / Empty / cssStyle
```

## Action

```cangjie

type ActionHandler = (ActionContext) -> PatchResult

struct ActionContext
    let sessionId: String
    let context: HashMap<String, String>
    let params: HashMap<String, String>
    let router: Router
    let pushFn: (Array<PatchEntryMsg>) -> Unit
    let sessionStates: HashMap<String, AppState>
    let route: RouteContext           // route.params / route.push(path)
    func push(patches): Unit
    func getState<T>(): T where T <: AppState

enum PatchResult { ReRender | Patch(Array<PatchEntry>) }

struct Router
    let sessionId: String
    let navigateFn: (String) -> Unit
    func push(path: String): Unit
```

## RouteRegistry

```cangjie

RouteRegistry.global()
    .register(path, factory)              // 注册路由
    .register(path, factory, title)       // 带标题
    .register(path, factory, title, guard) // 带守卫
    .register(path, factory, title, guard, layout) // 全参数
    .create(path): Option<IComponent>     // 创建页面
    .getTitle(path): Option<String>       // 获取标题
    .checkGuard(path, ctx): Bool          // 检查守卫
    .getLayout(path): Option<LayoutFn>    // 获取布局

type RouteFactory = () -> IComponent
type LayoutFn = (IComponent) -> IComponent
```

## RenderContext

```cangjie

RenderContext.expandTree(c, path)                 // 展开组件树
RenderContext.replaceTreeAtPath(tree, path, sub)  // 替换子树
RenderContext.collectHandlersFromTree(c, out)     // 收集 handlers
RenderContext.collectDirty()                       // 收集脏组件
RenderContext.clearDirty()                         // 清理脏标记
```

## CssModule

```cangjie

CssModule(map: HashMap<String, String>)
    .get(name): String     // 原始名 → hash 名

cssModule(pairs: Array<(String, String)>): CssModule  // 辅助构造
```

## Session

```cangjie

SessionManager(ttlMillis: Int64)
    .create(page, tree): Session
    .save(id, page, tree): Session
    .get(id): Option<Session>
    .remove(id)
    .cleanup()
    .generateId(): String

Session
    .touch()
    .updatePage(page, tree)
    .isExpired(ttl: Int64): Bool
```

## WS

```cangjie

wsSendJson<T>(ws, msg) where T <: JsonSerializable
wsSendText(ws, text)
wsClose(ws)
```

## Table

```cangjie
// src/components/Table.cj
class TableColumn
    colProp(v): TableColumn
    label(v): TableColumn
    width(v: Int64): TableColumn
    minWidth(v: Int64): TableColumn
    fixed(v: TableFixed): TableColumn     // Left | Right
    sortable(): TableColumn
    align(v: TableAlign): TableColumn      // Left | Center | Right
    colType(v: TableColumnType): TableColumn // Default | Selection | Index
    showOverflowTooltip(): TableColumn
    className(v): TableColumn
    formatter(f: (String) -> String): TableColumn
    sortBy(v): TableColumn
    reserveSelection(): TableColumn
    selectable(f: (HashMap<String, String>) -> Bool): TableColumn

class Table <: Component
    data(signal): Table
    add(col: TableColumn): Table
    stripe(): Table
    border(): Table
    height(v): Table
    maxHeight(v): Table
    size(v: ComponentSize2): Table
    fit(v: Bool): Table
    showHeader(v: Bool): Table
    highlight(): Table
    emptyText(v): Table
    showSummary(): Table
    sumText(v): Table
    sortColumn(signal: Signal<String>): Table
    sortOrder(signal: Signal<SortOrder>): Table
    selectedRows(signal): Table
    currentRow(signal): Table
    rowClassName(fn: (HashMap<String,String>, Int64) -> String): Table
    rowStyle(fn: (HashMap<String,String>, Int64) -> String): Table
    cellClassName(fn: (HashMap<String,String>, TableColumn, Int64, Int64) -> String): Table
    cellStyle(fn: (HashMap<String,String>, TableColumn, Int64, Int64) -> String): Table
    headerRowClassName(fn: (Int64) -> String): Table
    headerCellClassName(fn: (TableColumn, Int64) -> String): Table
    headerRowStyle(fn: (Int64) -> String): Table
    headerCellStyle(fn: (TableColumn, Int64) -> String): Table
```
## Dialog

```cangjie
// src/components/Dialog.cj
class Dialog <: Component
    init(children: Array<IComponent>)
    visible(signal: Signal<Bool>): Dialog
    title(v: String): Dialog
    width(v: String): Dialog
    top(v: String): Dialog
    showClose(v: Bool): Dialog
    closeOnClickModal(v: Bool): Dialog
    closeOnPressEscape(v: Bool): Dialog
    modal(v: Bool): Dialog
    center(): Dialog
    alignCenter(): Dialog
    fullscreen(): Dialog
    destroyOnClose(): Dialog
    beforeClose(h: ActionHandler): Dialog
    header(v: Array<IComponent>): Dialog
    footer(v: Array<IComponent>): Dialog
```
## Drawer

```cangjie
// src/components/Drawer.cj
enum DrawerDirection: LTR | RTL | TTB | BTT

class Drawer <: Component
    init(children: Array<IComponent>)
    visible(signal: Signal<Bool>): Drawer
    title(v: String): Drawer
    direction(v: DrawerDirection): Drawer
    size(v: String): Drawer
    showClose(v: Bool): Drawer
    closeOnClickModal(v: Bool): Drawer
    closeOnPressEscape(v: Bool): Drawer
    modal(v: Bool): Drawer
    withHeader(v: Bool): Drawer
    destroyOnClose(): Drawer
    beforeClose(h: ActionHandler): Drawer
    header(v: Array<IComponent>): Drawer
    footer(v: Array<IComponent>): Drawer
```
## Form

```cangjie
// src/components/Form.cj
struct FormRule
    init(required?, message?, min?, max?, pattern?)
    check(value): String        // 返回错误文本，空字符串=通过

class FormItem <: Component
    label(v): FormItem
    required(): FormItem
    error(v): FormItem          // 直接设错误文本
    rule(r: FormRule): FormItem
    bind(signal: Signal<String>): FormItem    // 校验用
    errorSignal(signal): FormItem             // 错误跨 render 持久化
    validate(): Bool                           // 返回是否通过
    clearValidate()

class Form <: Component
    init(children)                             // 自动识别 FormItem 子项
    add(item: FormItem): Form
    validate(): Bool                           // 统一校验所有子项
    clearValidate()
```

## 组件枚举



```cangjie
ButtonKind:       Default | Primary | Success | Warning | Danger | Info
ComponentKind:    Default | Primary | Success | Warning | Danger | Info | Plain
ButtonSize:       Large | Default | Small
ButtonNativeType: Button | Submit | Reset
ComponentSize:    Large | Default | Small
TextSize:         Default | Large | Small
TagSize:          Default | Large | Medium | Small | Mini
TagEffect:        Dark | Light | Plain
CardShadow:       Always | Hover | Never
RowJustify:       Start | End | Center | SpaceAround | SpaceBetween | SpaceEvenly
RowAlign:         Top | Middle | Bottom
DividerDirection: Horizontal | Vertical
ContentPosition:  Left | Center | Right
SpaceDirection:   Horizontal | Vertical
MenuMode:         Horizontal | Vertical
LinkUnderline:    Always | Hover | Never
SortOrder:        None | Ascending | Descending
TableColumnType:  Default | Selection | Index
TableAlign:       Left | Center | Right
TableFixed:       Left | Right
ComponentSize2:   Large | Default | Small
DrawerDirection:  LTR | RTL | TTB | BTT
```

## CangjieUI（前端 JS）

通过 `@EmbedString` 编译时嵌入二进制（`public/js/cangjie-ui.js`），由 `UseComponent()` 或 `addJS()` 注册。运行时由 `/_cjxt/js/{hash}.js` 提供服务，无外部依赖：

```javascript
class CangjieUI {
    constructor(container, sessionId, initialTree)
    attachClickDelegate()                 // 事件委托
    connectWS()                           // WS 连接（自动重连 3s）
    handleMsg(msg)                        // 消息分发
    send(data)                            // JSON 发送
    loadNewPage(msg)                      // 全量替换
    renderTree(node, parentEl)            // 递归渲染
    attachBind(el)                        // 绑定 input 事件
    applyTreePatches(trees)               // 颗粒 patch
    renderSubtree(node)                   // 子树渲染
}
```
