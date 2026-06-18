# Batch A — Stage 1 基础组件实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 按 Element Plus 重新实现 Stage 1 基础组件：Button、ButtonGroup、Card、Divider、Text、Link、Tag、Badge、Space、Icon。

**Architecture:** 每个组件独立文件于 `src/components/`，类型枚举统一放 `src/components/Types.cj`，样式使用 Element Plus SCSS 编译进 `examples/public/css/bundle.css`，Showcase 演示放 `examples/src/showcase.cj`。

**Tech Stack:** Cangjie 1.1, cjxt 框架, Element Plus SCSS, sass, agent-browser。

---

## 前置检查

### Task 0: 确认本地 Element Plus 源码路径

**Files:**
- Read: `~/Projects/element-plus/packages/theme-chalk/src/`

**Step 1:** 列出需要拷贝的 SCSS 文件

Run: `ls ~/Projects/element-plus/packages/theme-chalk/src/{button,button-group,card,divider,text,link,tag,badge,space,icon}.scss`

Expected: 文件均存在。

**Step 2:** 检查当前 `public/scss/element-plus/` 中是否已有对应 scss

Run: `ls public/scss/element-plus/`

Expected: 部分已存在（button.scss, card.scss, divider.scss, text.scss, tag.scss, space.scss, icon.scss），button-group.scss 和 badge.scss 缺失。

---

## Button / ButtonGroup

### Task 1: 查 Element Plus 文档

**Files:**
- Read: `~/Projects/element-plus/packages/components/button/src/button.vue`
- Read: `~/Projects/element-plus/packages/components/button/src/button-group.vue`

记录 Props：size、type、plain、round、circle、loading、disabled、icon、native-type、autofocus；Events：click；Slots：default。

### Task 2: Types.cj 补充 Button 枚举

**Files:**
- Modify: `src/components/Types.cj`

新增：
- `ButtonType`（与 `ButtonKind` / `ComponentKind` 对齐或合并）
- `ButtonSize` 已存在，确认覆盖 Large / Default / Small
- `ButtonNativeType`：Button | Submit | Reset

### Task 3: 实现 Button.cj

**Files:**
- Modify: `src/components/Button.cj`

要求：
- 支持 `ButtonKind` / `ButtonType` / `ComponentKind` 统一
- 支持 size、plain、round、circle、loading、disabled、icon
- loading 状态显示 spinner 并禁用点击
- 使用 `VNode` 构建 `<button class="el-button ...">`

### Task 4: 实现 ButtonGroup.cj

**Files:**
- Create: `src/components/ButtonGroup.cj`

要求：
- 接收 `Array<IComponent>`
- 渲染 `<div class="el-button-group">...</div>`

### Task 5: Button SCSS

**Files:**
- Copy: `~/Projects/element-plus/packages/theme-chalk/src/button.scss` → `public/scss/element-plus/button.scss`
- Create: `public/scss/element-plus/button-group.scss`
- Modify: `public/scss/element-plus/element-plus.scss` 添加 `@use 'button-group.scss';`

### Task 6: Showcase 演示

**Files:**
- Modify: `examples/src/showcase.cj`

更新 `demoButton()` 和 `demoButtonGroup()`，展示：
- Default / Primary / Success / Warning / Danger / Info
- Plain / Round / Circle / Disabled / Loading
- 按钮组

### Task 7: 浏览器验证

Run:
```bash
cd examples && cjpm build
./scripts/build-css.sh
./target/release/bin/main
```

使用 `agent-browser` 点击 Button 菜单，验证样式和点击事件。

### Task 8: 单元测试

**Files:**
- Modify: `src/components_test.cj`（如不存在则创建）

新增 Button class 生成测试。

### Task 9: Commit

```bash
git add src/components/Button.cj src/components/ButtonGroup.cj src/components/Types.cj \
  public/scss/element-plus/button.scss public/scss/element-plus/button-group.scss \
  public/scss/element-plus/element-plus.scss examples/src/showcase.cj \
  src/components_test.cj examples/public/css/bundle.css
git commit -m "feat: Button/ButtonGroup 按 Element Plus 重新实现"
```

---

## Card

### Task 10: 查 EP 文档

Props：header、footer、body-style、body-class、shadow。
Slots：header、default、footer。

### Task 11: 实现 Card.cj

支持 header/footer slot 和 shadow 枚举。

### Task 12: Card SCSS

拷贝/更新 `public/scss/element-plus/card.scss`。

### Task 13: Showcase 演示

展示：默认卡片、带阴影、带 header/footer。

### Task 14: 验证 + Commit

---

## Divider

### Task 15: 复核 Divider.cj

已修复，确认 direction / content-position 行为正确。

### Task 16: Showcase 演示

已优化，确认无需改动。

---

## Text

### Task 17: 查 EP 文档

Props：type、size、truncated、line-clamp、tag。

### Task 18: Types.cj 补充

确认 `TextSize` 和 `ComponentKind` 足够，或新增 `TextType`。

### Task 19: 实现 Text.cj

支持 size、truncated。

### Task 20: Text SCSS + Showcase + Commit

---

## Link

### Task 21: 查 EP 文档

Props：type、underline、disabled、href、icon。
Events：click。

### Task 22: 实现 Link.cj

Create `src/components/Link.cj`。

### Task 23: Link SCSS + Showcase + Commit

---

## Tag

### Task 24: 查 EP 文档

Props：type、size、closable、hit、round、effects。
Events：close、click。

### Task 25: 实现 Tag.cj

支持 closable（显示关闭图标并触发 close 事件）。

### Task 26: Tag SCSS + Showcase + Commit

---

## Badge

### Task 27: 查 EP 文档

Props：value、max、is-dot、hidden、type、show-zero、offset、badge-style。

### Task 28: 实现 Badge.cj

Create `src/components/Badge.cj`。

### Task 29: Badge SCSS + Showcase + Commit

---

## Space

### Task 30: 查 EP 文档

Props：direction、size、wrap、alignment、fill、spacer。

### Task 31: 实现 Space.cj

支持 direction / wrap / size。

### Task 32: Space SCSS + Showcase + Commit

---

## Icon

### Task 33: 查 EP 文档

Props：size、color、icon（svg 或类名）。

### Task 34: 实现 Icon.cj

使用 Element Plus 的图标字体或 SVG。当前使用类名 `el-icon-${name}`，确认样式匹配。

### Task 35: Icon SCSS + Showcase + Commit

---

## Batch A 收尾

### Task 36: 全量构建与浏览器回归

Run:
```bash
cd examples && cjpm build
./scripts/build-css.sh
./target/release/bin/main
```

使用 `agent-browser` 遍历所有 Stage 1 组件菜单。

### Task 37: 更新 AGENTS.md

在「代码总结」追加 Batch A 完成记录。

### Task 38: Commit

```bash
git add AGENTS.md docs/plans/2026-06-18-batch-a-stage1-basic.md
git commit -m "docs: Batch A 计划与代码总结"
```
