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
}
