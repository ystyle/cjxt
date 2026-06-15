package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

func checkResult(result: Option<HashMap<String, String>>): HashMap<String, String> {
    match (result) {
        case Some(params) => params
        case None => throw Exception("expected match")
    }
}

func checkVal(val: Option<String>, expected: String): Unit {
    match (val) {
        case Some(v) => @Expect(v, expected)
        case None => @Fail("expected value")
    }
}

@Test
public class RegistryTest {
    @TestCase
    public func testExactMatch(): Unit {
        let entry = RouteEntry("/order/list")
        let params = checkResult(entry.doMatch("/order/list"))
        @Expect(params.size, 0)
    }

    @TestCase
    public func testDynamicMatch(): Unit {
        let entry = RouteEntry("/order/[id]")
        let params = checkResult(entry.doMatch("/order/123"))
        checkVal(params.get("id"), "123")
    }

    @TestCase
    public func testMismatchPath(): Unit {
        let entry = RouteEntry("/order/list")
        let result = entry.doMatch("/user/list")
        match (result) {
            case Some(_) => @Fail("expected no match")
            case None => @Expect(true, true)
        }
    }

    @TestCase
    public func testMismatchDynamic(): Unit {
        let entry = RouteEntry("/order/[id]")
        let result = entry.doMatch("/order")
        match (result) {
            case Some(_) => @Fail("expected no match")
            case None => @Expect(true, true)
        }
    }

    @TestCase
    public func testMultipleDynamics(): Unit {
        let entry = RouteEntry("/order/[year]/[month]")
        let params = checkResult(entry.doMatch("/order/2026/06"))
        checkVal(params.get("year"), "2026")
        checkVal(params.get("month"), "06")
    }
}
