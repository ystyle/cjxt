// 数据组件演示：Table / Pagination / DatePicker / DateRangePicker / Tree / Cascader / Upload
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.{ArrayList, HashMap}

public func demoTable(st: ShowcaseState): Array<IComponent> {
    let d = st.tableData
    if (d.get().size == 0) {
        d.set(initTableData())
    }
    let columns = ArrayList<TableColumn>()
    columns.add(TableColumn().colType(TableColumnType.Selection).width(50))
    columns.add(TableColumn().colType(TableColumnType.Index).label("#").width(60))
    columns.add(TableColumn().colProp("date").label("Date").width(120).sortable())
    columns.add(TableColumn().colProp("name").label("Name").width(120).sortable())
    columns.add(TableColumn().colProp("state").label("State").width(120))
    columns.add(TableColumn().colProp("city").label("City").width(120))
    columns.add(TableColumn().colProp("address").label("Address").width(200).showOverflowTooltip())
    let tbl = Table()
        .data(d)
        .border()
        .stripe()
        .highlight()
        .height("300px")
        .sortColumn(st.tableSortColumn)
        .sortOrder(st.tableSortOrder)
        .selectedRows(st.tableSelectedRows)
        .currentRow(st.tableCurrentRow)
    for (c in columns) { tbl.add(c) }
    [
        demoSection("带边框 / 斑马纹 / 高亮当前行 / 排序 / 多选", [
            tbl.render(),
        ]),
        demoSection("空数据表格", [
            Table()
                .data(Signal<ArrayList<HashMap<String, String>>>(ArrayList<HashMap<String, String>>()))
                .add(TableColumn().colProp("name").label("Name").width(120))
                .add(TableColumn().colProp("email").label("Email").width(200))
                .render(),
        ]),
    ]
}

