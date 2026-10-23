# 组件库规划

基于 Element Plus 样式风格，使用 cjxt 框架实现服务端驱动 UI 组件。

## 设计原则

- **服务端渲染**：所有组件以 vnode 形式在服务端构建，通过 WS 增量推送
- **CSS 隔离**：使用 `@importCSS` 宏 + hash 类名，组件样式互不污染
- **数据驱动**：表单组件通过 `bind<T>()` 或闭包捕获的 Signal 管理状态
- **交互收敛**：前端 JS 维持轻量，复杂交互优先走 WS action + 服务端逻辑
- **Zero Deps**：组件库零外部依赖，纯 cjxt 标准库

## 阶段分组

### Stage 1 — 布局与基础（12 个）

**复杂度最低，纯 vnode + CSS，基本不需要交互逻辑。**

| 组件 | 对应 EP | 说明 |
|------|---------|------|
| `Button` | el-button | size / type / round / loading / icon |
| `ButtonGroup` | el-button-group | 按钮组容器 |
| `Row` | el-row | flex 布局行，gutter / justify / align |
| `Col` | el-col | 栅格列，span / offset / push / pull |
| `Card` | el-card | 卡片容器，shadow / header slot |
| `Divider` | el-divider | 分割线，direction / content-position |
| `Text` | el-text | 文本，type / size / truncated |
| `Link` | el-link | 链接，type / underline / icon / href |
| `Tag` | el-tag | 标签，type / size / closable / hit |
| `Badge` | el-badge | 徽标，value / max / dot / is-dot |
| `Space` | el-space | 间距容器，size / direction / wrap |
| `Icon` | el-icon | 图标封装，基于 svg 或字体图标 |

### Stage 2 — 表单控件（10 个）

**核心交互组件，通过 cjxt 的 bind/action 体系驱动。**

| 组件 | 说明 |
|------|------|
| `Input` | 输入框，size / type / prefix / suffix / clearable |
| `InputNumber` | 数字输入，min / max / step / controls |
| `Switch` | 开关，active-value / inactive-value |
| `Radio` | 单选，value 绑定 + label |
| `RadioGroup` | 单选项组，v-model 等效 |
| `Checkbox` | 复选，indeterminate 状态 |
| `CheckboxGroup` | 复选框组 |
| `Select` | 下拉选择，options / filterable / multiple |
| `Slider` | 滑块，min / max / step / range |
| `Rate` | 评分，max / allow-half / show-text |

**配套基础设施**：`Form` + `FormItem` 校验体系（rules、validate、状态 class）

### Stage 3 — 数据展示（8 个）

**服务端渲染主力，行数据驱动，Table 是最核心的业务组件。**

| 组件 | 说明 |
|------|------|
| `Table` + `TableColumn` | 表格，数据驱动 / 排序 / 筛选 / 行展开 / 自定义列模板 |
| `Progress` | 进度条，percentage / status / stroke-width |
| `Avatar` | 头像，size / shape / src / icon / fallback |
| `Empty` | 空状态，image / description / size |
| `Descriptions` | 描述列表，border / column / direction |
| `Statistic` | 统计数值，value / title / prefix / suffix |
| `Result` | 结果页，status / title / sub-title |
| `Tag`（增强）| 增加可移除、过渡动画 |

### Stage 4 — 交互组件（12 个）

**需要 WS + 前端 JS 配合，涉及定位、动画、遮罩层等。**

| 组件 | 说明 |
|------|------|
| `Dialog` | 模态框，v-model / width / fullscreen / before-close |
| `Drawer` | 抽屉，direction / size / with-header |
| `Tooltip` | 文字提示，placement / effect / content |
| `Popover` | 弹出框，trigger / width / placement |
| `Popconfirm` | 气泡确认，title / confirm-button-text / cancel-button-text |
| `Dropdown` | 下拉菜单，trigger / command / hide-on-click |
| `Message` | 消息提示，type / duration / show-close |
| `Notification` | 通知，title / message / position / duration |
| `MessageBox` | 弹框，alert / confirm / prompt |
| `Tabs` + `TabPane` | 标签页，v-model / type / closable / addable |
| `Collapse` + `CollapseItem` | 折叠面板，v-model / accordion |
| `Pagination` | 分页，total / page-size / current-page / layout |

