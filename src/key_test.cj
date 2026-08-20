package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// 构造带按键信息的 action params（与前端 JS 发送格式一致，全部为字符串）
func buildKeyParams(key: String, code: String, keyCode: Int64, ctrl: Bool, shift: Bool, alt: Bool, meta: Bool): HashMap<String, String> {
    let p = HashMap<String, String>()
    p["key"] = key
    p["code"] = code
    p["keyCode"] = keyCode.toString()
    p["ctrl"] = if (ctrl) { "1" } else { "0" }
    p["shift"] = if (shift) { "1" } else { "0" }
    p["alt"] = if (alt) { "1" } else { "0" }
    p["meta"] = if (meta) { "1" } else { "0" }
    p
}

@Test
public class KeyEventTest {
    @TestCase
    public func testParseKeyEvent(): Unit {
        let p = buildKeyParams("Enter", "Enter", 13, true, false, false, false)
        match (parseKeyEvent(p)) {
            case Some(ke) =>
                @Expect(ke.key, "Enter")
                @Expect(ke.code, "Enter")
                @Expect(ke.keyCode, 13)
                @Expect(ke.ctrl, true)
                @Expect(ke.shift, false)
                @Expect(ke.alt, false)
                @Expect(ke.meta, false)
            case None => @Fail("expected KeyEvent")
        }
    }

    @TestCase
    public func testParseKeyEventNoneWithoutKey(): Unit {
        match (parseKeyEvent(HashMap<String, String>())) {
            case Some(_) => @Fail("expected None")
            case None => @Expect(true, true)
        }
    }

    @TestCase
    public func testKeyEventHelpers(): Unit {
        match (parseKeyEvent(buildKeyParams("Enter", "Enter", 13, false, false, false, false))) {
            case Some(ke) =>
                @Expect(ke.isEnter(), true)
                @Expect(ke.isEscape(), false)
            case None => @Fail("expected KeyEvent")
        }
        match (parseKeyEvent(buildKeyParams("Escape", "Escape", 27, false, false, false, false))) {
            case Some(ke) =>
                @Expect(ke.isEnter(), false)
                @Expect(ke.isEscape(), true)
            case None => @Fail("expected KeyEvent")
        }
    }

    @TestCase
    public func testKeyEventKeycodeParseInvalid(): Unit {
        let p = HashMap<String, String>()
        p["key"] = "a"
        p["code"] = "KeyA"
        p["keyCode"] = "not-a-number"
        match (parseKeyEvent(p)) {
            case Some(ke) => @Expect(ke.keyCode, 0)
            case None => @Fail("expected KeyEvent with fallback keyCode")
        }
    }

    @TestCase
    public func testActionContextKeyEvent(): Unit {
        let router = Router("s1", { _ => () })
        let ke = KeyEvent("Enter", "Enter", 13, false, false, false, false)
        let ctx = ActionContext("s1", HashMap<String, String>(), HashMap<String, String>(), router, keyEvent: Some(ke))
        match (ctx.keyEvent) {
            case Some(k) =>
                @Expect(k.key, "Enter")
                @Expect(k.isEnter(), true)
            case None => @Fail("expected keyEvent")
        }
    }

    @TestCase
    public func testActionContextKeyEventDefaultNone(): Unit {
        let router = Router("s1", { _ => () })
        let ctx = ActionContext("s1", HashMap<String, String>(), HashMap<String, String>(), router)
        match (ctx.keyEvent) {
            case Some(_) => @Fail("expected None")
            case None => @Expect(true, true)
        }
    }

    // 从 WS 原始 JSON 解析 action params 对象
    @TestCase
    public func testReadActionParams(): Unit {
        let raw = "{\"type\":\"action\",\"name\":\"h:a:keydown\",\"params\":{\"key\":\"Enter\",\"code\":\"Enter\",\"keyCode\":\"13\",\"ctrl\":\"1\",\"shift\":\"0\"},\"sessionId\":\"s1\"}"
        let p = readActionParams(raw)
        match (p.get("key")) {
            case Some(v) => @Expect(v, "Enter")
            case None => @Fail("expected key")
        }
        match (p.get("code")) { case Some(v) => @Expect(v, "Enter") case None => @Fail("expected code") }
        match (p.get("keyCode")) { case Some(v) => @Expect(v, "13") case None => @Fail("expected keyCode") }
        match (p.get("ctrl")) { case Some(v) => @Expect(v, "1") case None => @Fail("expected ctrl") }
        @Expect(p.size, 5)
    }

    // params 不在消息中或为空时返回空 map
    @TestCase
    public func testReadActionParamsNone(): Unit {
        let raw = "{\"type\":\"action\",\"name\":\"h:a:click\"}"
        let p = readActionParams(raw)
        @Expect(p.size, 0)
    }

    // 点击等普通 action 也能把 data-* 参数解析进 params（之前服务端丢弃了 params）
    @TestCase
    public func testReadActionParamsClickData(): Unit {
        let raw = "{\"type\":\"action\",\"name\":\"submit\",\"params\":{\"row\":\"3\",\"col\":\"2\"},\"sessionId\":\"s1\"}"
        let p = readActionParams(raw)
        match (p.get("row")) {
            case Some(v) => @Expect(v, "3")
            case None => @Fail("expected row")
        }
        match (p.get("col")) { case Some(v) => @Expect(v, "2") case None => @Fail("expected col") }
    }
}
