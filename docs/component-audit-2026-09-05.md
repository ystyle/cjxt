# 组件库 EP 对齐审计报告

> 日期:2026-09-05 | 方法:逐组件对照 cjxt 实现与 Element Plus 本地源码
> (`~/Projects/element-plus/packages/components/*`,master 0.0.0-dev.1),SCSS 侧与 EP
> theme-chalk 逐字 diff。审计范围:Stage 1/2/3 已实现组件 + 备注 Stage 4 Tooltip/Popover。
> 结论:SCSS 全部为 EP 原版拷贝且接线完整(零偏离),所有偏差都在 cjxt 渲染的 DOM/类名/交互。

## 状态图例

- 🔴 简化实现明显偏离 / 功能缺陷,必须重做
- 🟡 视觉对齐但缺 props/交互
- ✅ 完全对齐

## Stage 1 — 布局与基础

| 组件 | 状态 | 关键差异 |
|---|---|---|
| Button | 🔴 | loading 图标无 `is-loading` 不旋转;loading 误加 `is-disabled` 置灰(EP 只加 mask);默认插槽缺 `<span>` 包裹 → icon+文字间距失效 |
| ButtonGroup | 🟡 | DOM/Props 对齐;`b.render()` 内联破坏子组件脏追踪 |
| Card | 🟡 | 主体对齐;缺 headerClass/footerClass |
| Row/Col | 🟡 | Row 缺 tag;Col 缺响应式 `xs/sm/md/lg/xl`、`is-guttered`;gutter 需显式传参(EP 为 Row 注入) |
| Divider | 🟡 | 缺 borderStyle(`--el-divider-border-style`)与 role=separator |
| Text | ✅ | 全对齐;仅 title 溢出提示依赖客户端 DOM 测量,无法服务端对齐(需客户端 JS 或用户显式传 title) |
| Link | 🟡 | disabled 仍加 is-hover-underline;`<a disabled>` 非标准属性;默认缺 `el-link--default` |
| Tag | 🔴 | **onClose 死代码**(× 从未绑 onClick,且无 stopPropagation,点×会冒泡触发根点击);默认 type 无 `--primary` → `--el-tag-text-color` 未定义,默认 Tag 文字色继承父级而非 EP 蓝 |
| Badge | 🟡 | 缺 color/offset/badgeStyle/badgeClass/is-hide-zero;无值/无内容时仍渲染空 sup(EP 不渲染) |
| Space | 🟡 | 缺 alignment(EP 默认 center,cjxt stretch 拉伸不同高子项)、fill/fillRatio、rowGap/columnGap 分轴、size 预设 |
| Icon | 🟡 | 根元素 `span` vs EP `<i>`(视觉等价);未知图标名回退 info 图标(合理) |

## Stage 2 — 表单控件

| 组件 | 状态 | 关键差异 |
|---|---|---|
| Input | 🟡 | 缺 textarea(.el-textarea__inner)/prepend/append(el-input-group);clear 图标不可点击(裸 Icon 无类无 onClick);prefix/suffix 缺 `el-input__icon` 类;缺 is-focus(需前端 focus/blur 采集);showPassword 无切换 |
| InputNumber | 🔴 | **无 `el-input__wrapper` 嵌套**(inner 本身 border:none)→ 输入框无边框;类名 `--no-controls` ≠ `is-without-controls`;**disabled 守卫缺失**(禁用点+/-仍改值);Int64.parse 无 try/catch(中间态输入炸 action);缺 repeat-click/role/aria/边界 is-disabled |
| Switch | 🟡 | **disabled 守卫缺失**(禁用点击仍翻转);input 缺 role/aria;inner 无条件渲染(EP 仅 inlinePrompt);缺 loading/width/inline-prompt |
| Radio | 🟡 | **独立实例不可交互**(signal=None 时无 handler);onClick 挂在隐藏 `el-radio__original` 上(Table 已迁移到 label,Radio 未迁移);span 缺 is-disabled/is-focus;RadioGroup name 每次 render 递增;死代码 |
| Checkbox | 🟡 | **独立实例不可交互**(无 bind(Signal<Bool>) API);span 缺 is-disabled/is-indeterminate/is-focus;CheckboxGroup 缺 role=group;缺 trueLabel/falseLabel/border/size |
| Select | 🔴 | **filterable 搜索框错位**(在下拉 `el-select-dropdown__header` 里,EP 是 wrapper 内 combobox);下拉无 el-scrollbar(长列表溢出不可滚);无点击外部关闭/键盘/option hover;根类 `el-select--disabled` 在 SCSS 不存在(禁用态无视觉);clear+caret 同时渲染(EP 二选一);tags 缺 `el-select__selected-item` 包裹层;option-group 嵌套层级反了;option 缺 aria |
| Form/FormItem | 🔴 | **必填星号不显示**(缺 asterisk-left/right 类,EP 依赖它渲染 `*`);默认标签左对齐(EP 默认 `el-form-item--label-right` 右对齐);**校验无触发时机**(仅手工 validate(),无 blur/change 自动触发);无 Form 级 rules/model(prop 是死参数);error 用 span(EP div);缺 label-suffix/show-message/size 等 |
| Rate | 🔴 | **allowHalf 声明但完全未实现**(无半星双图标;值模型 Int64 无法表示 0.5);激活色硬编码 `#e6a23c` ≠ EP `#f7ba2a`,void 色 `#c6d1de` ≠ EP `#c6d1de`(对比过,即同值,但 fill 错);**disabled 守卫缺失**;缺 hover 放大/aria/键盘/clearable/show-score |

