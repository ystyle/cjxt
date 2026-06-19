# 组件库

组件库基于 Element Plus 设计语言，Props/Slots/Events 对齐 EP 文档，服务端渲染，Signal 驱动。

所有组件位于继承 `Component` 抽象类，使用 builder 模式链式调用。

## 组件列表

### 基础

| 组件 | 文件 | 核心 API |
|------|------|----------|
| **Button** | `Button.cj` | `kind(ButtonKind)` `size(ButtonSize)` `round()` `circle()` `plain()` `text()` `link()` `bg()` `loading()` `disabled()` `icon(name)` `nativeType(ButtonNativeType)` `autofocus()` `onClick(handler)` |
| **ButtonGroup** | `Button.cj` | `direction(SpaceDirection)` `size(ButtonSize)` `kind(ButtonKind)` children 为 Button 数组 |
| **Text** | `Text.cj` | `kind(ComponentKind)` `size(TextSize)` `truncated()` `lineClamp(n)` `tag(name)` |
| **Link** | `Text.cj` | `kind(ComponentKind)` `underline(LinkUnderline)` `noUnderline()` `disabled()` `href(url)` `target(name)` `icon(name)` `onClick(handler)` |
| **Icon** | `Icon.cj` | `name` 为字符串（内置 26 个图标），`size(String)` `color(String)` |

### 布局

| 组件 | 文件 | 核心 API |
|------|------|----------|
| **Row** | `Card.cj` | `gutter(Int64)` `justify(RowJustify)` `align(RowAlign)` |
| **Col** | `Card.cj` | `span(Int64)` `offset(Int64)` `pull(Int64)` `push(Int64)` `gutter(Int64)` |
| **Card** | `Card.cj` | `header(String\|Array)` `footer(String\|Array)` `shadow(CardShadow)` `bodyStyle(String)` `bodyClass(String)` |
| **Divider** | `Divider.cj` | `direction(DividerDirection)` `contentPosition(ContentPosition)` |
| **Space** | `Space.cj` | `size(Int64)` `direction(SpaceDirection)` `wrap()` |

### 表单

| 组件 | 文件 | 核心 API |
|------|------|----------|
| **Input** | `Input.cj` | `placeholder(String)` `size(ComponentSize)` `clearable()` `disabled()` `password()` `prefixIcon(name)` `suffixIcon(name)` `bind(Signal<String>)` |
| **InputNumber** | `InputNumber.cj` | `min(Int64)` `max(Int64)` `step(Int64)` `size(ComponentSize)` `disabled()` `noControls()` `bind(Signal<Int64>)` |
| **Switch** | `Switch.cj` | `activeText(String)` `inactiveText(String)` `activeValue(Bool)` `inactiveValue(Bool)` `disabled()` `size(ComponentSize)` `bind(Signal<Bool>)` |
| **Radio** | `Radio.cj` | `value` 为标识字符串，`disabled()` |
| **RadioGroup** | `Radio.cj` | `bind(Signal<String>)` |
| **Checkbox** | `Checkbox.cj` | `value` 为标识字符串，`disabled()` |
| **CheckboxGroup** | `Checkbox.cj` | `bind(Signal<ArrayList<String>>)` |
| **Select** | `Select.cj` | `placeholder(String)` `disabled()` `clearable()` `filterable()` `multiple()` `bind(Signal<String>)` `bindMulti(Signal<ArrayList<String>>)` |
| **SelectOption** | `Select.cj` | `value` 为标识字符串，`disabled()` |
| **SelectOptionGroup** | `Select.cj` | `label` 为分组标题，children 为 SelectOption |
| **Slider** | `Slider.cj` | `min(Int64)` `max(Int64)` `step(Int64)` `showStops()` `disabled()` `bind(Signal<Int64>)` |
| **Rate** | `Rate.cj` | `max(Int64)` `allowHalf()` `showText()` `disabled()` `texts(Array<String>)` `bind(Signal<Int64>)` |

### 数据展示

| 组件 | 文件 | 核心 API |
|------|------|----------|
| **Tag** | `Tag.cj` | `kind(ComponentKind)` `size(TagSize)` `effect(TagEffect)` `closable()` `hit()` `round()` `color(String)` `onClose(handler)` `onClick(handler)` |
| **Badge** | `Tag.cj` | `value(Int64\|String)` `max(Int64)` `dot()` `hidden()` `showZero(Bool)` `kind(ComponentKind)` |

