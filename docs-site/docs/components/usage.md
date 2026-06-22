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

组件样式基于 Element Plus SCSS 变量：

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

编译后通过 `element-plus.css` 独立加载。

## Form 校验

```cangjie
// 定义规则
let item = FormItem([Input().bind(this.state.email)])
    .label("邮箱")
    .bind(this.state.email)
    .rule(FormRule(required: true, message: "必填"))
    .rule(FormRule(min: 5, message: "至少5个字符"))
    .rule(FormRule(pattern: "^\\w+@\\w+\\.\\w+$", message: "格式错误"))
    .errorSignal(this.state.emailError)    // 错误信号，跨 render 持久化

// 手动校验
let ok = item.validate()

// 表单统一校验
Form([itemUser, itemPwd, itemEmail]).validate()
```

`errorSignal` 是必需的——因为组件实例在每次渲染时重新创建，错误状态需要通过外部 `Signal` 持久化。

## 组合示例

```cangjie
import cjxt.*
import cjxt.components.*

class LoginForm <: Component {
    var state = LoginState()

    public func render(): IComponent {
        let itemUser = FormItem([Input().placeholder("用户名").bind(this.state.username)])
            .label("用户名")
            .bind(this.state.username)
            .rule(FormRule(required: true, message: "请输入用户名"))
            .errorSignal(this.state.userError)

        let itemPwd = FormItem([Input().password().placeholder("密码").bind(this.state.password)])
            .label("密码")
            .bind(this.state.password)
            .rule(FormRule(required: true, message: "请输入密码"))
            .errorSignal(this.state.pwdError)

        div([
            Form([itemUser, itemPwd]),
            PrimaryButton("登录").onClick({ ctx =>
                if (Form([itemUser, itemPwd]).validate()) {
                    // 登录逻辑
                }
                PatchResult.ReRender
            }),
        ])
    }
}
```
