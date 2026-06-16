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

| Stage | 组件数 | 状态 |
|-------|--------|------|
| Stage 1 布局与基础 | 12 | ❌ |
| Stage 2 表单控件 | 10 + Form | ❌ |
| Stage 3 数据展示 | 8 | ❌ |
| Stage 4 交互组件 | 12 | ❌ |
| Stage 5 复杂组件 | ~20 | ❌ |

## 实现路线

每期迭代模式：
1. 选 3-5 个组件同步开发
2. 每个组件产出：声明文件 → 测试用例 → 实现 → 验证
3. 一期完成后整理文档 + demo
