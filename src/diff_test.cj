package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class DiffTest {
    func makeDiv(extraAttrs: HashMap<String, String>): ComponentNode {
        div([text("hello")], extraAttrs, None, HashMap<String, String>())
    }

    func baseDiv(): ComponentNode {
        let attrs = HashMap<String, String>()
        attrs["class"] = "box"
        div([text("hello")], attrs, None, HashMap<String, String>())
    }

    @TestCase
    public func testSameTreeNoPatches(): Unit {
        let a = baseDiv()
        let patches = diffTree(a, a, "")
        @Expect(patches.size, 0)
    }

    @TestCase
    public func testDifferentTypeReplace(): Unit {
        let old = baseDiv()
        let newTree = span([text("hello")], HashMap<String, String>(), None, HashMap<String, String>())
        let patches = diffTree(old, newTree, "")
        @Expect(patches.size > 0, true)
        @Expect(patches[0].op, "replace")
    }

    @TestCase
    public func testAttrChanged(): Unit {
        let old = baseDiv()
        let attrs = HashMap<String, String>()
        attrs["class"] = "big-box"
        let newTree = div([text("hello")], attrs, None, HashMap<String, String>())
        let patches = diffTree(old, newTree, "")
        @Expect(patches.size, 1)
        @Expect(patches[0].op, "replace")
    }

    @TestCase
    public func testChildAdded(): Unit {
        let attrs = HashMap<String, String>()
        attrs["class"] = "box"
        let old = div([text("hello")], attrs, None, HashMap<String, String>())
        let newTree = div([
            text("hello"),
            text("world")
        ], attrs, None, HashMap<String, String>())
        let patches = diffTree(old, newTree, "")
        @Expect(patches.size, 1)
        @Expect(patches[0].op, "add")
    }
}
