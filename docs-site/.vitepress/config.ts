import { defineConfig } from 'vitepress'

export default defineConfig({
  base: process.env.DOCS_BASE || '/cjxt/',
  title: 'cjxt',
  description: '仓颉全栈服务端驱动 UI 框架',
  lang: 'zh-CN',
  head: [
    ['link', { rel: 'icon', href: '/cjxt/favicon.ico' }],
    ['meta', { name: 'theme-color', content: '#409eff' }],
  ],
  themeConfig: {
    logo: '/cjxt/logo.svg',
    siteTitle: 'cjxt',
    nav: [
      { text: '文档', link: '/docs/quick-start' },
      { text: '核心概念', link: '/essentials/architecture' },
      { text: 'API', link: '/reference/api' },
    ],
    sidebar: {
      '/docs/': [
        {
          text: '基础',
          items: [
            { text: '快速开始', link: '/docs/quick-start' },
            { text: '响应式：Signal', link: '/docs/basics/signal' },
            { text: '组件系统', link: '/docs/basics/component' },
            { text: '事件处理', link: '/docs/basics/events' },
            { text: '表单与数据绑定', link: '/docs/basics/forms' },
            { text: 'VNode 与 DSL', link: '/docs/basics/vnode-dsl' },
            { text: 'CSS 体系', link: '/docs/basics/styling' },
            { text: '路由系统', link: '/docs/basics/routing' },
          ],
        },
        {
          text: '组件库',
          items: [
            { text: '组件索引', link: '/docs/components/' },
            { text: '使用指南', link: '/docs/components/usage' },
            { text: 'Table 表格', link: '/docs/components/table' },
            { text: 'Dialog 对话框', link: '/docs/components/dialog' },
            { text: 'Form 表单', link: '/docs/components/form' },
          ],
        },
        {
          text: '应用规模化',
          items: [
            { text: '项目结构', link: '/docs/scaling-up/project-structure' },
            { text: '会话与 WebSocket', link: '/docs/scaling-up/session' },
            { text: '宏系统', link: '/docs/scaling-up/macros' },
          ],
        },
      ],
      '/essentials/': [
        {
          text: '核心概念',
          items: [
            { text: '架构总览', link: '/essentials/architecture' },
            { text: '响应式：Signal', link: '/essentials/reactivity' },
            { text: '组件系统', link: '/essentials/component' },
            { text: 'VNode 与 DSL', link: '/essentials/vnode-dsl' },
            { text: 'CSS 体系', link: '/essentials/styling' },
            { text: '路由系统', link: '/essentials/routing' },
          ],
        },
      ],
      '/reference/': [
        {
          text: '参考',
          items: [
            { text: 'API 索引', link: '/reference/api' },
          ],
        },
      ],
    },
    socialLinks: [
      { icon: 'github', link: 'https://atomgit.com/ystyle/cjxt' },
    ],
    footer: {
      message: '基于 MIT 协议开源',
      copyright: 'Copyright © 2024-2026 ystyle',
    },
    editLink: {
      pattern: 'https://atomgit.com/ystyle/cjxt/src/branch/master/docs-site/:path',
      text: '在 AtomGit 上编辑此页',
    },
  },
})
