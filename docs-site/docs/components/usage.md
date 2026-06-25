# 组件使用指南

## 导入组件

```cangjie
// 导入全部组件
import cjxt.components.*

// 或按需导入
import cjxt.components.{Button, Input, Select}
```

宏需要单独导入（`@Page`、`@defineCSS` 等）：

```cangjie
import cjxt.*
import cjxt.macros.*
```

## Builder 模式

所有组件使用链式 builder 模式——方法返回自身，可以连续调用：

```cangjie
Button("提交")
    .kind(ButtonKind.Primary)
    .size(ComponentSize.Large)
    .round()
    .icon("search")
```

## 事件绑定

```cangjie
// 方式一：显式返回 PatchResult（通用）
button(text("提交")).onClick({ ctx =>
    PatchResult.ReRender
})

// 方式二：简化写法（Button/MenuItem/Tag/Link 支持）
Button("提交").onClick({ ctx =>
    // 框架自动走 ReRender
})
```

`ActionContext` 提供导航和状态访问：

```cangjie
button(text("跳转")).onClick({ ctx =>
    ctx.route.push("/other-page")               // 导航
    let st = ctx.getState<MyState>()             // 共享状态
    PatchResult.ReRender
})
```

## 数据绑定

```cangjie
// 文本输入
Input().bind(this.state.username)               // Signal<String>

// 数字输入
InputNumber().bind(this.state.count)            // Signal<Int64>

// 开关
Switch().bind(this.state.enabled)               // Signal<Bool>

// 单选
RadioGroup([Radio([text("A")], "a")]).bind(this.state.value)   // Signal<String>

// 复选
CheckboxGroup([Checkbox([text("A")], "a")]).bind(this.state.checks)  // Signal<ArrayList<String>>

// 下拉单选
Select([SelectOption([text("A")], "a")]).bind(this.state.value)     // Signal<String>

// 下拉多选
Select([...]).multiple().bindMulti(this.state.values)  // Signal<ArrayList<String>>

// 滑块
Slider().bind(this.state.volume)                // Signal<Int64>

// 评分
Rate().bind(this.state.score)                   // Signal<Int64>
```

## 枚举使用

组件参数通过枚举类型控制：

```cangjie
Button("提交")
    .kind(ButtonKind.Primary)          // | Default | Primary | Success | Warning | Danger | Info
    .size(ButtonSize.Default)          // | Large | Default | Small

Tag("标签")
    .effect(TagEffect.Plain)           // | Dark | Light | Plain
    .size(TagSize.Small)               // | Default | Large | Medium | Small | Mini
```

枚举值通过 `asClass()` 转为 CSS class，直接写在 DOM 属性中。

## CSS 与样式

组件样式基于 Element Plus SCSS 变量，通过 `@EmbedString` 编译时嵌入二进制：

```cangjie
import cjxt.*
import cjxt.components.*

main() {
    App()
        .UseComponent()          // 编译时嵌入 EP 样式 + 前端 JS
        .configure(AppConfig(...))
        .serve()
}
```

> 使用 `UseComponent()` 后，组件样式自动可用，无需额外下载或配置。

自定义样式放在 `public/scss/element-plus/custom/`：

```scss
// element-plus.scss 中引用 EP 变量
@include b(button) {
  height: getCssVar('button-height');
  background: getCssVar('button-bg-color');
}
```

自定义样式放在 `public/scss/element-plus/custom/`：

```scss
@use '../mixins/mixins' as *;
@use '../common/var' as *;

@include b(button) {
  &.custom-style { ... }
}
```

编译后通过 `@EmbedString` 嵌入二进制，由 `/_cjxt/css/{hash}.css` 提供服务。

## Form 校验

参见 [Form 表单文档](./form)。