**前端扩展**：Stage 4 可能需要给 cjxt 前端 JS 添加以下能力：
- Teleport/Portal（Dialog/Drawer 的 body 挂载）
- 定位计算（Tooltip/Popover/Dropdown）
- 消息队列管理（Message/Notification）
- 动画过渡（CSS transition + 状态 class）
- 点击外部关闭

### Stage 5 — 复杂组件（~20 个）

**树、日期、级联、上传等，需在框架成熟后追加。**

| 类别 | 组件 |
|------|------|
| 导航 | `Menu` `SubMenu` `MenuItem` `Breadcrumb` `Steps` |
| 时间 | `DatePicker` `TimePicker` `TimeSelect` `DateTimePicker` `Calendar` |
| 树/级联 | `Tree` `TreeSelect` `Cascader` `CascaderPanel` |
| 其他 | `Transfer` `Upload` `ColorPicker` `Carousel` `Autocomplete` `Mention` `InputTag` |
| 虚拟化 | `SelectV2` `TableV2` `TreeV2` `VirtualList` |

## 进度

> 进度表更新于 2026-10-23。演示站（examples `/showcase`）按 8 组 56 项组织：
> 基础 11 / 表单 9 / 数据 10 / 导航 4 / 反馈 6 / 遮罩层 5 / 展示 6 / 高级 5

| Stage | 组件数 | 已实现 | 状态 |
|-------|--------|--------|------|
| Stage 1 布局与基础 | 12 | Button / ButtonGroup / Card / Col / Divider / Icon / Link / Row / Space / Tag / Text / Badge | ✅ 12/12 |
| Stage 2 表单控件 | 10 + Form | Checkbox / CheckboxGroup / Form / FormItem / Input / InputNumber / Radio / RadioGroup / Rate / Select / Slider / Switch | ✅ 12/12 |
| Stage 3 数据展示 | 8 | Avatar / Descriptions / DescriptionsItem / Empty / Progress / Result / Statistic / Table / TableColumn | ✅ 9/8 |
| Stage 4 交互组件 | 12 | Dialog / Drawer / Tooltip / Popover / Popconfirm / Dropdown / Message / Notification / MessageBox / Tabs+TabPane / Collapse+CollapseItem / Pagination | ✅ 12/12 |
| Stage 5 复杂组件 | 25 | **已做 12**：Menu / SubMenu / MenuItem / Breadcrumb / Steps（导航 5）、DatePicker / DateRangePicker / Calendar / TimePicker（时间 4）、Tree / Cascader（树/级联 2，CascaderPanel 集成于 Cascader）、Upload、VirtualList<br>**未做 12**：TimeSelect / DateTimePicker / TreeSelect / Transfer / ColorPicker / Carousel / Autocomplete / Mention / InputTag / SelectV2 / TableV2 / TreeV2 | 🟡 12/25 |

**计划外组件（已实现，非 Stage 清单）：** `Alert` / `Message` / `Notification` / `Loading` / `Skeleton`（反馈）、`Markdown` / `AutoScroll` / `Reactive`（Computed·Effect 演示）/ `VirtualList` / `DomTx`（高级能力演示）、下拉树级联等业务扩展随 P1-P3 迭代完成（见 AGENTS.md 后续计划）。

> ⚠️ 上面 Stage 5 的「未做 12」只是**当初 Stage 5 自己列的**范围，不是完整缺口——
> 布局族（`Container` 等）、展示族（`Timeline`/`Image` 等）从未进过任何 Stage。
> **完整缺口与补齐顺序见下一节。**

