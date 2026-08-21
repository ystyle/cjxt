package cjxt

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class TabLogicTest {
    func names(): ArrayList<String> {
        let n = ArrayList<String>()
        n.add("a")
        n.add("b")
        n.add("c")
        n
    }

    @TestCase
    public func testResolveActiveEmpty(): Unit {
        @Expect(resolveActiveTab("", this.names()), "a")
    }

    @TestCase
    public func testResolveActiveFound(): Unit {
        @Expect(resolveActiveTab("b", this.names()), "b")
        @Expect(resolveActiveTab("c", this.names()), "c")
    }

    @TestCase
    public func testResolveActiveFallback(): Unit {
        @Expect(resolveActiveTab("z", this.names()), "a")
    }

    @TestCase
    public func testResolveActiveEmptyPanes(): Unit {
        @Expect(resolveActiveTab("a", ArrayList<String>()), "")
        @Expect(resolveActiveTab("", ArrayList<String>()), "")
    }
}
