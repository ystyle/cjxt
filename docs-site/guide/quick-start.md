# 快速开始

## 环境准备

### 安装仓颉

推荐使用 [cjvs](https://atomgit.com/ystyle/cjvs) 管理仓颉版本：

```bash
cjvs install 1.1.0
cjvs use 1.1.0
```

验证安装：

```bash
cjc --version
```

### 安装 Node.js

文档站和样式编译依赖 Node.js（推荐 v18+），安装 pnpm：

```bash
npm install -g pnpm
```

### 安装 sass

Element Plus 样式编译需要 sass：

```bash
npm install -g sass
```

## 下载项目

```bash
git clone https://atomgit.com/ystyle/cjxt.git
cd cjxt
```

## 构建

### 1. 加载仓颉环境

```bash
eval "$(cjvs env zsh)"
eval "$(cjvs stdx env zsh)"
```

### 2. 构建框架

```bash
cjpm build
```

### 3. 构建示例项目

```bash
cd examples && cjpm build && cd ..
```

### 4. 编译 Element Plus 样式

```bash
./scripts/build-css.sh
```

## 运行演示

```bash
cd examples && ./target/release/bin/main
```

浏览器打开 `http://localhost:8080`。点击 "组件库" tab 查看所有组件演示。

## 项目结构

```
cjxt/
├── src/                          # 框架源码
│   ├── main.cj                   # 入口
│   ├── vnode.cj                  # ComponentNode + 标签辅助函数
│   ├── component.cj              # Component 接口 / 生命周期
│   ├── action.cj                 # ActionContext / PatchResult / Router
│   ├── signal.cj                 # Signal<T> + SignalTracker
│   ├── store.cj                  # Store<S>
│   ├── css.cj                    # CssModule + cssModule
│   ├── config.cj                 # AppConfig
│   ├── app.cj                    # App 类 + 会话循环
│   ├── html.cj                   # HTML 壳 + 前端 JS
│   ├── session.cj                # 会话管理
│   ├── registry.cj               # 路由匹配 + 守卫/布局
│   ├── ws.cj                     # WebSocket 工具
│   ├── components/               # 组件实现
│   │   ├── Types.cj              # 组件参数枚举
│   │   ├── Button.cj
│   │   ├── Input.cj
│   │   ├── Slider.cj
│   │   └── ...
│   ├── macros/                   # 宏定义
│   └── *_test.cj                 # 单元测试
├── examples/                     # 演示项目
│   ├── src/
│   │   ├── entry.cj              # 应用入口
│   │   └── showcase.cj           # 组件库 Showcase
│   └── public/css/
│       ├── bundle.css             # CSS Module（hashed class）
│       └── element-plus.css       # Element Plus 全局样式
├── public/scss/element-plus/      # EP SCSS 源文件
│   └── custom/                    # 自定义样式扩展
├── scripts/build-css.sh           # 编译 EP SCSS 脚本
└── docs-site/                     # 文档站点（VitePress）
```

## 开发命令

| 命令 | 说明 |
|------|------|
| `cjpm build` | 构建框架 |
| `cd examples && cjpm build` | 构建演示项目 |
| `./scripts/build-css.sh` | 编译 EP 样式 |
| `cjpm test` | 运行测试 |
| `cjpm test --filter 'TestName.method'` | 运行单个测试 |
| `cd docs-site && pnpm dev` | 启动文档开发服务器 |
