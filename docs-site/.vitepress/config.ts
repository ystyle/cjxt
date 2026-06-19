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
      { text: '首页', link: '/' },
      { text: '快速开始', link: '/guide/quick-start' },
      { text: '指南', link: '/guide/architecture' },
      { text: '组件库', link: '/components' },
    ],
    sidebar: {
      '/guide/': [
        {
          text: '指南',
          items: [
            { text: '快速开始', link: '/guide/quick-start' },
            { text: '架构与核心概念', link: '/guide/architecture' },
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
