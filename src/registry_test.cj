package cjxt

import std.collection.*
import std.io.{ByteBuffer}
import stdx.encoding.json.stream.{JsonWriter}
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

    @TestCase
    public func testRegisterReplacesSamePath(): Unit {
        let reg = RouteRegistry()
        reg.register("/a", { => div([]) })
        reg.register("/a", { => div([text("second")]) })
        // 同路径后注册者生效：只保留一条，且解析到最新的工厂
        @Expect(reg.entriesSize(), 1)
        let c = reg.create("/a")
        match (c) {
            case Some(page) =>
                let vnode = page.renderWithScope()
                @Expect(serializeTestNode(vnode).contains("second"))
            case None => @Fail("expected /a to resolve")
        }
    }

    @TestCase
    public func testRegisterReplaceKeepsOtherPaths(): Unit {
        let reg = RouteRegistry()
        reg.register("/a", { => div([]) })
        reg.register("/b", { => div([]) })
        reg.register("/a", { => div([text("newA")]) })
        @Expect(reg.entriesSize(), 2)
        let a = reg.create("/a")
        match (a) {
            case Some(page) => @Expect(serializeTestNode(page.renderWithScope()).contains("newA"))
            case None => @Fail("expected /a")
        }
        let b = reg.create("/b")
        match (b) {
            case Some(_) => ()
            case None => @Fail("expected /b")
        }
    }
}

/** 把 IComponent 序列化为 JSON 字符串（测试断言用） */
func serializeTestNode(c: IComponent): String {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    c.toJson(w)
    w.flush()
    buf.flush()
    String.fromUtf8(buf.bytes())
}