## 缺口全量清单（对齐 EP 文档口径）

> 核对于 2026-10-23。基准 = EP 文档页面向用户的组件页（`~/Projects/Nodejs/element-plus/docs/examples/`，80 个，
> `layout`/`border`/`transitions` 为归类页已排除），逐项比对 cjxt 的 `public class` / `public func` 实现。

**结论：80 项里已实现 74 项，缺 6 项独立组件。**
（2026-10-23 逐批推进：`Container` 族 53→54、`Scrollbar` 54→55，第 2-5 批 19 个组件 55→74。）

上面 Stage 表的「未做 12」只覆盖 Stage 5 当初列出的范围，**不含下面这些**——
尤其布局族与展示族从没进过任何 Stage。

> 计数口径：`Header`/`Aside`/`Main`/`Footer` 是 `Container` 的子件，随第 1 批一起做，不单列；
> `ColorPickerPanel`/`DatePickerPanel`/`CascaderPanel` 同理。EP 的 `message`/`notification`/`typography`
> 在 cjxt 已有对应（见文末对照表），不计入缺口。

### 缺口清单（按补的优先级排序）

**第 1 批 — 布局地基（2 项，最该先补）**

| 组件 | 状态 | 说明 |
|------|------|------|
| `Container`（含 `Header`/`Aside`/`Main`/`Footer`） | ✅ 已完成（2026-10-23） | 页面级布局族，见 `src/components/Container.cj`。语义标签 `section/header/aside/main/footer`；方向自动判定（有 Header/Footer 即纵向，显式 `direction` 优先）；尺寸走 `--el-header-height`/`--el-footer-height`/`--el-aside-width`，默认值由 scss 提供（60px/60px/300px）。 |
| `Scrollbar` | ✅ 已完成（2026-10-23） | 见 `src/components/Scrollbar.cj`。DOM 对齐 EP（`el-scrollbar > __wrap > __view`）；EP 的 JS thumb 方案在服务端模型下改为 `native` 开关：默认用浏览器原生滚动条，`native(false)` 时加 `__wrap--hidden-default` 隐藏原生滚动条（滚动能力保留）。 |

**第 2 批 — 高频展示件（4 项）**

| 组件 | 缺它的代价 |
|------|-----------|
| `Timeline` | ✅ 已完成 | `Timeline` + `TimelineItem`；`is-{mode}` 同时挂 `ul`/`li`（EP 靠 inject，cjxt 在 render 里扫子实例写回）。 |
| `Image` | ✅ 已完成 | lazy 用原生 `loading=lazy`；加载/失败态由调用方显式驱动（服务端拿不到 load/error 事件）；预览为简化版遮罩。 |
| `Segmented` | ✅ 已完成 | 选中滑块用服务端几何算（`flex:1` 等宽下 `calc(100%/n)` + `translateX`），替代 EP 的 ResizeObserver。 |
| `AvatarGroup` | ✅ 已完成 | 叠压交给 scss；组级 shape 无法区分"未设"与"显式 circle"，取舍已注明。 |

> （`AvatarGroup` 属"现有组件的形态变体"，3 个变体之一。）

**第 3 批 — 表单补全（4 项）**

| 组件 | 说明 |
|------|------|
| `RadioButton` / `CheckboxButton` | ✅ 已完成 | 在 `Radio.cj`/`Checkbox.cj` 内新增类，**原有类逐行未动**；Group 只加 match 分支，两种形态可混排。 |
| `InputOtp` | ✅ 已完成 | 每位一个 `__input-field` 包裹层（scss 的聚焦环挂这层）；值按 Rune 逐位铺开，中文不会切坏。`type` prop 因关键字改名 `kind`。 |
| `InputTag` | ✅ 已完成 | `__inner > span.el-tag ×N + __input-wrapper > input`；草稿文本不存内部信号（重渲染会丢），从 action params 现取。 |

