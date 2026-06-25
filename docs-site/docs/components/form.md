# Form 表单

基于 Element Plus Form，支持校验、布局、错误状态持久化。

## 基础用法

```cangjie
Form([
    FormItem([Input().placeholder("用户名").bind(this.state.username)])
        .label("用户名"),
    FormItem([Input().password().placeholder("密码").bind(this.state.password)])
        .label("密码"),
    Button("登录").kind(ButtonKind.Primary).onClick({ ctx =>
        PatchResult.ReRender
    }),
])
```

## 校验

### FormRule

| 字段 | 类型 | 说明 |
|------|------|------|
| `required` | `Bool` | 必填 |
| `message` | `String` | 错误提示文本 |
| `min` | `Int64` | 最小长度 |
| `max` | `Int64` | 最大长度 |
| `pattern` | `String` | 正则表达式（`std.regex`） |

### 单表单项校验

```cangjie
let item = FormItem([Input().bind(this.state.email)])
    .label("邮箱")
    .bind(this.state.email)
    .rule(FormRule(required: true, message: "必填"))
    .rule(FormRule(min: 5, message: "至少5个字符"))
    .rule(FormRule(pattern: "^\\w+@\\w+\\.\\w+$", message: "格式错误"))
    .errorSignal(this.state.emailError)

// 手动校验
let ok = item.validate()
```

### Form 统一校验

```cangjie
let form = Form([
    itemUser,
    itemPwd,
    itemEmail,
])
let allValid = form.validate()
form.clearValidate()
```

`Form.validate()` 自动遍历所有 `FormItem` 子项，逐个校验并收集错误。`clearValidate()` 清空所有错误状态。

### 校验状态 class

| class | 条件 |
|-------|------|
| `is-error` | `validate()` 返回 `false` |
| `is-success` | `validate()` 返回 `true` |
| `is-required` | `required()` 或 `FormRule(required: true)` |

## 状态持久化

FormItem 实例在父组件每次 `render()` 时重新创建，错误状态需要通过外部 Signal 持久化：

```cangjie
class MyState <: AppState {
    var email = Signal<String>("")
    var emailError = Signal<String>("")
}
```

通过 `errorSignal()` 传入：

```cangjie
FormItem([Input().bind(this.state.email)])
    .errorSignal(this.state.emailError)
```

## 布局

### 标签顶部

```cangjie
Form([...]).labelTop()      // 标签在输入框上方
```

### 行内布局

```cangjie
Form([...]).inline()        // 表单项水平排列
```

### 标签宽度

```cangjie
Form([...]).labelWidth("100px")   // 统一标签宽度
```

FormItem 自动继承 Form 的布局设置。

## 完整示例

```cangjie
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
            Button("登录").kind(ButtonKind.Primary).onClick({ ctx =>
                if (Form([itemUser, itemPwd]).validate()) {
                    // 登录逻辑
                }
                PatchResult.ReRender
            }),
        ])
    }
}
```

## API

```cangjie
// Form
class Form <: Component
    init(children)                    // 自动识别 FormItem 子项
    add(item: FormItem): Form
    validate(): Bool                  // 统一校验所有子项
    clearValidate()
    labelTop(): Form                  // 标签顶部
    inline(): Form                    // 行内布局
    labelWidth(v: String): Form      // 标签宽度

// FormItem
class FormItem <: Component
    label(v: String): FormItem
    required(): FormItem
    error(v: String): FormItem       // 直接设置错误文本
    rule(r: FormRule): FormItem
    bind(signal: Signal<String>): FormItem  // 校验读取 Signal
    errorSignal(signal: Signal<String>): FormItem  // 错误状态持久化
    validate(): Bool
    clearValidate()
```

## 枚举

```cangjie
FormRule(
    required: Bool = false,
    message: String = "",
    min: Int64 = 0,
    max: Int64 = 0,
    pattern: String = "",
)
```