public func demoPagination(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("基础分页（prev / pager / next / total）", [
            div([
                Pagination()
                    .total(500)
                    .currentPage(st.paginationPage)
                    .pageSize(st.paginationSize)
                    .background(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("完整布局（prev / pager / next / sizes / jumper / total）", [
            div([
                Pagination()
                    .total(1000)
                    .layout("prev, pager, next, sizes, jumper, total")
                    .pageSizes([10, 20, 50, 100])
                    .currentPage(st.paginationPage)
                    .pageSize(st.paginationSize)
                    .background(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("小尺寸 + 单页隐藏", [
            div([
                Pagination()
                    .total(3)
                    .pageSizes([5, 10])
                    .currentPage(st.paginationPage)
                    .pageSize(st.paginationSize)
                    .small(),
                Pagination()
                    .total(3)
                    .currentPage(st.paginationPage)
                    .pageSize(st.paginationSize)
                    .hideOnSinglePage(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("当前状态", [
            div([text("第 ${st.paginationPage.get()} 页，每页 ${st.paginationSize.get()} 条（共 1000 条）")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoDatePicker(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("日期选择（DatePicker）", [
            div([
                DatePicker().bind(st.dateValue).clearable(),
                div([text("当前选择：${st.dateValue.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("区间选择（DateRangePicker）", [
            div([
                DateRangePicker()
                    .start(st.rangeStart)
                    .end(st.rangeEnd)
                    .clearable(),
                div([text("当前区间：${st.rangeStart.get()} ~ ${st.rangeEnd.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
        demoSection("禁用状态", [
            div([
                DatePicker().bind(st.dateValue).disabled(),
                DateRangePicker().start(st.rangeStart).end(st.rangeEnd).disabled(),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoTree(st: ShowcaseState): Array<IComponent> {
    // 组织架构
    let org = ArrayList<TreeNode>([
        TreeNode("产品部", ArrayList<TreeNode>([
            TreeNode("前端组", ArrayList<TreeNode>([
                TreeNode("框架组"),
                TreeNode("业务组"),
            ])),
            TreeNode("后端组"),
        ])),
        TreeNode("设计部", ArrayList<TreeNode>([
            TreeNode("UI 组"),
            TreeNode("交互组"),
        ])),
        TreeNode("市场部"),
    ])
    [
        demoSection("树形控件（Tree）", [
            div([
                Tree(org).expanded(st.treeExpanded).currentKey(st.treeCurrent).onNodeClick { path, label =>
                    st.treeNodeLabel.set(label)
                    PatchResult.ReRender
                },
            ], attrs: Some(HashMap<String, String>([("style", "width:100%")]))),
            div([text("当前选中：${st.treeNodeLabel.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("点 ▶ 展开/收起子节点；点标签选中高亮并回传路径与标签")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoCascader(st: ShowcaseState): Array<IComponent> {
    let regions = ArrayList<CascaderNode>([
        CascaderNode("浙江", "zj", ArrayList<CascaderNode>([
            CascaderNode("杭州", "hz", ArrayList<CascaderNode>([
                CascaderNode("西湖区", "xh"),
                CascaderNode("滨江区", "bj"),
            ])),
            CascaderNode("宁波", "nb"),
        ])),
        CascaderNode("江苏", "js", ArrayList<CascaderNode>([
            CascaderNode("南京", "nj"),
        ])),
    ])
    [
        demoSection("级联选择器（Cascader）", [
            div([
                Cascader(regions, st.cascaderSelected).onChange { sel =>
                    let labels = cascaderPathLabels(regions, sel)
                    var t = "未选择"
                    var i = 0
                    for (l in labels) { if (i == 0) { t = l } else { t = "${t}/${l}" }; i += 1 }
                    st.cascaderText.set(t)
                    PatchResult.ReRender
                },
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                text("自定义分隔符（>）"),
                Cascader(regions, st.cascaderSelected).separator(" > ").onChange { sel =>
                    let labels = cascaderPathLabels(regions, sel)
                    var t = "未选择"
                    var i = 0
                    for (l in labels) { if (i == 0) { t = l } else { t = "${t} > ${l}" }; i += 1 }
                    st.cascaderText.set(t)
                    PatchResult.ReRender
                },
                text("末级显示"),
                Cascader(regions, st.cascaderSelected).showAllLevels(false),
                text("可清除"),
                Cascader(regions, st.cascaderSelected).clearable(),
                text("禁用"),
                Cascader(regions, st.cascaderSelected).disabled(true),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("已选择：${st.cascaderText.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("点输入框开面板；点父节点展开下一列；点叶子选中并关闭")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoUpload(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("上传（Upload）", [
            div([
                Upload().url("/_cjxt/uploads").files(st.uploadFiles),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("已上传 ${st.uploadFiles.get().size} 个文件")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("点上传区选文件 → 客户端 XHR 上传到 /_cjxt/uploads → 服务端存盘并回传 → 列表出现；点 × 删除")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

// ============ Props ============

public func propsTable(): IComponent {
    div([
        propRow("Table.data(signal)", "Signal<ArrayList<HashMap<String, String>>>", "表格数据源"),
        propRow("Table.add(TableColumn)", "Chain", "添加列配置"),
        propRow("stripe / border / highlight", "false", "斑马纹 / 边框 / 高亮当前行"),
        propRow("height / maxHeight", "String", "表格高度 / 最大高度"),
        propRow("size", "Large | Default | Small", "表格尺寸"),
        propRow("showSummary", "false", "是否在表尾显示汇总行"),
        propRow("Table.sortColumn(signal)", "Signal<String>", "当前排序列，外置信号可持久化"),
        propRow("Table.sortOrder(signal)", "Signal<SortOrder>", "当前排序方向，外置信号可持久化"),
        propRow("Table.selectedRows(signal)", "Signal<ArrayList<HashMap<String, String>>>", "选中的行集合，外置信号可持久化"),
        propRow("Table.currentRow(signal)", "Signal<Option<HashMap<String, String>>>", "当前高亮行，外置信号可持久化"),
        propRow("Table.rowClassName(fn)", "(HashMap<String,String>, Int64) -> String", "自定义行 class 回调"),
        propRow("Table.rowStyle(fn)", "(HashMap<String,String>, Int64) -> String", "自定义行 style 回调"),
        propRow("Table.cellClassName(fn)", "(HashMap<String,String>, TableColumn, Int64, Int64) -> String", "自定义单元格 class 回调"),
        propRow("Table.cellStyle(fn)", "(HashMap<String,String>, TableColumn, Int64, Int64) -> String", "自定义单元格 style 回调"),
        propRow("Table.headerCellClassName(fn)", "(TableColumn, Int64) -> String", "自定义表头 cell class 回调"),
        propRow("Table.headerRowStyle(fn)", "(Int64) -> String", "自定义表头行 style 回调"),
        propRow("Table.headerCellStyle(fn)", "(TableColumn, Int64) -> String", "自定义表头 cell style 回调"),
        propRow("Table.headerRowClassName(fn)", "(Int64) -> String", "自定义表头行 class 回调"),
        propRow("TableColumn.colProp", "String", "列对应数据字段名"),
        propRow("TableColumn.label", "String", "列标题"),
        propRow("TableColumn.width / minWidth", "Int64", "列宽 / 最小列宽"),
        propRow("TableColumn.fixed", "Left | Right", "固定列位置"),
        propRow("TableColumn.sortable", "false", "该列是否可排序"),
        propRow("TableColumn.align", "Left | Center | Right", "单元格对齐方式"),
        propRow("TableColumn.colType", "Default | Selection | Index", "列类型：默认 / 多选 / 序号"),
        propRow("TableColumn.showOverflowTooltip", "false", "内容溢出时显示 tooltip"),
        propRow("TableColumn.formatter", "(String) -> String", "单元格内容格式化函数"),
    ])
}

public func propsPagination(): IComponent {
    div([
        propRow("total", "Int64", "总条数"),
        propRow("pagerCount", "Int64", "页码按钮数量（奇数）"),
        propRow("layout", "String", "布局：prev,pager,next,total,sizes,jumper"),
        propRow("pageSizes", "Array<Int64>", "每页条数选项"),
        propRow("background / small", "Bool", "背景色 / 小尺寸"),
        propRow("disabled / hideOnSinglePage", "Bool", "禁用 / 单页时隐藏"),
        propRow("prevText / nextText", "String", "上/下一页文本"),
        propRow("currentPage / pageSize", "Signal<Int64>", "外置信号（跨渲染持久化）"),
        propRow("onCurrentChange / onSizeChange / onChange", "ActionHandler", "页码/条数/变更事件"),
    ])
}

public func propsDatePicker(): IComponent {
    div([
        propRow("bind(signal)", "Signal<String>", "值绑定（yyyy-MM-dd）"),
        propRow("placeholder", "String", "占位文本"),
        propRow("disabled", "Bool", "禁用状态"),
        propRow("clearable", "Bool", "可清除"),
        propRow("onChange", "ActionHandler", "选择变化事件"),
    ])
}

public func propsDateRangePicker(): IComponent {
    div([
        propRow("start / end", "Signal<String>", "起止值绑定"),
        propRow("startPlaceholder / endPlaceholder", "String", "起止占位文本"),
        propRow("disabled", "Bool", "禁用状态"),
        propRow("clearable", "Bool", "可清除"),
        propRow("onChange", "ActionHandler", "区间变化事件"),
    ])
}

public func propsTree(): IComponent {
    div([
        propRow("TreeNode(label, children, disabled)", "String·Array·Bool", "节点数据"),
        propRow("Tree.expanded", "Signal<HashMap<String, Bool>>", "展开状态外置"),
        propRow("Tree.currentKey", "Signal<String>", "选中节点外置"),
        propRow("onNodeClick(path, label)", "(String, String) -> Unit", "节点点击回调"),
    ])
}

public func propsCascader(): IComponent {
    div([
        propRow("CascaderNode(label, value, children)", "String·String·Array", "级联选项（children 可级联）"),
        propRow("Cascader(options, selected)", "Array·Signal<ArrayList<String>>", "选项 + 选中值外置"),
        propRow("placeholder", "String", "占位文本（默认 请选择）"),
        propRow("disabled", "Bool", "禁用状态"),
        propRow("clearable", "Bool", "可清除（选中后显示 ×）"),
        propRow("separator", "String", "路径分隔符（默认 ' / '）"),
        propRow("showAllLevels", "Bool", "显示全部层级（false 只显示末级）"),
        propRow("onChange", "(ArrayList<String>) -> Unit", "选择完成回调"),
    ])
}

public func propsUpload(): IComponent {
    div([
        propRow("url", "String", "上传端点（App.serveUpload 注册）"),
        propRow("files", "Signal<ArrayList<UploadFile>>", "文件列表外置信号"),
        propRow("onUploaded", "(UploadFile) -> Unit", "上传成功回调"),
    ])
}
