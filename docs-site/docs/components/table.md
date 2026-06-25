# Table 表格

基于 Element Plus Table，数据驱动、服务端排序/选择/高亮。

## 基础用法

```cangjie
let data = Signal(ArrayList<HashMap<String, String>>())

// 初始化数据
data.set(initTableData())

let table = Table()
    .data(data)
    .add(TableColumn().colProp("date").label("Date").width(120))
    .add(TableColumn().colProp("name").label("Name").width(120))
    .add(TableColumn().colProp("address").label("Address").width(240))
table.render()
```

## Table 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `data(signal)` | `Signal<ArrayList<HashMap<String, String>>>` | 表格数据源 |
| `add(col)` | `TableColumn` | 添加列配置（链式调用多次） |
| `stripe()` | `Bool` | 斑马纹 |
| `border()` | `Bool` | 纵向边框 |
| `height(v)` | `String` | 固定高度（body 自动滚动） |
| `maxHeight(v)` | `String` | 最大高度 |
| `size(v)` | `ComponentSize2` | 表格尺寸：`Large | Default | Small` |
| `fit(v)` | `Bool` (默认 `true`) | 列宽自适应 |
| `showHeader(v)` | `Bool` (默认 `true`) | 是否显示表头 |
| `highlight()` | `Bool` | 高亮当前行（点击行选中） |
| `emptyText(v)` | `String` (默认 `"No Data"`) | 空数据提示文本 |
| `showSummary()` | `Bool` | 显示汇总行 |
| `sumText(v)` | `String` (默认 `"Sum"`) | 汇总行首列文本 |
| `sortColumn(signal)` | `Signal<String>` | 排序列 prop，外置信号持久化排序状态 |
| `sortOrder(signal)` | `Signal<SortOrder>` | 排序方向：`None | Ascending | Descending` |
| `selectedRows(signal)` | `Signal<ArrayList<HashMap<String, String>>>` | 选中行集合，外置信号持久化选择状态 |
| `currentRow(signal)` | `Signal<Option<HashMap<String, String>>>` | 当前高亮行，外置信号持久化 |
| `rowClassName(fn)` | `(row, index) -> String` | 行自定义 class 回调 |
| `rowStyle(fn)` | `(row, index) -> String` | 行自定义 style 回调 |
| `cellClassName(fn)` | `(row, col, rowIdx, colIdx) -> String` | 单元格自定义 class 回调 |
| `cellStyle(fn)` | `(row, col, rowIdx, colIdx) -> String` | 单元格自定义 style 回调 |
| `headerRowClassName(fn)` | `(index) -> String` | 表头行自定义 class 回调 |
| `headerRowStyle(fn)` | `(index) -> String` | 表头行自定义 style 回调 |
| `headerCellClassName(fn)` | `(col, index) -> String` | 表头单元格自定义 class 回调 |
| `headerCellStyle(fn)` | `(col, index) -> String` | 表头单元格自定义 style 回调 |

## TableColumn 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `colProp(v)` | `String` | 对应数据字段 key |
| `label(v)` | `String` | 列标题 |
| `width(v)` | `Int64` | 列宽（px） |
| `minWidth(v)` | `Int64` | 最小列宽（px） |
| `fixed(v)` | `TableFixed` | 固定列：`Left | Right` |
| `sortable()` | `Bool` | 该列可排序 |
| `align(v)` | `TableAlign` | 对齐：`Left | Center | Right` |
| `colType(v)` | `TableColumnType` | 列类型：`Default | Selection | Index` |
| `showOverflowTooltip()` | `Bool` | 内容溢出时显示 tooltip |
| `className(v)` | `String` | 自定义 class |
| `formatter(f)` | `(String) -> String` | 单元格内容格式化函数 |
| `sortBy(v)` | `String` | 指定排序依据字段（默认使用 `colProp`） |
| `reserveSelection()` | `Bool` | 数据更新后是否保留选中状态 |
| `selectable(f)` | `(HashMap<String, String>) -> Bool` | 单选/复选框是否可选 |

## 排序

添加 `sortable()` 启用列排序。点击表头切换升序/降序/取消排序。

```cangjie
let sortColumn = Signal<String>("")
let sortOrder = Signal<SortOrder>(SortOrder.None)

Table()
    .data(data)
    .add(TableColumn().colProp("date").label("Date").width(120).sortable())
    .add(TableColumn().colProp("name").label("Name").width(120).sortable())
    .sortColumn(sortColumn)       // 外置信号持久化排序状态
    .sortOrder(sortOrder)
```

## 多选

添加 `colType(TableColumnType.Selection)` 列启用多选。

```cangjie
let selectedRows = Signal<ArrayList<HashMap<String, String>>>(ArrayList<HashMap<String, String>>())

Table()
    .data(data)
    .add(TableColumn().colType(TableColumnType.Selection).width(50))
    .add(TableColumn().colProp("name").label("Name").width(120))
    .selectedRows(selectedRows)   // 外置信号持久化选中行
```

## 行高亮

```cangjie
Table().data(data).highlight()
```

点击行高亮当前行。结合 `currentRow` 外置信号持久化状态。

## 自定义行/单元格样式

通过回调实现：

```cangjie
Table()
    .rowClassName({row, index =>
        match (row.get("status")) {
            case Some(v) => if (v == "error") { "row-error" } else { "" }
            case None => ""
        }
    })
    .rowStyle({row, index =>
        if (index % 2 == 0) { "background: #fafafa" } else { "" }
    })
```

对应 CSS（使用 `App.addCSS` 添加全局样式）：

```css
.el-table .row-error { --el-table-tr-bg-color: var(--el-color-danger-light-9); }
```

## 汇总行

```cangjie
Table().data(data).showSummary().sumText("合计")
```

## 固定列

```cangjie
TableColumn().colProp("date").label("Date").width(150).fixed(TableFixed.Left)
TableColumn().colProp("actions").label("操作").width(120).fixed(TableFixed.Right)
```

## 注意事项

### 状态持久化

Table 内部的状态信号（排序/选中/高亮）在父组件每次 `render()` 创建新 Table 实例时会丢失。需要通过外置信号持久化：

```cangjie
class MyComponent <: Component {
    var state = MyState()

    public func render(): IComponent {
        Table()
            .data(this.state.data)
            .sortColumn(this.state.sortColumn)     // 外置信号
            .sortOrder(this.state.sortOrder)       // 外置信号
            .selectedRows(this.state.selectedRows) // 外置信号
            .currentRow(this.state.currentRow)     // 外置信号
            .render()
    }
}
```

## 枚举类型

```cangjie
SortOrder:       None | Ascending | Descending
TableColumnType: Default | Selection | Index
TableAlign:      Left | Center | Right
TableFixed:      Left | Right
ComponentSize2:  Large | Default | Small
```