**第 4 批 — 导航与定位（4 项）**

**全部已完成（2026-10-23），且四个组件零前端 JS**：

| 组件 | 做法 |
|------|------|
| `Affix` | CSS `position: sticky`（无需滚动监听）；受祖先 `overflow` 约束属 CSS 语义 |
| `Backtop` | 原生 `<a href="#">` 锚点回顶——cjxt 的 `dom_command` 没有 `scrollTo`，挂 action 只会空转 |
| `Anchor` | 原生 `href="#id"` + `scroll-margin-top` 补偿 offset |
| `PageHeader` | cjxt action（`route.push`），补了 Enter/Space 键盘可达 |

**第 5 批 — 高级交互（7 项）**

**全部已完成（2026-10-23）**：`ConfigProvider` / `Splitter` / `Carousel` / `Transfer` / `ColorPicker` / `Tour` / `Watermark`。
已知能力边界（均写在各文件头注释，非 TODO）：Tour 不定位目标元素（居中）、Carousel 无 autoplay、
Transfer 无 filterable、ColorPicker 无自由取色、Watermark 用 SVG 而非 canvas。
`Splitter` **拖拽已实现**（2026-10-23）：照 Slider 的既有模式走标准 `bind` 消息，
不新增协议消息；纯 bind 往返有一帧延迟（未做前端乐观更新，见下方能力边界表）。
`ConfigProvider` 因 cjxt 无上下文通道，改用 CSS 变量继承，必然多一层包裹元素。

另有 `InfiniteScroll`：EP 侧是**指令**不是组件，cjxt 需按服务端模型重新设计（见第 6 批末条）。

**第 6 批 — 联动组件与虚拟化（6 项，收益最低或依赖外部前提）**

| 组件 | 不着急的理由 |
|------|-------------|
| `Autocomplete` | `Select` 已支持 filterable，差的是"输入即建议"的交互形态。 |
| `Mention` | 场景窄（富文本框里 @ 人），Chat 富文本落地后再做。 |
| `TimeSelect` / `DateTimePicker` | `DatePicker`/`TimePicker` 已就绪，缺的是组合与时间轴扩展。 |
| `TreeSelect` | `Select` + `Tree` 都已就绪，缺的是组合。 |
| `SelectV2` / `TableV2` / `TreeV2` | EP 用虚拟滚动重写了这三者。cjxt 已有自研 `VirtualList`（`src/components/VirtualList.cj`），**应先评估「把 VirtualList 接进现有 Select/Table/Tree」是否够用**，够用则不该盲抄 EP 的重写版。AGENTS.md 亦记着「Table 待接入」。 |
| `InfiniteScroll` | 同上，先看 `VirtualList` 能否覆盖；EP 是指令式（`v-infinite-scroll`），cjxt 没有 v- 指令体系，需要新设计。 |

### 已在 cjxt 存在、但名字与 EP 不同的（不用补，避免重复实现）

| EP 名 | cjxt 实现 | 备注 |
|-------|-----------|------|
| `message` | `MessageHost`（`Feedback.cj:60`） | 用 Signal 列表驱动，非命令式 API |
| `notification` | `NotificationHost`（`Feedback.cj:150`） | 同上 |
| `typography` | `Text` | |
| `layout` / `border` | `Row` + `Col` / `Card` | EP 文档里是归类页，非独立组件 |
| `transitions` | 无对应组件 | 属于 CSS 动画，由 `public/scss` 承担 |

> ⚠️ 交叉核对结论：`Message`/`Notification` 在 Stage 4 标为已完成，指的确实是 `MessageHost`/`NotificationHost` 这对宿主组件；
> 若后续需要 EP 那种 `Message.success()` 式命令式调用，应作为**新的便利 API** 单独评估，不计入组件缺口。

### EP scss 的覆盖检查（2026-10-23 全量核对）