## Stage 3 — 数据展示

| 组件 | 状态 | 关键差异 |
|---|---|---|
| Table | 🔴 | **height 模式不可纵向滚动**(仅 overflow-x,EP 用 el-scrollbar 包 body);**排序为字符串比较**(数值列 "2">"10" 错误);**展开行完全缺失**(无 Expand 列类型);空数据 DOM 偏离(无空 body table/empty-block 合并);fixed 列缺 EP 类+背景+多列 offset 累加;showOverflowTooltip 为 30 字符截断假实现;所有 cell 强制 nowrap(EP 默认换行);多选无半选;reserveSelection/selectable 死代码;th 缺 is-leaf/aria-sort |
| Progress | 🔴 | **text-inside 双嵌套 bug**(inner 被包两层,进度长度"平方":80% 显示 64%);status 时缺图标;颜色用 CSS 变量 ≠ EP STATUS_COLOR_MAP 硬编码(#13ce66/#ff4949/#20a0ff);缺 format;circle 缺 aria |
| Avatar | 🟡 | **onError 绑到 img.onClick**(EP 是原生 error 事件,服务端无法收发,需客户端 JS);数字尺寸用 inline px 而非 `--el-avatar-size`;缺 el-avatar--icon 类;is-error class EP 不存在 |
| Empty | 🟡 | 默认文案硬编码"暂无数据"(EP 随 locale);默认 SVG 手绘简化版;imageSize 仅 String 无单位支持;image 双层同 class |
| Descriptions | 🟡 | **缺 rowspan**;分行算法与 EP 不同(无 span clamp/末行填充);缺 is-bordered-label 等类;无内容默认 "--"(EP 空 td);labelWidth 落点不同 |
| Statistic | 🟡 | **无数字格式化**(precision/千分位/formatter 全缺);value 类名 `__value`(EP 模板 `__number` 但 scss 只定义 `__value`,取舍需明确);prefix/suffix 用 span(EP div) |
| Result | 🟡 | 图标手绘简化(未拷贝官方 CircleCheckFilled 等 path);extra 用 children 代替具名 slot |

## 备注:Stage 4 Tooltip / Popover

- 🟡 客户端组件用 `cssText` 手写样式(深色 #303133/白底边框),未使用 EP 的 `.el-popper` 类;
  `tooltip.scss`/`popover.scss` 已在 SCSS 目录但未 `@use` 接线。视觉近似,POI 与 EP popper 不同。

## 无法对齐(需要说明原因的项)

| 项 | 原因 | 对策 |
|---|---|---|
| Text 溢出 title 自动提示 | 依赖客户端 offsetWidth/scrollWidth 测量 | 客户端 JS 或显式传 title |
| Input focus 态 (is-focus) | 服务端无 focus/blur 事件通道 | cangjie-ui.js 加通用 focus/blur 采集(一次投入全输入类受益) |
| Select popper 定位/click-outside/键盘/hover | EP 用 popper + VClickOutside + useSelect 状态机 | 自建挂点(参考 attachSlider 模式),或接受 inline absolute 近似 |
| Rate hover 缩放/半星指示 | mousemove 通道 | 半星结构本身可服务端对齐;hover 需客户端 |
| Avatar img error 回退 | 原生 error 事件服务端无法收发 | 客户端监听 img error → dispatch action |
| Table fixed 阴影 (is-scrolling-*) | 客户端滚动状态监听 | 静态对齐(sticky+背景)先行,阴影后续 |
| Empty/Result 默认图标 | 无技术障碍 | 从 EP icons-vue 拷贝 path |
| Form blur/change 自动校验 | 无事件通道 | 经 bind 消息链路上报触发事件 |
| 过渡动画 (zoom-in-center 等) | Vue transition | 可近似或跳过 |

## 重做优先级清单

### P0 功能缺陷(修复成本小,影响最大)
1. Switch / InputNumber / Rate **disabled 守卫缺失**(3 处,各一行)
2. Progress **text-inside 双嵌套**(一行)
3. Tag **onClose 接线** + 默认 type=primary
4. Button **loading**(is-loading + 去掉 is-disabled)+ 默认插槽包 span
5. Rate 激活色 `#e6a23c` → `#f7ba2a`
6. Form/FormItem **必填星号**(asterisk-left/right)+ 默认 `el-form-item--label-right`
7. InputNumber **el-input__wrapper 嵌套**(否则无边框)+ 类名修正 + Int64.parse 防炸

### P1 结构重做(中等成本)
8. Select:filterable 移到 wrapper、el-scrollbar、外部关闭/键盘/hover、根类修正、tags 包裹层、option-group 嵌套
9. Table:height 滚动容器、类型感知排序、expand 列、空数据 DOM、fixed 列类、去掉强制 nowrap、showOverflowTooltip
10. Rate:半星结构(值模型 Float64/×2 Int64)
11. Input:textarea/prepend/append/clear 点击/prefix 图标类
12. Checkbox/Radio:独立 bind 可用性 + span 状态类 + 死代码清理
13. Descriptions:rowspan + getRows 算法
14. Badge:is-hide-zero + 空值不渲染 sup + offset/color

### P2 补 props(锦上添花)
- Button dashed/color/tag、Col 响应式、Space alignment、Divider borderStyle、Card headerClass、Icon span→i、Link 小修、Statistic 格式化、Empty SVG/文案、Result 官方图标、Avatar --el-avatar-size
