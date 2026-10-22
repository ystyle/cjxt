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

**结论：80 项里已实现 54 项，缺 26 项独立组件 + 3 个现有组件的形态变体。**
（2026-10-23 补上 `Container` 族后：53 → 54，独立缺口 27 → 26。）

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
| `Scrollbar` | 待做 | 自定义滚动条；`custom/select-scroll.scss` 只解决下拉面板自己的滚动，业务侧长列表没有可用件。 |

**第 2 批 — 高频展示件（4 项）**

| 组件 | 缺它的代价 |
|------|-----------|
| `Timeline` | 时间线。日志、审批流、进度记录场景刚需，没有替代。 |
| `Image` | EP 的 `el-image` 带懒加载 / 加载失败回退 / 点击预览。现在只能用裸 `<img>`。 |
| `Segmented` | 分段控制器，视图切换比 Radio 更常见。 |
| `AvatarGroup` | `Avatar` 已有单件，组只是叠放 + 溢出计数，**很便宜**。 |

> （`AvatarGroup` 属"现有组件的形态变体"，3 个变体之一。）

**第 3 批 — 表单补全（4 项）**

| 组件 | 说明 |
|------|------|
| `RadioButton` / `CheckboxButton` | EP 的按钮形态单选/复选。现有 `Radio`/`Checkbox` 只有圆点形态（`Radio.cj` 无 button 分支），**改造成本低**。这 2 个即上述"形态变体"。 |
| `InputOtp` | 验证码输入。登录 / 二次验证要用。 |
| `InputTag` | 标签化输入，多值场景比 `Select` multiple 更直接。 |

**第 4 批 — 导航与定位（4 项）**

`Affix`（吸顶）、`Backtop`（回到顶部）、`Anchor`（锚点导航）、`PageHeader`（页头）——
都与滚动位置强相关，建议**同批做**，共用一套滚动监听。

**第 5 批 — 高级交互（7 项）**

`ColorPicker`、`Carousel`、`Tour`、`Splitter`、`Transfer`、`Watermark`、`ConfigProvider`。
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