> 教训：**EP 把组件拆成多个 scss，只拷主文件会静默丢样式**（`collapse`+`collapse-item`、
> `splitter`+`splitter-panel`、`carousel`+`carousel-item`、`anchor`+`anchor-link`、`radio-group`、`checkbox-group`）。
> 拷之前 `ls theme-chalk/src/ | grep -i <组件名>` 看全量，并按 EP `index.scss` 的**相对次序**接入。

已补入（本轮之前缺失、但组件确实在用的）：

| scss | 影响的组件 | 缺失后果 |
|------|-----------|---------|
| `splitter-panel.scss` | Splitter | 无 `flex-grow:0`，`flex-basis` 尺寸模型失效（面板平分而非按 size） |
| `carousel-item.scss` | Carousel | 无 `position:absolute`，所有 item 纵向堆叠，轮播不成立 |
| `anchor-link.scss` | Anchor | `__link` 只有结构无样式（字号/行高/内边距/颜色/hover/is-active 全丢） |
| `radio-group.scss` | RadioGroup | 无 `display:inline-flex` + `flex-wrap`，一行放不下不换行；`font-size:0` 缺失导致项间出现空隙 |
| `checkbox-group.scss` | CheckboxGroup | 无 `font-size:0` / `line-height:0`，项间出现空隙 |

**经核对确认「不是缺口」的**（避免后人重复排查）：
- `dropdown-item.scss` / `tab-pane.scss` 在 EP 上游就是 **0 字节空文件**；`el-dropdown-menu__item`、`el-tab-pane` 的样式分别由 `dropdown.scss` 的 `e(item)` 与 EP 自身（无样式，仅 `role=tabpanel`）承担
- `spinner.scss`：cjxt **零使用** `el-spinner`，Loading 走 `el-loading-spinner`（`loading.scss` 已含）

## 能力边界（已实现但有取舍的组件）

> 下列组件**结构、类名、DOM 已对齐 EP**，但因 cjxt 是**服务端渲染模型**，某些纯客户端交互
> 无法实现或改用了等价方案。每一项都写进了对应组件的文件头注释，**不是 TODO、也不是漏做**。
> 若某项业务确实需要 EP 的完整交互，需要动 `public/js/cangjie-ui.js`（前端 JS 改造），单独立项评估。

| 组件 | 边界 | 原因 / 等价方案 |
|------|------|----------------|
| `Tour` | 不定位到目标元素，**居中显示** | 服务端拿不到目标 rect（EP 靠客户端 FloatingUI 测量）。`target` 仍落到 `data-tour-target`，供后续前端接线 |
| `Carousel` | **无 autoplay**，仅手动切换 | EP 用客户端 `setInterval` 推进，cjxt 组件无时钟。DOM 与 `data-carousel` 标记已备好 |
| `Carousel` | `type=card` 只落类名 + 遮罩 | 3D 层叠位移依赖容器实时像素宽 |

