package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

func attrsOf(cls: String): Attributes {
    let a = HashMap<String, String>()
    a["class"] = cls
    a
}

@Test
public class DiffTest {
    @TestCase
    public func testSameTreeNoPatches(): Unit {
        let a = div([text("hello")], attrs: attrsOf("box"))
        let patches = diffTree(a, a, "")
        @Expect(patches.size, 0)
    }

    @TestCase
    public func testDifferentTypeReplace(): Unit {
        let old = div([text("hello")], attrs: attrsOf("box"))
        let newTree = span([text("hello")])
        let patches = diffTree(old, newTree, "")
        @Expect(patches.size > 0, true)
        @Expect(patches[0].op(), "replace")
    }

    @TestCase
    public func testAttrChanged(): Unit {
        let old = div([text("hello")], attrs: attrsOf("box"))
        let newTree = div([text("hello")], attrs: attrsOf("big-box"))
        let patches = diffTree(old, newTree, "")
        @Expect(patches.size, 1)
        @Expect(patches[0].op(), "replace")
    }

    @TestCase
    public func testChildAdded(): Unit {
        let old = div([text("hello")], attrs: attrsOf("box"))
        let newTree = div([text("hello"), text("world")], attrs: attrsOf("box"))
        let patches = diffTree(old, newTree, "")
        @Expect(patches.size, 1)
        @Expect(patches[0].op(), "add")
    }

    @TestCase
    public func testDiffActionsChanged(): Unit {
        let a1 = HashMap<String, String>()
        a1["click"] = "h1"
        let a2 = HashMap<String, String>()
        a2["click"] = "h999"
        let old = div([text("test")], actions: Some(a1))
        let newTree = div([text("test")], actions: Some(a2))
        let patches = diffTree(old, newTree, "")
        @Expect(patches.size, 1)
        @Expect(patches[0].op(), "replace")
    }

    @TestCase
    public func testActionsDiffedAlongsideAttrs(): Unit {
        let a1 = HashMap<String, String>()
        a1["click"] = "h1"
        let a2 = HashMap<String, String>()
        a2["click"] = "h999"
        let old = div([text("hello")], attrs: attrsOf("box"), actions: Some(a1))
        let newTree = div([text("hello")], attrs: attrsOf("big-box"), actions: Some(a2))
        let patches = diffTree(old, newTree, "")
        @Expect(patches.size, 2)
    }
}
