---
layout: home

hero:
  name: cjxt
  text: 仓颉全栈服务端驱动 UI 框架
  tagline: 基于仓颉语言，服务端渲染，零前端框架依赖。Elment Plus 设计语言，全栈 Type Safety。
  image:
    src: /cjxt/logo.svg
    alt: cjxt
  actions:
    - theme: brand
      text: 快速开始
      link: /guide/quick-start
    - theme: alt
      text: 在 AtomGit 查看源码
      link: https://atomgit.com/ystyle/cjxt
    - theme: alt
      text: 架构与核心概念
      link: /guide/architecture

features:
  - icon: ⚡️
    title: 服务端渲染
    details: 状态在服务端，ComponentNode JSON 通过 WebSocket 增量推送前端，无需 Virtual DOM。
  - icon: 🔗
    title: 响应式 Signal
    details: Signal<T> 提供 get/set/subscribe，SignalTracker 自动追踪依赖，精确脏检测，只重渲变更组件。
  - icon: 🎨
    title: Element Plus 设计
    details: 组件 props/slots/events 对齐 Element Plus，SCSS 变量复用，自定义扩展目录覆盖。
  - icon: 🪶
    title: 零前端框架
    details: 前端 JS 不到 5KB，原生事件委托，CangjieUI 类直接操作 DOM，无 React/Vue 等依赖。
  - icon: 🛡️
    title: 全栈类型安全
    details: 仓颉类型系统从前端序列化到后端处理，Signal 泛型 + JsonDeserializable 编译期检查。
  - icon: 📦
    title: 宏系统
    details: '@Page 路由宏、@importCSS CSS module、@sass 样式宏，编译期生成代码。'
---
