package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

func renderCalendarJson(ca: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(ca, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

@Test
public class CalendarTest {
    @TestCase
    public func testCalendarStructure(): Unit {
        let ca = Calendar()
        let (json, handlers) = renderCalendarJson(ca)
        @Expect(json.contains("el-calendar"), true)
        @Expect(json.contains("el-calendar__header"), true)
        @Expect(json.contains("el-calendar__title"), true)
        @Expect(json.contains("el-calendar__button-group"), true)
        @Expect(json.contains("el-calendar-table"), true)
        @Expect(json.contains("el-calendar-day"), true)
        // 42 格（6 行 x 7 列）+ 7 个表头
        @Expect(handlers.size >= 45, true) // 42 td + 3 导航
    }

    @TestCase
    public func testViewDateTitleAndSelected(): Unit {
        let vis = Signal<String>("2026-08-01")
        let val = Signal<String>("2026-08-15")
        let ca = Calendar().viewDate(vis).bind(val)
        let (json, _) = renderCalendarJson(ca)
        @Expect(json.contains("2026 年 8 月"), true)
        @Expect(json.contains("is-selected"), true)
    }

    @TestCase
    public func testFirstDayOfWeekMonday(): Unit {
        let vis = Signal<String>("2026-08-01")
        let ca = Calendar().viewDate(vis).firstDayOfWeek(1)
        let (json, _) = renderCalendarJson(ca)
        // 周一起始：表头第一个是"一"（文本节点 "一" 在 "日" 之前）
        let i1 = json.indexOf("\"text\":\"一\"")
        let i2 = json.indexOf("\"text\":\"日\"")
        match (i1) {
            case Some(a) =>
                match (i2) {
                    case Some(b) => @Expect(a < b, true)
                    case None => @Fail("no 日 header")
                }
            case None => @Fail("no 一 header")
        }
    }

    @TestCase
    public func testNavButtonsActions(): Unit {
        let vis = Signal<String>("2026-08-01")
        let ca = Calendar().viewDate(vis)
        let (json, handlers) = renderCalendarJson(ca)
        @Expect(json.contains("上月"), true)
        @Expect(json.contains("今天"), true)
        @Expect(json.contains("下月"), true)
        @Expect(handlers.size, 45)
    }
}
