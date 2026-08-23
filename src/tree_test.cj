package cjxt

import std.collection.HashMap
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class TreeLogicTest {
    @TestCase
    public func testToggle(): Unit {
        let empty = HashMap<String, Bool>()
        let e1 = treeToggle(empty, "0")
        @Expect(treeIsExpanded(e1, "0"), true)
        @Expect(treeIsExpanded(e1, "1"), false)
        let e2 = treeToggle(e1, "0")
        @Expect(treeIsExpanded(e2, "0"), false)
        // 原 map 不变（返回副本）
        @Expect(treeIsExpanded(empty, "0"), false)
    }

    @TestCase
    public func testChildPath(): Unit {
        @Expect(treeChildPath("", 0), "0")
        @Expect(treeChildPath("", 2), "2")
        @Expect(treeChildPath("0", 1), "0/1")
        @Expect(treeChildPath("0/1", 3), "0/1/3")
    }
}
