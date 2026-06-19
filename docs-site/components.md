# 组件库

组件库基于 Element Plus 设计语言，Props/Slots/Events 对齐 EP 文档，服务端渲染，Signal 驱动。

## 组件列表

### Stage 1 — 布局与基础

| 组件 | 文件 | 说明 |
|------|------|------|
| **Button** | `src/components/Button.cj` | size / kind / round / circle / loading / icon / plain / text / link / bg |
| **ButtonGroup** | `src/components/Button.cj` | 按钮组，direction / size / kind |
| **Card** | `src/components/Card.cj` | 卡片容器，header / footer / shadow / bodyStyle |
| **Row** | `src/components/Row.cj` | flex 栅格行，gutter / justify / align |
| **Col** | `src/components/Col.cj` | 栅格列，span / offset / push / pull |
| **Divider** | `src/components/Divider.cj` | 分割线，direction / contentPosition |
| **Text** | `src/components/Text.cj` | 文本，kind / size / truncated / lineClamp / tag |
| **Link** | `src/components/Link.cj` | 链接，kind / underline / href / target / icon / disabled |
| **Tag** | `src/components/Tag.cj` | 标签，kind / size / effect / closable / hit / round / color |
| **Badge** | `src/components/Badge.cj` | 徽标，value / max / dot / hidden / showZero / kind |
| **Space** | `src/components/Space.cj` | 间距容器，size / direction / wrap |
| **Icon** | `src/components/Icon.cj` | 图标，name / size / color |

### Stage 2 — 表单控件

| 组件 | 文件 | 说明 |
|------|------|------|
| **Input** | `src/components/Input.cj` | 输入框，placeholder / size / clearable / password / disabled / prefixIcon / suffixIcon / bind |
| **InputNumber** | `src/components/InputNumber.cj` | 数字输入，min / max / step / size / noControls / bind |
| **Switch** | `src/components/Switch.cj` | 开关，activeText / inactiveText / size / disabled / bind |
| **Radio** | `src/components/Radio.cj` | 单选按钮，value / disabled |
| **RadioGroup** | `src/components/Radio.cj` | 单选项组，bind |
| **Checkbox** | `src/components/Checkbox.cj` | 复选按钮，value / disabled |
| **CheckboxGroup** | `src/components/Checkbox.cj` | 复选框组，bind |
| **Select** | `src/components/Select.cj` | 下拉选择，placeholder / disabled / clearable / filterable / multiple / option groups / bind / bindMulti |
| **Slider** | `src/components/Slider.cj` | 滑块，min / max / step / showStops / disabled / bind |
| **Rate** | `src/components/Rate.cj` | 评分，max / allowHalf / showText / texts / disabled / bind |

### 配套组件

| 组件 | 文件 | 说明 |
|------|------|------|
| **Form** | `src/components/Form.cj` | 表单容器 |
| **FormItem** | `src/components/FormItem.cj` | 表单项，label / required / error |
| **Menu** | `src/components/Menu.cj` | 菜单容器，mode（Horizontal / Vertical） |
| **MenuItem** | `src/components/Menu.cj` | 菜单项，active / onClick |

## 查看演示

完整交互演示请下载源码后运行 examples 项目：

```bash
git clone https://atomgit.com/ystyle/cjxt.git
cd cjxt

# 构建
eval "$(cjvs env zsh)"
eval "$(cjvs stdx env zsh)"
cjpm build
cd examples && cjpm build && cd ..
./scripts/build-css.sh

# 启动
cd examples && ./target/release/bin/main
```

浏览器打开 `http://localhost:8080`，点击 "组件库" tab 查看全部组件演示。

## Props / Events 说明

以 Button 为例：

```cangjie
Button("提交")
    .kind(ComponentKind.Primary)       // 主题色
    .size(ComponentSize.Large)          // 尺寸
    .round()                           // 圆角
    .icon("search")                    // 图标
    .loading()                         // 加载中
    .disabled()                        // 禁用
    .onClick({ ctx =>                  // 点击回调
        PatchResult.ReRender
    })
```

### 通用 Props

| Prop | 类型 | 说明 |
|------|------|------|
| kind | ComponentKind | Default / Primary / Success / Warning / Danger / Info |
| size | ComponentSize | Large / Default / Small |
| disabled | Bool | 禁用状态 |
| bind | `Signal<T>` | 双向数据绑定（表单组件） |
| onClick | ActionHandler | 点击回调 |

## 样式扩展

组件基于 Element Plus SCSS，通过 CSS 变量自定义主题：

```scss
:root {
  --el-color-primary: #409eff;
  --el-color-success: #67c23a;
  --el-border-radius-base: 6px;
}
```

自定义组件样式放在 `public/scss/element-plus/custom/` 目录下。
