# 快速开始

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
import cjxt.components.*

class Counter <: Component {
    var count = Signal<Int64>(0)

    public func render(): IComponent {
        div([
            h1([text("cjxt Demo")]),
            p([text("计数: ${this.count.get()}")]),
            Button("+1").onClick({ ctx =>
                this.count.update(fn: { v => v + 1 })
                PatchResult.ReRender
            }),
            Button("-1").onClick({ ctx =>
                this.count.update(fn: { v => v - 1 })
                PatchResult.ReRender
            }),
        ])
    }
}

main() {
    App()
        .configure(AppConfig(title: "cjxt Demo"))
        .UseComponent()      // EP 样式（编译期嵌入）
        .addCSS(siteCss())   // 页面样式模块（@importCSS 的 "_css" 全文）
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
