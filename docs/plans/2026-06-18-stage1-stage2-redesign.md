# Stage 1 & Stage 2 组件重新完善设计

## 目标

按 AGENTS.md 的「组件实现流程」，重新完善组件库规划中的 Stage 1（布局与基础）和 Stage 2（表单控件）全部组件，使其在 props、slots、events、样式三个维度对齐 Element Plus。

## 范围

### Stage 1 — 布局与基础（12 个）

| 组件 | 状态 |
|------|------|
| Button | 已存在，简陋 |
| ButtonGroup | 缺失 |
| Row | 缺失 |
| Col | 缺失 |
| Card | 已存在，简陋 |
| Divider | 已修复，需复核 |
| Text | 已存在，简陋 |
| Link | 缺失 |
| Tag | 已存在，简陋 |
| Badge | 缺失 |
| Space | 已存在，简陋 |
| Icon | 已存在，简陋 |

### Stage 2 — 表单控件（10 个 + Form）

| 组件 | 状态 |
|------|------|
| Input | 已存在，简陋 |
| InputNumber | 已存在，简陋 |
| Switch | 已存在，简陋 |
| Radio | 已存在，简陋 |
| RadioGroup | 与 Radio 同文件 |
| Checkbox | 已存在，简陋 |
| CheckboxGroup | 与 Checkbox 同文件 |
| Select | 已存在，简陋 |
| Slider | 已存在，简陋 |
| Rate | 已存在，简陋 |
| Form / FormItem | 已存在，简陋 |

## 实施流程（严格按 AGENTS.md）

每组件：
1. 查本地 Element Plus 文档/源码，确认 Props、Slots、Events
2. 在 `src/components/Types.cj` 定义该组件所需的枚举类型
3. 确认框架能力支持（事件、CSS、信号绑定）
4. 实现组件：`src/components/<Name>.cj`，class `<: Component`
5. CSS：Element Plus SCSS 放入 `public/scss/element-plus/`，编译进 `bundle.css`
6. Showcase：`examples/src/showcase.cj` 添加演示
7. 浏览器测试：启动演示服务，`agent-browser` 验证交互
8. 单元测试：把失败的用例沉淀到 `src/*_test.cj`

## 分批计划

1. **Batch A — Stage 1 基础组件**
   Button、ButtonGroup、Card、Divider、Text、Link、Tag、Badge、Space、Icon
2. **Batch B — Stage 1 布局组件**
   Row、Col
3. **Batch C — Stage 2 基础表单**
   Input、InputNumber、Switch、Radio、RadioGroup、Checkbox、CheckboxGroup
4. **Batch D — Stage 2 复杂表单**
   Select、Slider、Rate、Form、FormItem

## 验收标准

- 每个组件的 Props / Slots / Events 与 Element Plus 文档一致
- 每个组件在 Showcase 中有可交互演示
- 每个组件样式正确，通过浏览器截图验证
- 新增/修复的 bug 用例必须沉淀为单元测试
- 每批完成后更新 AGENTS.md「代码总结」

## 构建顺序

1. `cd examples && cjpm build`（生成 CSS module → bundle.css）
2. `./scripts/build-css.sh`（追加 Element Plus 全局样式 → bundle.css）
3. 启动 `./target/release/bin/main` 验证
