# Select 组件功能增强设计

## 目标

在现有的单选 Select 基础上，对齐 Element Plus 的核心功能：多选、清除、可搜索、选项分组。

## 设计

### Select 类

```cj
public class Select <: Component {
    var _signal: Option<Signal<String>> = None        // 单选绑定
    var _multiSignal: Option<Signal<ArrayList<String>>> = None  // 多选绑定
    var _children: Array<IComponent>
    var _placeholder: String = ""
    var _disabled: Bool = false
    var _multiple: Bool = false       // 是否多选模式
    var _clearable: Bool = false      // 是否可清除
    var _filterable: Bool = false     // 是否可搜索
    var _open: Signal<Bool>           // 下拉展开状态
    var _filterText: Signal<String>   // 搜索文本
}
```

### 方法

| 方法 | 作用 |
|------|------|
| `bind(signal: Signal<String>)` | 单选绑定（已有） |
| `bindMulti(signal: Signal<ArrayList<String>>)` | 多选绑定 |
| `placeholder(v: String)` | 占位文本（已有） |
| `disabled()` | 禁用（已有） |
| `multiple()` | 开启多选模式 |
| `clearable()` | 开启清除 |
| `filterable()` | 开启搜索 |

### 渲染逻辑

#### 单选（现有，不变）

- `.el-select__selection` 内显示 `<span class="el-select__selected-item">` 或 `<span class="el-select__placeholder is-transparent">`

#### 多选（新增）

- `.el-select__selection` 内显示多个 `el-tag`：
  - 每个选中值对应一个 `<span class="el-tag el-tag--info">`
  - 内容为选项 label
  - 关闭按钮（×）点击后从选中列表中移除该值
- 无选中值时显示 placeholder
- 通过 `is-selected` class 标记下拉中已选项

#### 清除图标

- `_clearable` 为 true 且当前有选中值时，在 suffix 位置显示清除图标
- 点击清除：单选时置空字符串，多选时置空 ArrayList

#### 搜索

- `_filterable` 为 true 时，在下拉列表顶部渲染 `<input class="el-select__input">`
- 输入时更新 `_filterText` 信号
- 选项过滤：只显示 label 文本包含 `_filterText` 的选项
- 过滤不区分大小写（可选）

#### 选项分组

```cj
public class SelectOptionGroup <: Component {
    var _label: String
    var _children: Array<IComponent>
    // 渲染为：
    // <li class="el-select-dropdown__group">
    //   <span class="el-select-dropdown__group-title">label</span>
    //   <ul><option children...></ul>
    // </li>
}
```

#### 自定义模板（已有）

`SelectOption` 的 children 直接作为选项内容渲染，不受影响。

### CSS

需要在 `element-plus.scss` 中补充（如果 EP 对应样式缺失）：

- `.el-select-dropdown__group` / `__group-title`（已由 `option.scss` 提供）
- `.el-select__input`（搜索输入框，已由 `select.scss` 提供）
- `.el-tag` 样式（已有 `tag.scss`，但 EP tag.scss 依赖较多，可能需要补充）

需要确认 `tag.scss` 是否已包含在 `element-plus.scss` 中。如缺少则补充。

### 限制

- 下拉无 teleport，直接绝对定位在 `.el-select` 内
- 搜索不支持远程模式（可后续扩展）
- 不支持键盘导航
- 不支持 allow-create