### 导航

| 组件 | 文件 | 核心 API |
|------|------|----------|
| **Menu** | `Menu.cj` | `mode(MenuMode)` `add(MenuItem)` 支持 Horizontal / Vertical |
| **MenuItem** | `Menu.cj` | `disabled(Bool)` `active(Bool)` `onClick(handler)` |

### 表单容器

| 组件 | 文件 | 核心 API |
|------|------|----------|
| **Form** | `Form.cj` | children 为 FormItem |
| **FormItem** | `Form.cj` | `label(String)` `setProp(String)` `required()` `error(String)` |

## 内置图标

通过 `Icon("name")` 使用：

| 类别 | 图标 |
|------|------|
| 方向 | `arrow-down` `arrow-up` `arrow-left` `arrow-right` |
| 基本 | `close` `check` `search` |
| 星级 | `star` `star-filled` `star-on` `star-off` |
| 编辑 | `edit` `delete` |
| 状态 | `info-filled` `success-filled` `warning-filled` `error-filled` |
| 形状 | `circle-check` `circle-close` |
| 加载 | `loading` |
| 加减 | `minus` `plus` |
| 可见 | `view` `hide` |
| 用户 | `user` `lock` |

## 便捷函数

`Button.cj` 提供常用变体的便捷函数：

```cangjie
PrimaryButton("提交")   // 等价于 Button("提交").kind(ButtonKind.Primary)
DangerButton("删除")    // 等价于 Button("删除").kind(ButtonKind.Danger)
SuccessButton("成功")   // 等价于 Button("成功").kind(ButtonKind.Success)
WarningButton("警告")   // 等价于 Button("警告").kind(ButtonKind.Warning)
InfoButton("信息")      // 等价于 Button("信息").kind(ButtonKind.Info)
SmallButton("小按钮")   // 等价于 Button("小按钮").size(ButtonSize.Small)
```

## 绑定用法

表单组件通过 `bind(signal)` 实现双向数据绑定，支持的类型：

| 组件 | 信号类型 | 绑定的值 |
|------|---------|---------|
| `Input` | `Signal<String>` | 输入文本 |
| `InputNumber` | `Signal<Int64>` | 数字 |
| `Switch` | `Signal<Bool>` | 开关状态 |
| `RadioGroup` | `Signal<String>` | 选中值 |
| `CheckboxGroup` | `Signal<ArrayList<String>>` | 选中值列表 |
| `Select` | `Signal<String>` | 选中值 |
| `Select.multiple()` | `Signal<ArrayList<String>>` | 多选值列表 |
| `Slider` | `Signal<Int64>` | 滑块位置 |
| `Rate` | `Signal<Int64>` | 评分值 |

## 枚举类型

所有组件枚举定义在 `Types.cj`：

```cangjie
ButtonKind:     Default | Primary | Success | Warning | Danger | Info
ComponentKind:  Default | Primary | Success | Warning | Danger | Info | Plain
ButtonSize:     Large | Default | Small
ButtonNativeType: Button | Submit | Reset
ComponentSize:  Large | Default | Small
TextSize:       Default | Large | Small
TagSize:        Default | Large | Medium | Small | Mini
TagEffect:      Dark | Light | Plain
CardShadow:     Always | Hover | Never
RowJustify:     Start | End | Center | SpaceAround | SpaceBetween | SpaceEvenly
RowAlign:       Top | Middle | Bottom
DividerDirection: Horizontal | Vertical
ContentPosition:  Left | Center | Right
SpaceDirection:   Horizontal | Vertical
MenuMode:         Horizontal | Vertical
LinkUnderline:    Always | Hover | Never
```

## 查看演示

完整交互演示请下载源码后运行 examples 项目：

```bash
git clone https://atomgit.com/ystyle/cjxt.git
cd cjxt
eval "$(cjvs env zsh)"
eval "$(cjvs stdx env zsh)"
cjpm build
cd examples && cjpm build && cd ..
./scripts/build-css.sh
cd examples && ./target/release/bin/main
```

浏览器打开 `http://localhost:8080`，点击"组件库" tab 查看全部组件演示。
