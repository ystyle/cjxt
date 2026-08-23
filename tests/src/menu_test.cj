package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class MenuDarkTest {
    @TestCase
    public func testDarkMenuSetsCssVariables(): Unit {
        let menu = Menu()
            .dark()
            .add(MenuItem("/a", [text("A")]).active(true))
        let expanded = RenderContext.expandTree(menu, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let json = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        @Expect(json.contains("--el-menu-bg-color"), true)
        @Expect(json.contains("--el-menu-text-color"), true)
        @Expect(json.contains("#1d2b3a"), true)
    }

    @TestCase
    public func testPlainMenuNoDarkStyle(): Unit {
        let menu = Menu().add(MenuItem("/a", [text("A")]))
        let expanded = RenderContext.expandTree(menu, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let json = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        @Expect(json.contains("--el-menu-bg-color"), false)
    }

    @TestCase
    public func testMenuItemHasLeftPadding(): Unit {
        // EP vertical 菜单 calc() 依赖 --el-menu-level（服务端未设置 → padding 归零）
        // MenuItem 内联兜底：level=0 + 左右 20px 内边距
        let menu = Menu().add(MenuItem("/a", [text("A")]))
        let expanded = RenderContext.expandTree(menu, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let json = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        @Expect(json.contains("--el-menu-level: 0"), true)
        @Expect(json.contains("padding-left: 20px"), true)
    }
}
