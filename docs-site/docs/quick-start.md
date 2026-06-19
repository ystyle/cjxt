# 快速开始

本指南将带你创建一个使用 cjxt 的新项目。

如果你希望查看组件库演示或框架完整示例，请直接运行 [examples 项目](https://atomgit.com/ystyle/cjxt/tree/master/examples)。

## 前提

安装仓颉：从 [https://cangjie-lang.cn/download](https://cangjie-lang.cn/download) 下载安装。

安装 stdx：从 [https://atomgit.com/cangjie/cangjie_stdx](https://atomgit.com/cangjie/cangjie_stdx) 下载并配置环境变量：

```bash
export CANGJIE_STDX_PATH="/path/to/stdx/版本号/平台/static/stdx"
# 例如：
# export CANGJIE_STDX_PATH="/home/user/.config/cjvs/stdx/1.1.0/linux_x86_64_cjnative/static/stdx"
```

学习仓颉：参考 [https://cangjie-lang.cn/docs](https://cangjie-lang.cn/docs)。

## 创建项目

```bash
mkdir cjxt-demo
cd cjxt-demo
cjpm init
```

## 添加依赖

编辑 `cjpm.toml`，添加：

```toml
[dependencies]
cjxt = { git = "https://atomgit.com/ystyle/cjxt.git", branch = "master" }
```

## 编写代码

`src/main.cj`：

```cangjie
package demo

import cjxt.*

@Page["/"]
class Counter <: Component {
    var count = Signal<Int64>(0)

    public func render(): IComponent {
        div([
            text("计数: ${this.count.get()}"),
            button(text("+")).onClick({ ctx =>
                this.count.update(fn: { v => v + 1 })
                PatchResult.ReRender
            }),
            button(text("-")).onClick({ ctx =>
                this.count.update(fn: { v => v - 1 })
                PatchResult.ReRender
            }),
        ])
    }
}

main() {
    App()
        .configure(AppConfig(title: "cjxt Demo"))
        .serve()
}
```

## 编译运行

```bash
cjpm build
./target/release/bin/demo
```

浏览器打开 `http://localhost:8080`。

## 完整示例

组件库 Showcase 和更多用法参考 [examples 目录](https://atomgit.com/ystyle/cjxt/tree/master/examples)。
