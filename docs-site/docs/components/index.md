# 组件库

基于 Element Plus 设计语言，使用 builder 模式链式调用。

> 使用组件库需要 Element Plus 样式。可用以下命令下载编译好的样式文件到项目中：
> ```bash
> curl -sL https://raw.githubusercontent.com/ystyle/cjxt/master/examples/public/css/element-plus.css -o public/css/element-plus.css
> ```
> 也可使用 cjxt 仓库中的脚本：`scripts/download-ep-css.sh`。后续将通过包管理自动分发。

## 查看演示

```bash
git clone https://atomgit.com/ystyle/cjxt.git
cd cjxt
eval "$(cjvs env zsh)" && eval "$(cjvs stdx env zsh)"
cjpm build
cd examples && cjpm build && cd ..
./scripts/build-css.sh
cd examples && ./target/release/bin/main
```

浏览器打开 `http://localhost:8080`，点击 "组件库" tab 查看全部交互演示。

## 基础

| 组件 | API |
|------|-----|
| **Button** | `kind(ButtonKind)` `size(ButtonSize)` `round()` `circle()` `plain()` `text()` `link()` `bg()` `loading()` `disabled()` `icon(name)` `nativeType(ButtonNativeType)` `autofocus()` `onClick(h)` |
| **ButtonGroup** | `direction(SpaceDirection)` `size(ButtonSize)` `kind(ButtonKind)` |
| **Text** | `kind(ComponentKind)` `size(TextSize)` `truncated()` `lineClamp(n)` `tag(name)` |
| **Link** | `kind(ComponentKind)` `underline(LinkUnderline)` `noUnderline()` `disabled()` `href(url)` `target(t)` `icon(name)` `onClick(h)` |
| **Icon** | `name`(26 内置图标) `size(String)` `color(String)` |

## 布局

| 组件 | API |
|------|-----|
| **Row** | `gutter(Int64)` `justify(RowJustify)` `align(RowAlign)` |
| **Col** | `span(Int64)` `offset(Int64)` `pull(Int64)` `push(Int64)` `gutter(Int64)` |
| **Card** | `header(s)` `footer(s)` `shadow(CardShadow)` `bodyStyle(s)` `bodyClass(s)` |
| **Divider** | `direction(DividerDirection)` `contentPosition(ContentPosition)` |
| **Space** | `size(Int64)` `direction(SpaceDirection)` `wrap()` |

## 表单

| 组件 | API | 绑定类型 |
|------|-----|---------|
| **Input** | `placeholder(s)` `size(ComponentSize)` `clearable()` `disabled()` `password()` `prefixIcon(n)` `suffixIcon(n)` | `Signal<String>` |
| **InputNumber** | `min(n)` `max(n)` `step(n)` `size(ComponentSize)` `disabled()` `noControls()` | `Signal<Int64>` |
| **Switch** | `activeText(s)` `inactiveText(s)` `activeValue(Bool)` `inactiveValue(Bool)` `disabled()` `size(ComponentSize)` | `Signal<Bool>` |
| **Radio** | `value` 标识字符串 `disabled()` | — |
| **RadioGroup** | `bind(Signal<String>)` | `Signal<String>` |
| **Checkbox** | `value` 标识字符串 `disabled()` | — |
| **CheckboxGroup** | `bind(Signal<ArrayList<String>>)` | `Signal<ArrayList<String>>` |
| **Select** | `placeholder(s)` `disabled()` `clearable()` `filterable()` `multiple()` | `Signal<String>` / `bindMulti` |
| **SelectOption** | `value` `disabled()` | — |
| **SelectOptionGroup** | `label` 分组标题 | — |
| **Slider** | `min(n)` `max(n)` `step(n)` `showStops()` `disabled()` | `Signal<Int64>` |
| **Rate** | `max(n)` `allowHalf()` `showText()` `disabled()` `texts(Array<String>)` | `Signal<Int64>` |

## 数据展示

| 组件 | API |
|------|-----|
| **Tag** | `kind(ComponentKind)` `size(TagSize)` `effect(TagEffect)` `closable()` `hit()` `round()` `color(s)` `onClose(h)` `onClick(h)` |
| **Badge** | `value(n|s)` `max(n)` `dot()` `hidden()` `showZero(Bool)` `kind(ComponentKind)` |

## 导航

| 组件 | API |
|------|-----|
| **Menu** | `mode(MenuMode)` `add(MenuItem)` |
| **MenuItem** | `disabled(Bool)` `active(Bool)` `onClick(h)` |

## 表单容器

| 组件 | API |
|------|-----|
| **Form** | children 为 FormItem |
| **FormItem** | `label(s)` `setProp(s)` `required()` `error(s)` |

## 枚举类型

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
```
