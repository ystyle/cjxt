package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

func renderTimePickerJson(tp: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(tp, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

func countOccurrences(s: String, sub: String): Int64 {
    var count = 0
    var idx = 0
    var searching = true
    while (searching) {
        match (s.indexOf(sub, idx)) {
            case Some(pos) =>
                count += 1
                idx = pos + 1
            case None =>
                searching = false
        }
    }
    count
}

@Test
public class TimePickerTest {
    @TestCase
    public func testPanelStructure(): Unit {
        let vis = Signal<String>("09:30:45")
        let tp = TimePicker().bind(vis)
        let (json, handlers) = renderTimePickerJson(tp)
        @Expect(json.contains("el-time-panel"), true)
        @Expect(json.contains("el-time-panel__content has-seconds"), true)
        @Expect(json.contains("el-time-spinner has-seconds"), true)
        @Expect(json.contains("el-time-spinner__wrapper"), true)
        @Expect(json.contains("el-time-spinner__list"), true)
        @Expect(json.contains("el-picker__popper el-popper"), true)
        @Expect(json.contains("el-time-panel__btn cancel"), true)
        @Expect(json.contains("el-time-panel__btn confirm"), true)
        // 144 个 li（时 24 + 分 60 + 秒 60）+ 取消 + 确定
        @Expect(handlers.size >= 146, true)
    }

    @TestCase
    public func testActiveItemsMatchValue(): Unit {
        let vis = Signal<String>("09:30:45")
        let tp = TimePicker().bind(vis)
        let (json, _) = renderTimePickerJson(tp)
        @Expect(countOccurrences(json, "el-time-spinner__item is-active"), 3)
        // 输入框 readonly 且显示当前值
        @Expect(json.contains("\"readonly\":\"true\""), true)
        @Expect(json.contains("09:30:45"), true)
    }

    @TestCase
    public func testDefaultPlaceholder(): Unit {
        let vis = Signal<String>("")
        let tp = TimePicker().bind(vis)
        let (json, _) = renderTimePickerJson(tp)
        @Expect(json.contains("HH:mm:ss"), true)
    }
}