| `Transfer` | 无 `filterable` / `virtualScroll` | 需输入过滤与虚拟列表；交互上把"两侧勾选+箭头"压成"勾选即移动"一步，避免双份状态 |
| `ColorPicker` | 无 `showAlpha` / 自由取色 | EP 面板是饱和度区拖拽 + 色相条（大量指针交互），改为预设色板网格 |
| `Watermark` | 用 **SVG** 而非 canvas | 服务端无 canvas；SVG 的 `text`+`rotate` 等价，CSS 用法一致。无 image 型水印、无 MutationObserver 防篡改 |
| `Affix` | 走 **CSS `position: sticky`**，非 JS 测量 | 无需滚动监听；受祖先 `overflow` 约束属 CSS 语义。EP 的 `position:fixed` + teleport 补偿不适用 |
| `Affix` | `visibilityHeight` 类显隐做不到 | 纯客户端滚动状态，服务端读不到 |
| `Backtop` | **恒显示**，无 `visibilityHeight` 显隐 | 同上；阈值以 `data-visibility-height` 输出备用 |
| `Backtop` | 走原生 `<a href="#">`，非 action | cjxt 的 `dom_command` 只有 focus/scrollIntoView/setProperty/getProperty，**没有 `scrollTo`**，挂 action 只会空转 |
| `Image` | `lazy` 用原生 `loading="lazy"` | EP 用 IntersectionObserver + 滚动容器；原生属性语义等价且零前端代码 |
| `Image` | 加载中 / 失败态由**调用方显式驱动** | 服务端拿不到 img 的 `load`/`error` 原生事件 |
| `Image` | 预览为**简化版**遮罩 | 未做 EP 全套缩放/旋转/工具栏 |
| `Anchor` | 无 marker 跟随定位 | EP 用 rect 差值 + 客户端测量；改为 `current(href)` 静态或 `bindAnchorCurrent(Signal)` 外置驱动 |
| `Anchor` | 高亮不由滚动位置自动驱动 | 滚动位置是客户端状态，沿 VirtualList 的 Signal 外置结论 |
| `Segmented` | 选中滑块用**服务端几何计算** | 替代 EP 的 ResizeObserver：`flex:1` 等宽前提下 `calc(100%/n)` + `translateX`，逐像素一致；某项被内容撑开时会有偏差 |
| `AvatarGroup` | 组级 `shape` 会覆盖子头像 | `Avatar._shape` 非 Option、默认 Circle，服务端分不清"未设"与"显式 circle"；要混排需把该头像放组外 |
| `ConfigProvider` | 必多一层 `.el-config-provider` 包裹元素 | EP 靠 provide/inject 不输出元素；cjxt 无上下文通道，改用 **CSS 变量继承**。架构适配，非对齐疏漏 |
| `Timeline` | mode 下发是构造期副作用 | `Timeline.render()` 写子 item 的 `_timelineMode`；同一 item 实例复用到两个不同 mode 的 Timeline 会互相覆盖 |

### 与 EP 的其它已知差异（非能力边界，是有意的设计选择）

| 项 | 说明 |
|----|------|
| `Scrollbar` | EP 的 JS thumb 方案改为 `native` 开关：默认用浏览器原生滚动条，`native(false)` 时加 `__wrap--hidden-default` 隐藏原生滚动条（滚动能力保留） |
| `InputOtp` | EP 的 `type` prop 因 `type` 是仓颉关键字，改名为 `kind(...)`；原生 input 的 type 另叫 `inputType(...)` |
| `InputTag` | 草稿文本不存内部信号（组件重渲染会新建实例、内部状态丢失），改为从 action 的 `params.value` 现取 |
| `Anchor` | 只保留唯一构造器 `Anchor(Array<IComponent>)` + `static func ofLinks(...)`；双 init 重载会 `ambiguous match` |
| `PageHeader` | 比 EP 多做：`tabindex=0` 补了 Enter/Space 键盘触发（EP 模板只写 click） |

## CSS 加载流程

### 概览

组件库样式只有**一条**供给通道：`App.addCSS` → `cssBlobs`。

```cangjie
App()
  .UseComponent()      // EP 样式：@EmbedString 编译期嵌入二进制，内部调 addCSS
  .addCSS(siteCss())   // 页面样式模块：@importCSS / @defineCSS 的产物（含 "_css" 全文）
```

渲染期按承载方式自动选择交付形式：

| 承载 | 交付形式 |
|------|---------|
| HTTP（浏览器） | `<link href="/_cjxt/css/{hash}.css">`，由内置路由 `serveEmbeddedCSS` 提供内容 |
| 无 HTTP（WebView `file://`、自包含页面） | `<style>` 直接内联进 HTML（`selfContainedShell`） |

**不要用 `cssBundle` / `componentsCss` + `serveStatic`**：那条通道与 `addCSS` 重复，
且**只在 HTTP 下成立** —— 页面以 `file://` 加载时 `/css/*.css` 取不到，样式静默全丢。

