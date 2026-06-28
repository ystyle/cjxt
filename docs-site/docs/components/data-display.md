# 数据展示

 Progress、Avatar、Empty、Descriptions、Statistic、Result 六个轻量组件的用法汇总。

## Progress 进度条

支持线形、环形、仪表盘三种类型，百分比驱动。

```cangjie
// 线形
Progress().percentage(50)
Progress().percentage(75).status(ProgressStatus.Success)
Progress().percentage(100).status(ProgressStatus.Success).striped()
Progress().percentage(80).strokeWidth(12).textInside()
Progress().percentage(30).color("#f56c6c")

// 环形 / 仪表盘
Progress().percentage(75).kind(ProgressKind.Circle).width(100)
Progress().percentage(80).kind(ProgressKind.Dashboard).status(ProgressStatus.Warning)
```

### Progress 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `kind(v)` | `ProgressKind` | 类型：`Line \| Circle \| Dashboard` |
| `percentage(v)` | `Int64` | 百分比 0-100 |
| `status(v)` | `ProgressStatus` | 状态色：`None \| Success \| Exception \| Warning` |
| `strokeWidth(v)` | `Int64` | 线形进度条高度（px，默认 6） |
| `textInside()` | — | 百分比文字显示在进度条内部 |
| `width(v)` | `Int64` | Circle/Dashboard 画布宽度（默认 126） |
| `showText(v)` | `Bool` | 是否显示百分比文字（默认 true） |
| `color(v)` | `String` | 自定义颜色（覆盖 status 颜色） |
| `striped()` | — | 条纹效果 |
| `stripedFlow()` | — | 流动条纹效果 |
| `indeterminate()` | — | 不确定动画 |
| `duration(v)` | `Int64` | 动画持续时间（秒，默认 3） |
| `strokeLinecap(v)` | `String` | 线端形状：`butt \| round \| square`（默认 round） |

## Avatar 头像

```cangjie
Avatar().icon("user")
Avatar().src("https://example.com/avatar.png")
Avatar().size("large").icon("user")
Avatar().size("small").icon("user")
Avatar().shape(AvatarShape.Square).icon("user")
Avatar().size("64").src("avatar.png")  // 数字 px
```

### Avatar 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `size(v)` | `String` | `large \| small` 或数字 px |
| `shape(v)` | `AvatarShape` | `Circle \| Square` |
| `icon(v)` | `String` | 图标名称 |
| `src(v)` | `String` | 图片 URL |
| `alt(v)` | `String` | 图片 alt 文本 |
| `srcSet(v)` | `String` | 响应式图片 srcset |
| `fit(v)` | `AvatarFit` | 图片填充方式 |
| `onError(h)` | `ActionHandler` | 图片加载失败回调 |

## Empty 空状态

```cangjie
Empty().description("暂无数据")
Empty().image("/empty-custom.png").imageSize("200")
```

### Empty 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `description(v)` | `String` | 描述文本 |
| `image(v)` | `String` | 自定义图片 URL |
| `imageSize(v)` | `String` | 图片尺寸 |
| `slotImage(v)` | `Array<IComponent>` | 自定义图片区域 |
| `slotDescription(v)` | `Array<IComponent>` | 自定义描述区域 |

不传 `image` 时显示 Element Plus 默认 SVG 插图。

## Descriptions 描述列表

```cangjie
Descriptions()
    .title("用户信息")
    .add(DescriptionsItem().label("用户名").children([text("admin")]))
    .add(DescriptionsItem().label("手机号").children([text("138****1234")]))
    .add(DescriptionsItem().label("居住地").children([text("北京")]))

Descriptions()
    .border()
    .title("用户信息")
    .column(3)
    .add(DescriptionsItem().label("用户名").children([text("admin")]))
```

### Descriptions 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `add(item)` | `DescriptionsItem` | 添加描述项 |
| `border()` | — | 带边框样式 |
| `column(v)` | `Int64` | 每行列数（默认 3） |
| `direction(v)` | `DescriptionsDirection` | `Horizontal \| Vertical` |
| `size(v)` | `String` | `large \| default \| small` |
| `title(v)` | `String` | 标题 |
| `extra(v)` | `String` | 标题右侧额外内容 |
| `labelWidth(v)` | `String` | 标签宽度 |
| `slotTitle(v)` | `Array<IComponent>` | 标题插槽 |
| `slotExtra(v)` | `Array<IComponent>` | 额外内容插槽 |

### DescriptionsItem 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `label(v)` | `String` | 标签文本 |
| `children(v)` | `Array<IComponent>` | 内容 |
| `span(v)` | `Int64` | 跨列数（默认 1） |
| `width(v)` | `String` | 单元格宽度 |
| `minWidth(v)` | `String` | 单元格最小宽度 |
| `labelWidth(v)` | `String` | 该单元格标签宽度 |
| `align(v)` | `DescriptionsAlign` | 对齐：`Left \| Center \| Right` |
| `labelAlign(v)` | `DescriptionsAlign` | 标签对齐 |
| `className(v)` | `String` | 内容单元格 class |
| `labelClassName(v)` | `String` | 标签单元格 class |

## Statistic 统计数值

```cangjie
Statistic().title("日活跃用户").value("128,000").suffix("人")
Statistic().title("总销售额").value(128000).prefix("¥")
Statistic().title("转化率").value("12.8").suffix("%").valueStyle("color: #f56c6c")
```

### Statistic 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `title(v)` | `String` | 标题 |
| `value(v)` | `String \| Int64` | 数值 |
| `prefix(v)` | `String` | 前缀 |
| `suffix(v)` | `String` | 后缀 |
| `valueStyle(v)` | `String` | 数值行内样式 |
| `slotTitle(v)` | `Array<IComponent>` | 标题插槽 |
| `slotPrefix(v)` | `Array<IComponent>` | 前缀插槽 |
| `slotSuffix(v)` | `Array<IComponent>` | 后缀插槽 |

## Result 结果页

```cangjie
Result()
    .title("操作成功")
    .subTitle("您已成功提交申请")
    .icon(ResultIcon.Success)

Result()
    .title("操作失败")
    .subTitle("请检查网络连接")
    .icon(ResultIcon.Error)
```

### Result 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `title(v)` | `String` | 标题 |
| `subTitle(v)` | `String` | 副标题 |
| `icon(v)` | `ResultIcon` | 图标：`Primary \| Success \| Warning \| Info \| Error` |
| `slotIcon(v)` | `Array<IComponent>` | 自定义图标 |
| `slotTitle(v)` | `Array<IComponent>` | 标题插槽 |
| `slotSubTitle(v)` | `Array<IComponent>` | 副标题插槽 |
| `children(v)` | `Array<IComponent>` | 底部额外内容（extra slot） |

## 枚举类型

```cangjie
ProgressKind:          Line | Circle | Dashboard
ProgressStatus:        None | Success | Exception | Warning
AvatarShape:           Circle | Square
AvatarFit:             Fill | Contain | Cover | None | ScaleDown
DescriptionsDirection: Horizontal | Vertical
DescriptionsAlign:     Left | Center | Right
ResultIcon:            Primary | Success | Warning | Info | Error
```
