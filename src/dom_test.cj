package cjxt

import std.collection.HashMap
import std.convert.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class DomLogicTest {
    @TestCase
    public func testNextDomTxIdMonotonic(): Unit {
        let a = nextDomTxId()
        let b = nextDomTxId()
        @Expect(a.startsWith("dom_"), true)
        @Expect(b != a, true)
    }

    @TestCase
    public func testReadResults(): Unit {
        let r = readResults("{\"type\":\"dom_result\",\"txId\":\"dom_1\",\"results\":{\"r1\":\"42\",\"r2\":\"abc\"}}")
        match (r.get("r1")) {
            case Some(v) => @Expect(v, "42")
            case None => @Expect(false, true)
        }
        match (r.get("r2")) {
            case Some(v) => @Expect(v, "abc")
            case None => @Expect(false, true)
        }
    }

    @TestCase
    public func testReadResultsEmpty(): Unit {
        let r = readResults("{\"type\":\"dom_result\",\"txId\":\"dom_1\"}")
        @Expect(r.size, 0)
    }

    @TestCase
    public func testDomCommandBuilders(): Unit {
        let f = domFocus("panel")
        @Expect(f.cmd, "focus")
        @Expect(f.refName, "panel")
        @Expect(f.path, "")
        let s = domScrollIntoView("list", "smooth")
        @Expect(s.cmd, "scrollIntoView")
        @Expect(s.value, "smooth")
        let sp = domSetProperty("status", "innerText", "hi")
        @Expect(sp.property, "innerText")
        @Expect(sp.value, "hi")
        let g = domGetProperty("widget", "offsetHeight", "k")
        @Expect(g.cmd, "getProperty")
        @Expect(g.resultKey, "k")
        // resolved()：带路径副本
        let r = g.resolved("children/0")
        @Expect(r.path, "children/0")
        @Expect(r.refName, "widget")
    }
}

@Test
public class DomParseResultTest {
    @TestCase
    public func testParseInt64Direct(): Unit {
        // 数值 DOM 值走直接 parse（JSON readValue<Int64> 对字符串会抛）
        @Expect(parseInt64Result("42"), 42)
        @Expect(parseInt64Result("0"), 0)
        @Expect(parseInt64Result(""), 0)
    }

    @TestCase
    public func testParseString(): Unit {
        let m = HashMap<String, String>()
        m["r1"] = "hello"
        @Expect(domParseResult<String>(m, "r1"), "hello")
    }

    @TestCase
    public func testParseMissingReturnsDefault(): Unit {
        let m = HashMap<String, String>()
        @Expect(domParseResult<String>(m, "r1"), "")
    }
}


// 数值结果解析辅助（对齐 DomApi.queryInt64 的内部逻辑）
func parseInt64Result(raw: String): Int64 {
    if (raw == "") { 0 } else { Int64.parse(raw, radix: 10) }
}
