package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Scrollbar 测试。
// 对齐点：EP scrollbar.vue 的 DOM 结构 el-scrollbar > __wrap > __view；
// native=false 时 wrap 追加 __wrap--hidden-default（隐藏原生滚动条）。
@Test
public class ScrollbarTest {
    // 子串出现次数（String.indexOf 返回 Option<Int64>，需循环从命中位置之后继续）
    func countOccurrences(hay: String, needle: String): Int64 {
        var n = 0
        var from: Int64 = 0
        var searching = true
        while (searching) {
            match (hay.indexOf(needle, from)) {
                case Some(i) =>
                    n = n + 1
                    from = i + needle.size
                case None => searching = false
            }
        }
        n
    }

    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    @TestCase
    public func testStructure(): Unit {
        // EP：div.el-scrollbar > div.el-scrollbar__wrap > div.el-scrollbar__view
        let out = this.json(Scrollbar([text("hello")]))
        @Expect(out.contains("el-scrollbar"), true)
        @Expect(out.contains("el-scrollbar__wrap"), true)
        @Expect(out.contains("el-scrollbar__view"), true)
        @Expect(out.contains("hello"), true)
    }

    @TestCase
    public func testNativeByDefaultKeepsBrowserScrollbar(): Unit {
        // 默认 native=true：不加 hidden-default，浏览器原生滚动条可见
        let out = this.json(Scrollbar([text("x")]))
        @Expect(out.contains("hidden-default"), false)
    }

    @TestCase
    public func testNonNativeHidesBrowserScrollbar(): Unit {
        // native=false 时按 EP 加 hidden-default
        let out = this.json(Scrollbar([text("x")]).native(false))
        @Expect(out.contains("el-scrollbar__wrap--hidden-default"), true)
    }

    @TestCase
    public func testHeightAndMaxHeight(): Unit {
        let out = this.json(Scrollbar([text("x")]).height("200px").maxHeight("400px"))
        @Expect(out.contains("height:200px"), true)
        @Expect(out.contains("max-height:400px"), true)
    }

    @TestCase
    public func testWrapAndViewClass(): Unit {
        let out = this.json(Scrollbar([text("x")]).wrapClass("mywrap").viewClass("myview"))
        @Expect(out.contains("mywrap"), true)
        @Expect(out.contains("myview"), true)
    }

    @TestCase
    public func testEmptySizeWritesNoStyle(): Unit {
        // 不设尺寸时不应产生空 style 属性
        let out = this.json(Scrollbar([text("x")]))
        @Expect(out.contains("\"style\":\"\""), false)
    }

    // ── 自定义 bar/thumb（2026-10-23 新增，方案 B）────────────────────
    // 服务端只出结构骨架（尺寸留空、display:none），真实几何由前端 attachScrollbar 计算
    // （scrollHeight/clientHeight 只有浏览器知道）。

    @TestCase
    public func testNativeModeRendersNoCustomBar(): Unit {
        // native=true：用浏览器原生滚动条，不出自定义 bar（EP 语义）
        let out = this.json(Scrollbar([text("x")]))
        @Expect(out.contains("el-scrollbar__bar"), false)
        @Expect(out.contains("data-scrollbar"), false)
    }

    @TestCase
    public func testNonNativeRendersBothBars(): Unit {
        // native=false：竖向 + 横向两条 bar 骨架
        let out = this.json(Scrollbar([text("x")]).native(false))
        @Expect(out.contains("el-scrollbar__bar is-vertical"), true)
        @Expect(out.contains("el-scrollbar__bar is-horizontal"), true)
        @Expect(out.contains("el-scrollbar__thumb"), true)
        @Expect(out.contains("data-scrollbar"), true)
    }

    @TestCase
    public func testThumbHasNoServerSideGeometry(): Unit {
        // 服务端不预置 thumb 尺寸（避免按猜测值渲染出假尺寸闪烁），初始 display:none
        let out = this.json(Scrollbar([text("x")]).native(false))
        @Expect(out.contains("display:none"), true)
        // 不应出现服务端算的 width/height 数值
        @Expect(out.contains("translateY"), false)
        @Expect(out.contains("translateX"), false)
    }

    @TestCase
    public func testWrapAttrPassthrough(): Unit {
        // wrapAttr 把属性透传到 wrap（TimePicker 用 data-scroll-active 让 patch 后滚到选中项）
        let out = this.json(Scrollbar([text("x")]).native(false)
            .wrapClass("el-time-spinner__wrapper")
            .wrapAttr("data-scroll-active", "true"))
        @Expect(out.contains("el-time-spinner__wrapper"), true)
        @Expect(out.contains("data-scroll-active"), true)
    }

    @TestCase
    public func testViewClassStillApplied(): Unit {
        let out = this.json(Scrollbar([text("x")]).native(false).viewClass("el-time-spinner__content"))
        @Expect(out.contains("el-time-spinner__content"), true)
        @Expect(out.contains("el-scrollbar__view"), true)
    }

    // ── maxHeight 模式（2026-10-23 修）──────────────────────────────
    // 原始缺陷：max-height 只写在根元素上，而 wrap 是 height:100% ——
    // 百分比高度需要父元素有**确定高度**，只有 max-height 时无法解析，
    // wrap 会撑到内容高度 → 既不出现滚动条、bar 也不显示（演示里表现为「空壳、无法操作」）。
    // 修法：maxHeight 模式下把同一约束也加到 wrap 的 style 上。

    @TestCase
    public func testMaxHeightAlsoConstrainsWrap(): Unit {
        let out = this.json(Scrollbar([text("x")]).native(false).maxHeight("120px"))
        // 根元素与 wrap 都应带上 max-height
        let occurrences = countOccurrences(out, "max-height:120px")
        @Expect(occurrences >= 2, true)
    }

    @TestCase
    public func testHeightModeDoesNotDuplicateOnWrap(): Unit {
        // height 模式：根元素有确定高度，wrap 的 height:100% 已生效，不必重复加
        let out = this.json(Scrollbar([text("x")]).native(false).height("180px"))
        @Expect(countOccurrences(out, "max-height"), 0)
        @Expect(out.contains("height:180px"), true)
    }

    @TestCase
    public func testMaxHeightIgnoredWhenHeightSet(): Unit {
        // 同时给 height 与 maxHeight 时，以 height 为主（不往 wrap 重复加 max-height）
        let out = this.json(Scrollbar([text("x")]).native(false).height("180px").maxHeight("120px"))
        @Expect(countOccurrences(out, "max-height:120px"), 1)
    }
}
