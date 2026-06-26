# Drawer 抽屉组件实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现 Drawer 抽屉组件，支持四个方向（ltr/rtl/ttb/btt）

**Architecture:** 与 Dialog 共享遮罩层结构和关闭逻辑，DOM 结构一致，CSS 复用 EP drawer.scss。状态通过外置 Signal 持久化。

**Tech Stack:** cjxt components + embed + Element Plus SCSS

---

### Task 1: 复制 EP drawer.scss 并引入

**Files:**
- Create: `public/scss/element-plus/drawer.scss`
- Modify: `public/scss/element-plus/element-plus.scss`
- Build: `bash scripts/build-css.sh`

**Step 1: 复制样式**

从 `/home/ystyle/Projects/element-plus/packages/theme-chalk/src/drawer.scss` 复制到 `public/scss/element-plus/drawer.scss`

```bash
cp ~/Projects/element-plus/packages/theme-chalk/src/drawer.scss public/scss/element-plus/drawer.scss
```

**Step 2: 在 element-plus.scss 中引入**

添加 `@use 'drawer';` 到 `public/scss/element-plus/element-plus.scss`

**Step 3: 编译 CSS**

```bash
bash scripts/build-css.sh
```

验证：`grep "el-drawer" public/css/element-plus.css` 应有匹配

**Step 4: 提交**

```bash
git add public/scss/element-plus/drawer.scss public/scss/element-plus/element-plus.scss public/css/element-plus.css examples/public/css/element-plus.css scripts/build-css.sh
git commit -m "feat(Drawer): 引入 EP drawer.scss 样式"
```

---

### Task 2: 实现 Drawer.cj 组件

**Files:**
- Create: `src/components/Drawer.cj`

**Step 1: 创建 Drawer.cj**

参照 Dialog.cj 结构：
- `DrawerDirection` 枚举：`LTR | RTL | TTB | BTT`
- `Drawer` class，Props 见设计文档
- `render()` 方法与 Dialog 相同结构，区别：
  - class 用 `el-drawer` + 方向 class
  - 方向 class 通过 `DrawerDirection` 枚举映射：`LTR→"ltr"`, `RTL→"rtl"`, `TTB→"ttb"`, `BTT→"btt"`
  - size 通过 CSS 变量 `--el-drawer-size`
  - header class 用 `el-drawer__header` / `el-drawer__title` / `el-drawer__close-btn` / `el-drawer__close`
  - body class 用 `el-drawer__body`
  - footer class 用 `el-drawer__footer`
  - `withHeader` 控制 header 是否渲染

**Step 2: 验证编译**

```bash
cd examples && rm -rf target/release/cjxt && eval "$(cjvs env zsh)" && eval "$(cjvs stdx env zsh)" && cjpm build
```

预期：编译成功

**Step 3: 提交**

```bash
git add src/components/Drawer.cj
git commit -m "feat(Drawer): 组件实现"
```

---

### Task 3: Showcase 演示

**Files:**
- Modify: `examples/src/showcase.cj`

**Step 1: 添加 Drawer 演示**

在 showcase 添加两个 demo：
1. **基础用法** — 默认右侧弹出，title + children + footer（取消/确认按钮）
2. **四个方向** — 用 Select/MenuItem 切换方向

参照 Dialog 的 showcase 代码风格（`demoDialog()` → `demoDrawer()`）。

**Step 2: 验证编译+启动**

```bash
cd examples && rm -rf target/release/cjxt && cjpm build && ./target/release/bin/main
```

**Step 3: 浏览器验证**

```bash
agent-browser open http://localhost:8080/showcase
# 点击 Drawer 导航
# 点击打开按钮，验证抽屉从右侧滑出
# 切换方向验证
# 点击遮罩层关闭验证
```

**Step 4: 提交**

```bash
git add examples/src/showcase.cj
git commit -m "feat(Drawer): showcase 演示"
```

---

### Task 4: 运行测试

```bash
cd /home/ystyle/Projects/Cangjie/cjxt && cjpm test
```

预期：42+ 测试全部通过（新增无单元测试，现有不受影响）

---

### 完整构建顺序

```bash
cd /home/ystyle/Projects/Cangjie/cjxt
bash scripts/build-css.sh
cd examples
rm -rf target/release/cjxt
eval "$(cjvs env zsh)" && eval "$(cjvs stdx env zsh)"
cjpm build
./target/release/bin/main
```
