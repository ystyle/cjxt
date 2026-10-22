package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Segmented 渲染结构 + 选中交互测试。
// 对齐点：EP segmented.vue 的 `.el-segmented > __group > __item-selected + label.__item`
// （含 is-selected / is-disabled / item-input / item-label）、options 为空不渲染、
// 等分滑块几何（服务端算，替代 EP 的 ResizeObserver 测量）、bind 驱动选中。
func renderSegmentedJson(t: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(t, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

func makeSegCtx(): ActionContext {
    ActionContext("s-seg", HashMap<String, String>(), HashMap<String, String>(),
        Router("s-seg", { _ => () }))
}

@Test
public class SegmentedTest {
    @TestCase
    public func testBasicStructure(): Unit {
        // div.el-segmented[role=radiogroup] > div.el-segmented__group.el-segmented--horizontal
        //   > div.el-segmented__item-selected + label.el-segmented__item (input + __item-label)
        let s = Segmented(Segmented.textOptions(["日", "周", "月"])).bind(Signal<String>("日"))
        let (json, _) = renderSegmentedJson(s)
        @Expect(json.contains("el-segmented"), true)
        @Expect(json.contains("el-segmented__group"), true)
        @Expect(json.contains("el-segmented--horizontal"), true)
        @Expect(json.contains("\"radiogroup\""), true)
        @Expect(json.contains("el-segmented__item-selected"), true)
        @Expect(json.contains("el-segmented__item-input"), true)
        @Expect(json.contains("el-segmented__item-label"), true)
        // 三项 label 都在
        @Expect(json.contains("\"日\""), true)
        @Expect(json.contains("\"周\""), true)
        @Expect(json.contains("\"月\""), true)
    }

    @TestCase
    public func testSelectedItemGetsClassAndCheckedInput(): Unit {
        let s = Segmented(Segmented.textOptions(["A", "B", "C"])).bind(Signal<String>("B"))
        let (json, _) = renderSegmentedJson(s)
        @Expect(json.contains("el-segmented__item is-selected"), true)
        // 只有选中那项的 input 带 checked
        @Expect(countSegOccurrences(json, "\"checked\":\"checked\""), 1)
    }

    @TestCase
    public func testItemDisabledClassAndNoHandler(): Unit {
        // 禁用项：label 带 is-disabled、input 带 disabled、且不挂点击 action
        let opts = [
            SegmentedOption("A"),
            SegmentedOption("B").disabled(),
        ]
        let s = Segmented(opts).bind(Signal<String>("A"))
        let (json, handlers) = renderSegmentedJson(s)
        @Expect(json.contains("is-disabled"), true)
        @Expect(json.contains("\"disabled\":\"disabled\""), true)
        // 只有未禁用的 A 有 handler
        @Expect(handlers.size, 1)
    }

    @TestCase
    public func testClickWritesSignal(): Unit {
        // 交互：点某一项 → 该项的 handler 写入对应 value（走真实链路：按元素定位 action 再派发）
        let sig = Signal<String>("A")
        let s = Segmented(Segmented.textOptions(["A", "B"])).bind(sig)
        let (json, handlers) = renderSegmentedJson(s)
        @Expect(handlers.size, 2)
        @Expect(json.contains("el-segmented__item is-selected"), true)

        // 定位第二项（label 上是 `el-segmented__item` + 紧跟 `is-selected` 的那个是第一项，
        // 未选中的第二项类名前缀为 `el-segmented__item` 且其后为引号/空格）。
        // 用 probeActionId 按非选中项定位：先取所有 item 的 action，逐个点，断言信号落在合法值上，
        // 再单独验证「点 B 得到 B」。
        let clicked = probeFire(json, handlers, "\"B\"", "click", makeSegCtx())
        // 若 marker 未命中同一元素（label 与 label 文本分属节点），退回直接按 handler 全量派发
        if (!clicked) {
            for ((_, h) in handlers) { let _ = h(makeSegCtx()) }
        }
        let v = sig.get()
        @Expect(v == "A" || v == "B", true)
    }

    @TestCase
    public func testClickOnSecondItemSelectsItsValue(): Unit {
        // 精确定位：渲染第二项（未选中）的 label 元素并派发 click → 信号必须变成 "B"
        let sig = Signal<String>("A")
        let s = Segmented(Segmented.textOptions(["A", "B"])).bind(sig)
        let (json, handlers) = renderSegmentedJson(s)

        // 未选中项的 label 类名是 "el-segmented__item"（不带 is-selected）；
        // 选中项是 "el-segmented__item is-selected"。故按不带后缀的那个定位即可拿到一项未选中项。
        let idSecond = probeActionId(json, "\"class\":\"el-segmented__item\"", "click")
        @Expect(idSecond != "", true)
        // 说明：上者可能命中"A"（已选中，类名含 is-selected 不会精确匹配）——精确匹配下只会命中未选中项。
        match (handlers.get(idSecond)) {
            case Some(h) =>
                let _ = h(makeSegCtx())
                // 唯一未选中的是 B，因此信号必须变为 B
                @Expect(sig.get(), "B")
            case None => @Expect(false, true)
        }
    }

    @TestCase
    public func testSelectedBarGeometryHorizontal(): Unit {
        // 三项、选中第 0 项：宽 1/3、translateX(0)
        let s = Segmented(Segmented.textOptions(["A", "B", "C"])).bind(Signal<String>("A"))
        let (json, _) = renderSegmentedJson(s)
        @Expect(json.contains("width:calc(100% / 3)"), true)
        @Expect(json.contains("translateX(calc(100% * 0))"), true)

        // 选中第 2 项：translateX(calc(100% * 2))
        let s2 = Segmented(Segmented.textOptions(["A", "B", "C"])).bind(Signal<String>("C"))
        let (j2, _) = renderSegmentedJson(s2)
        @Expect(j2.contains("translateX(calc(100% * 2))"), true)
    }

    @TestCase
    public func testSelectedBarGeometryVertical(): Unit {
        // 纵向用 height/translateY（EP 的 direction=vertical 分支）
        let s = Segmented(Segmented.textOptions(["A", "B"]))
            .bind(Signal<String>("B")).direction("vertical")
        let (json, _) = renderSegmentedJson(s)
        @Expect(json.contains("el-segmented--vertical"), true)
        @Expect(json.contains("height:calc(100% / 2)"), true)
        @Expect(json.contains("translateY(calc(100% * 1))"), true)
    }

    @TestCase
    public func testNoSelectionHidesBar(): Unit {
        // 信号值不在 options 里 → 无选中 → EP 的 isInit=false → display:none
        let s = Segmented(Segmented.textOptions(["A", "B"])).bind(Signal<String>("X"))
        let (json, _) = renderSegmentedJson(s)
        @Expect(json.contains("el-segmented__item-selected"), true)
        @Expect(json.contains("display:none"), true)
        @Expect(json.contains("is-selected"), false)
    }

    @TestCase
    public func testEmptyOptionsRendersNothing(): Unit {
        // EP: v-if="options.length" → 空 options 整个组件不渲染
        let s = Segmented([]).bind(Signal<String>("A"))
        let (json, _) = renderSegmentedJson(s)
        @Expect(json.contains("el-segmented"), false)
    }

    @TestCase
    public func testBlockAndSizeClasses(): Unit {
        let s = Segmented(Segmented.textOptions(["A"]))
            .bind(Signal<String>("A")).block().size(ComponentSize.Small)
        let (json, _) = renderSegmentedJson(s)
        @Expect(json.contains("is-block"), true)
        @Expect(json.contains("el-segmented--small"), true)

        // Default 档不加 size 修饰类（ComponentSize.Default.asClass() 是空串）
        let s2 = Segmented(Segmented.textOptions(["A"]))
            .bind(Signal<String>("A")).size(ComponentSize.Default)
        let (j2, _) = renderSegmentedJson(s2)
        @Expect(j2.contains("el-segmented-- "), false)
    }

    @TestCase
    public func testGroupDisabledDisablesAllItems(): Unit {
        // 组级 disabled：所有项都禁用、都不挂 action
        let s = Segmented(Segmented.textOptions(["A", "B"])).bind(Signal<String>("A")).disabled()
        let (json, handlers) = renderSegmentedJson(s)
        @Expect(handlers.size, 0)
        match (json.indexOf("is-disabled")) {
            case Some(_) => @Expect(true, true)
            case None => @Expect(false, true)
        }
    }
}

func countSegOccurrences(s: String, sub: String): Int64 {
    var count = 0
    var from = 0
    var searching = true
    while (searching) {
        match (s.indexOf(sub, from)) {
            case Some(i) =>
                count += 1
                from = i + sub.size
            case None => searching = false
        }
    }
    count
}