### 两个来源

| 来源 | 内容 | 进 cssBlobs 的方式 |
|------|------|------------------|
| 组件库（EP） | 全局 BEM 类（`.el-button`、`.el-menu-item`） | `@EmbedString("public/css/element-plus.css")` 编译期嵌入，`UseComponent()` 交给 addCSS |
| 页面样式模块 | scoped 类（`.container_4507...`） | `@importCSS` / `@defineCSS` 返回值里的 `"_css"` 全文，由业务包导出后交给 addCSS |

`@importCSS` 的返回值是 `CssModule`，同时带 scoped 类名映射与 CSS 全文：

```cangjie
let css = @importCSS("style.css")
css.get("card")    // → "card_8387104332281640942"
css.get("_css")    // → CSS 全文（宏额外塞的一条，见 macros/define_css.cj 的 addCssEntry）

// 因此声明样式模块的包要导出全文取值函数（惯例名 siteCss）
public func siteCss(): String { css.get("_css") }
```

### 构建顺序（关键！）

```
./scripts/build-css.sh   # 先：sass 编译 EP SCSS → public/css/element-plus.css
cd examples && cjpm build # 后：@EmbedString 在编译期读取该文件
```

顺序反了会让 `@EmbedString` 读到旧文件（甚至不存在）——**必须先编译 SCSS，再编译仓颉**。

`public/css/bundle.css` 是宏在编译期汇总写出的**构建产物**，供人查看/比对；
框架运行期不读它（内容已随 `"_css"` 进二进制）。

### EP SCSS 变量复用

组件可通过 `public/scss/element-plus/custom/*.scss` 编写自定义样式，复用 EP 的 CSS 变量：

```scss
@use '../mixins/mixins' as *;
@use '../common/var' as *;

@include b(slider) {
  input[type="range"] {
    height: getCssVar('slider-height');        // → 6px
    background: getCssVar('slider-main-bg-color'); // → #409eff
  }
  input[type="range"]::-webkit-slider-thumb {
    width: getCssVar('slider-button-size');     // → 20px
    border: 2px solid getCssVar('slider-main-bg-color');
  }
}
```

在 `element-plus.scss` 中在原始 SCSS 之后 import 自定义文件：

```scss
@use 'slider.scss';
@use 'custom/slider-range.scss';  // 覆盖 / 扩展
```

### 服务端配置

```cangjie
App()
  .UseComponent()       // EP 样式（编译期嵌入，内部 addCSS）
  .addCSS(siteCss())    // 页面样式模块（@importCSS 的 "_css" 全文）
```

HTML 渲染结果（HTTP 承载；无 HTTP 时改为内联 `<style>`）：

```html
<link rel="stylesheet" href="/_cjxt/css/83575583.css">   <!-- EP -->
<link rel="stylesheet" href="/_cjxt/css/07646276.css">   <!-- 页面模块 -->
```

> `serveStatic` 只在你确实要另外分发静态文件（图片、字体）时才需要；
> 它**不再**承担 CSS 供给。

### 核心原则

1. **只有一条通道**：所有 CSS 都经 `App.addCSS` 进 `cssBlobs`，由框架按承载方式自动交付
2. **内容 hash 去重**：`addCSS` 按内容 hash 存表，同一份 CSS 交两次只留一份
3. **scoped 与全局共存**：页面模块走 `@importCSS` 的 hash 类名；EP 用全局 BEM 类名，互不干扰
4. **自定义 EP 扩展**放 `public/scss/element-plus/custom/`，在 `element-plus.scss` 里 import，编译进同一输出

## 实现路线

每期迭代模式：
1. 选 3-5 个组件同步开发
2. 每个组件产出：声明文件 → 测试用例 → 实现 → 验证
3. 一期完成后整理文档 + demo
