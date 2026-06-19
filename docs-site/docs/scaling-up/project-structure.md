# 项目结构

## 仓颉模块化

仓颉通过 `package` 声明组织模块。一个项目可以有多个子包，源码都在 `src/` 下，通过文件内的 `package` 声明区分。

```bash
my-app/
├── cjpm.toml
└── src/
    ├── main.cj              # package myapp
    ├── utils.cj             # package myapp
    ├── pages/
    │   ├── home.cj          # package myapp.pages
    │   └── about.cj         # package myapp.pages
    └── components/
        ├── Types.cj         # package myapp.components
        ├── MyButton.cj      # package myapp.components
        └── MyCard.cj        # package myapp.components
```

导入方式：

```cangjie
import myapp.pages.*
import myapp.components.{MyButton, MyCard}
```

## 推荐目录结构

### 小型项目

```bash
project/
├── cjpm.toml
└── src/
    ├── main.cj              # 入口 + 路由
    └── pages.cj             # 所有页面组件
```

### 中型项目

```bash
project/
├── cjpm.toml
├── public/
│   └── css/                 # 样式文件
└── src/
    ├── main.cj              # 入口
    ├── app.cj               # App 配置
    ├── states.cj            # AppState 定义
    ├── pages/
    │   ├── home.cj
    │   ├── about.cj
    │   └── user.cj
    └── components/
        ├── Types.cj         # 组件枚举
        ├── MyButton.cj
        └── MyCard.cj
```

### 大型项目（多子包）

```bash
project/
├── cjpm.toml
├── public/
│   ├── css/
│   │   ├── bundle.css
│   │   └── element-plus.css
│   └── scss/
│       └── components/
└── src/
    ├── main.cj              # 入口
    ├── app.cj               # 应用配置
    ├── routes.cj            # 路由注册
    │
    ├── states/              # package project.states
    │   ├── user.cj
    │   └── order.cj
    │
    ├── pages/               # package project.pages
    │   ├── home.cj
    │   ├── user/
    │   │   ├── list.cj
    │   │   └── detail.cj
    │   └── order/
    │       ├── list.cj
    │       └── detail.cj
    │
    ├── components/          # package project.components
    │   ├── Types.cj         # 组件参数枚举
    │   ├── MyButton.cj
    │   ├── MyTable.cj
    │   └── MyDialog.cj
    │
    └── utils/               # package project.utils
        ├── format.cj
        └── validate.cj
```

## 组件子包

参考 cjxt 的 `src/components/`，每个组件一个文件，同属 `package project.components`：

`src/components/Types.cj`：

```cangjie
package project.components

public enum MyButtonKind {
    | Default | Primary | Success
}
```

`src/components/MyButton.cj`：

```cangjie
package project.components

import cjxt.*
import cjxt.components.*

public class MyButton <: Component {
    var _kind: MyButtonKind = MyButtonKind.Default

    public func kind(v: MyButtonKind): MyButton {
        this._kind = v; this
    }

    public func render(): IComponent {
        var cls = "my-button"
        match (this._kind) {
            case MyButtonKind.Primary =>
                cls = "${cls} my-button--primary"
            case _ => ()
        }
        Button("按钮").kind(ButtonKind.Primary).attr("class", cls)
    }
}
```

使用时：

```cangjie
import project.components.*

MyButton().kind(MyButtonKind.Primary)
```

## 宏子包

宏必须放在独立的包中，使用 `macro package` 声明。宏包**只能导出宏**，不能导出函数、类等公共声明（但可以定义包内私有的辅助函数）：

```cangjie
// src/macros/my_macro.cj
macro package project.macros
import std.ast.*

// 包内私有的辅助函数（对外不可见）
func helper(): String { "computed" }

// 宏（对外可见）
public macro myMacro(input: Tokens): Tokens {
    input
}
```

宏包目录结构与普通包一样，放在 `src/` 下：

```bash
src/
└── macros/
    ├── my_macro.cj          # macro package project.macros
    └── utils.cj             # macro package project.macros
```

## 注意事项

- 包名通常使用小写，多级用 `.` 分隔：`project.components`
- 宏包使用 `macro package` 声明，只能导出宏定义
- 循环引用：`package A` 引用 `package B`，`package B` 不能再引用 `package A`
