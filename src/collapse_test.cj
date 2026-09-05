package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

func assertNames(actual: ArrayList<String>, expected: Array<String>, label: String): Unit {
    if (actual.size != expected.size) {
        @Fail("${label}: size mismatch actual=${actual.size} expected=${expected.size}")
        return
    }
    for (i in 0..actual.size) {
        if (actual[i] != expected[i]) {
            @Fail("${label}: elem ${i} actual=${actual[i]} expected=${expected[i]}")
            return
        }
    }
    @Expect(true, true)
}

@Test
public class CollapseLogicTest {
    @TestCase
    public func testMultiToggleAdd(): Unit {
        var names = ArrayList<String>()
        names = collapseToggleActive(names, "a", false)
        assertNames(names, ["a"], "add-a")
        names = collapseToggleActive(names, "b", false)
        assertNames(names, ["a", "b"], "add-b")
    }

    @TestCase
    public func testMultiToggleRemove(): Unit {
        var names = ArrayList<String>(["a", "b", "c"])
        names = collapseToggleActive(names, "b", false)
        assertNames(names, ["a", "c"], "remove-b")
        names = collapseToggleActive(names, "a", false)
        assertNames(names, ["c"], "remove-a")
    }

    @TestCase
    public func testMultiToggleNone(): Unit {
        let names = ArrayList<String>()
        assertNames(collapseToggleActive(names, "x", false), ["x"], "add-x")
    }

    @TestCase
    public func testAccordionSwitch(): Unit {
        var names = ArrayList<String>(["a"])
        names = collapseToggleActive(names, "b", true)
        assertNames(names, ["b"], "switch-ab")
        names = collapseToggleActive(names, "a", true)
        assertNames(names, ["a"], "switch-ba")
    }

    @TestCase
    public func testAccordionCloseCurrent(): Unit {
        var names = ArrayList<String>(["a"])
        names = collapseToggleActive(names, "a", true)
        assertNames(names, [], "close-a")
    }

    @TestCase
    public func testAccordionOpenFromEmpty(): Unit {
        var names = ArrayList<String>()
        names = collapseToggleActive(names, "a", true)
        assertNames(names, ["a"], "open-a")
    }

    @TestCase
    public func testIsActive(): Unit {
        let names = ArrayList<String>(["a", "c"])
        @Expect(collapseIsActive(names, "a"), true)
        @Expect(collapseIsActive(names, "b"), false)
        let empty = ArrayList<String>()
        @Expect(collapseIsActive(empty, "a"), false)
    }
}
