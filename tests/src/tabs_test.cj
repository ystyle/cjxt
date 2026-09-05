package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

func renderTabsJson(t: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(t, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

@Test
public class TabsActiveBarTest {
    @TestCase
    public func testLineHasActiveBar(): Unit {
        let t = Tabs([
            TabPane([text("A 内容")], "a", "A"),
            TabPane([text("B 内容")], "b", "B"),
        ]).bind(Signal<String>("a"))
        let (json, _) = renderTabsJson(t)
        @Expect(json.contains("el-tabs__active-bar"), true)
        @Expect(json.contains("data-tabs-bar"), true)
    }

    @TestCase
    public func testCardNoActiveBar(): Unit {
        let t = Tabs([
            TabPane([text("A 内容")], "a", "A"),
        ]).tabType("card")
        let (json, _) = renderTabsJson(t)
        @Expect(json.contains("el-tabs__active-bar"), false)
    }

    @TestCase
    public func testVerticalIsLeftClass(): Unit {
        let t = Tabs([
            TabPane([text("A 内容")], "a", "A"),
        ]).position("left")
        let (json, _) = renderTabsJson(t)
        @Expect(json.contains("el-tabs__active-bar is-left"), true)
    }
}
