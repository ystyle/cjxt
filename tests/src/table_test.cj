package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// 泛型行类型（强类型领域对象模拟）
public struct PersonRow {
    let name: String
    let age: Int64
    let city: String

    public init(name: String, age: Int64, city: String) {
        this.name = name
        this.age = age
        this.city = city
    }
}

// 展开 Table 并序列化为 JSON 字符串（等价前端收到的树）
func renderTableJson<T>(table: Table<T>): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(table, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

func peopleData(): Signal<ArrayList<PersonRow>> {
    let list = ArrayList<PersonRow>()
    list.add(PersonRow("alice", 30, "bj"))
    list.add(PersonRow("bob", 25, "sh"))
    Signal<ArrayList<PersonRow>>(list)
}

func anyHandlerIdIn(map: HashMap<String, ActionHandler>, json: String): Bool {
    for ((id, _) in map) {
        if (json.contains(id)) { return true }
    }
    false
}

@Test
public class TableGenericRenderTest {
    @TestCase
    public func testAccessorTextColumn(): Unit {
        let table = Table<PersonRow>()
            .data(peopleData())
            .add(TableColumn<PersonRow>().label("姓名").accessor({ r => r.name }))
        let (json, _) = renderTableJson(table)
        @Expect(json.contains("alice"), true)
        @Expect(json.contains("bob"), true)
    }

    @TestCase
    public func testAccessorFormatterApplied(): Unit {
        let table = Table<PersonRow>()
            .data(peopleData())
            .add(TableColumn<PersonRow>().label("年龄").accessor({ r => r.age.toString() }).formatter({ v => "${v}岁" }))
        let (json, _) = renderTableJson(table)
        @Expect(json.contains("30岁"), true)
    }

    @TestCase
    public func testRenderCallbackInsertsComponent(): Unit {
        let table = Table<PersonRow>()
            .data(peopleData())
            .add(TableColumn<PersonRow>().label("城市").render({ r, i => Tag([text("城-${r.city}")]) }))
        let (json, _) = renderTableJson(table)
        @Expect(json.contains("城-bj"), true)
        @Expect(json.contains("城-sh"), true)
    }

    @TestCase
    public func testRenderPriorityOverAccessor(): Unit {
        let table = Table<PersonRow>()
            .data(peopleData())
            .add(TableColumn<PersonRow>()
                .label("城市")
                .accessor({ r => r.city })
                .render({ r, i => text("render-${r.city}") }))
        let (json, _) = renderTableJson(table)
        @Expect(json.contains("render-bj"), true)
        // accessor 原始值 "bj" 不应作为独立 JSON 字符串值出现（render 优先）
        @Expect(json.contains("\"bj\""), false)
    }

    @TestCase
    public func testOnRowClickBindsRowAction(): Unit {
        let table = Table<PersonRow>()
            .data(peopleData())
            .onRowClick({ r, i, ctx => PatchResult.ReRender })
        let (json, handlerMap) = renderTableJson(table)
        @Expect(json.contains("\"type\":\"tr\""), true)
        @Expect(json.contains("\"click\""), true)
        @Expect(anyHandlerIdIn(handlerMap, json), true)
    }

    @TestCase
    public func testNoOnRowClickKeepsRowUntouched(): Unit {
        let table = Table<PersonRow>()
            .data(peopleData())
        let (json, handlerMap) = renderTableJson(table)
        @Expect(handlerMap.size, 0)
    }

    @TestCase
    public func testRowKeySelectionRendersChecked(): Unit {
        let data = peopleData()
        let selected = Signal<ArrayList<PersonRow>>(ArrayList<PersonRow>())
        selected.get().add(PersonRow("alice", 30, "bj"))
        let table = Table<PersonRow>()
            .data(data)
            .rowKey({ r => r.name })
            .selectedRows(selected)
            .add(TableColumn<PersonRow>().colType(TableColumnType.Selection).width(50))
            .add(TableColumn<PersonRow>().label("姓名").accessor({ r => r.name }))
        let (json, _) = renderTableJson(table)
        // alice 行选中（checkbox is-checked），bob 行未选
        @Expect(json.contains("is-checked"), true)
    }

    @TestCase
    public func testTableWidthMaxOfTotalAndFull(): Unit {
        let table = Table<PersonRow>()
            .data(peopleData())
            .add(TableColumn<PersonRow>().label("姓名").accessor({ r => r.name }).width(200))
        let (json, _) = renderTableJson(table)
        // 内层表格宽度 = max(列宽总和, 100%)，列宽不足时铺满容器
        @Expect(json.contains("width: max(200px, 100%)"), true)
    }

    @TestCase
    public func testTableCellNowrap(): Unit {
        let table = Table<PersonRow>()
            .data(peopleData())
            .add(TableColumn<PersonRow>().label("姓名").accessor({ r => r.name }))
        let (json, _) = renderTableJson(table)
        // 单元格单行（防止窄列长文本换行成竖排）
        @Expect(json.contains("white-space: nowrap"), true)
    }
}

@Test
public class SortByAccessorTest {
    @TestCase
    public func testAscendingSort(): Unit {
        let list = ArrayList<PersonRow>()
        list.add(PersonRow("b", 2, "x"))
        list.add(PersonRow("a", 1, "y"))
        list.add(PersonRow("c", 3, "z"))
        let sorted = sortByAccessor<PersonRow>(list, { r => r.name }, SortOrder.Ascending)
        @Expect(sorted[0].name, "a")
        @Expect(sorted[1].name, "b")
        @Expect(sorted[2].name, "c")
    }

    @TestCase
    public func testDescendingSort(): Unit {
        let list = ArrayList<PersonRow>()
        list.add(PersonRow("b", 2, "x"))
        list.add(PersonRow("a", 1, "y"))
        let sorted = sortByAccessor<PersonRow>(list, { r => r.name }, SortOrder.Descending)
        @Expect(sorted[0].name, "b")
        @Expect(sorted[1].name, "a")
    }

    @TestCase
    public func testNoneOrderKeepsOriginal(): Unit {
        let list = ArrayList<PersonRow>()
        list.add(PersonRow("b", 2, "x"))
        list.add(PersonRow("a", 1, "y"))
        let sorted = sortByAccessor<PersonRow>(list, { r => r.name }, SortOrder.None)
        @Expect(sorted[0].name, "b")
        @Expect(sorted[1].name, "a")
    }
}
