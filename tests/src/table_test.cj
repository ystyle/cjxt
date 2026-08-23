package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// 展开 Table 并序列化为 JSON 字符串（等价前端收到的树）
func renderTableJson(table: Table): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(table, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

func makeData(vals: Array<HashMap<String, String>>): Signal<ArrayList<HashMap<String, String>>> {
    let list = ArrayList<HashMap<String, String>>()
    for (m in vals) { list.add(m) }
    Signal<ArrayList<HashMap<String, String>>>(list)
}

func oneRow(): HashMap<String, String> {
    let row = HashMap<String, String>()
    row["name"] = "foobar"
    row["status"] = "ok"
    row
}

func anyHandlerIdIn(map: HashMap<String, ActionHandler>, json: String): Bool {
    for ((id, _) in map) {
        if (json.contains(id)) { return true }
    }
    false
}

@Test
public class TableRenderTest {
    @TestCase
    public func testColumnRenderInsertsComponent(): Unit {
        let data = makeData([oneRow()])
        let table = Table()
            .data(data)
            .add(TableColumn().label("名称").colProp("name").render({ r, i =>
                Tag([text("自定义-${r["name"]}")])
            }))
        let (json, _) = renderTableJson(table)
        @Expect(json.contains("自定义-foobar"), true)
    }

    @TestCase
    public func testColumnRenderPriorityOverFormatter(): Unit {
        let data = makeData([oneRow()])
        let table = Table()
            .data(data)
            .add(TableColumn()
                .label("名称")
                .colProp("name")
                .formatter({ v => "fmt-${v}" })
                .render({ r, i => text("render-${r["name"]}") }))
        let (json, _) = renderTableJson(table)
        @Expect(json.contains("render-foobar"), true)
        @Expect(json.contains("fmt-foobar"), false)
    }

    @TestCase
    public func testOnRowClickBindsRowAction(): Unit {
        let data = makeData([oneRow()])
        let table = Table()
            .data(data)
            .onRowClick({ r, i => PatchResult.ReRender })
        let (json, handlerMap) = renderTableJson(table)
        @Expect(json.contains("\"type\":\"tr\""), true)
        @Expect(json.contains("\"click\""), true)
        @Expect(anyHandlerIdIn(handlerMap, json), true)
    }

    @TestCase
    public func testNoOnRowClickKeepsRowUntouched(): Unit {
        let data = makeData([oneRow()])
        let table = Table()
            .data(data)
        let (json, handlerMap) = renderTableJson(table)
        @Expect(handlerMap.size, 0)
    }
}
