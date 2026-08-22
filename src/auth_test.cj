// 通用认证机制单元测试：会话上下文读写 + AuthHooks 钩子 + DenyMsg/AuthMsg
package cjxt

import std.collection.*
import std.io.{ByteBuffer}
import stdx.encoding.json.stream.{JsonWriter, JsonSerializable}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class AuthTest {
    @TestCase
    public func testSetGetContext(): Unit {
        let router = Router("s1", { _ => () })
        let ctx = ActionContext("s1", HashMap<String, String>(), HashMap<String, String>(), router)
        ctx.setContext("uid", "1")
        ctx.setContext("isAdmin", "1")
        @Expect(ctx.getContext().get("uid").getOrThrow(), "1")
        @Expect(ctx.getContext().get("isAdmin").getOrThrow(), "1")
        // 覆盖写
        ctx.setContext("uid", "2")
        @Expect(ctx.getContext().get("uid").getOrThrow(), "2")
    }

    @TestCase
    public func testGetContextMissingKey(): Unit {
        let router = Router("s1", { _ => () })
        let ctx = ActionContext("s1", HashMap<String, String>(), HashMap<String, String>(), router)
        @Expect(ctx.getContext().get("nope").isNone(), true)
    }

    @TestCase
    public func testAuthHooksSetupValidate(): Unit {
        AuthHooks.reset()
        AuthHooks.setup({ t =>
            if (t == "good-token") {
                let m = HashMap<String, String>()
                m["uid"] = "7"
                m["isAdmin"] = "1"
                Some(m)
            } else {
                None
            }
        })
        match (AuthHooks.global()) {
            case Some(hooks) =>
                match (hooks.doValidateToken("good-token")) {
                    case Some(m) =>
                        @Expect(m.get("uid").getOrThrow(), "7")
                        @Expect(m.get("isAdmin").getOrThrow(), "1")
                    case None => @Fail("expected validated context")
                }
                @Expect(hooks.doValidateToken("bad-token").isNone(), true)
            case None => @Fail("expected AuthHooks global")
        }
        AuthHooks.reset()
        @Expect(AuthHooks.global().isNone(), true)
    }

    @TestCase
    public func testAuthHooksReplaceSemantics(): Unit {
        // 后配置者生效（与 RouteRegistry 覆盖语义一致）
        AuthHooks.reset()
        AuthHooks.setup({ _ => Some(HashMap<String, String>()) })
        AuthHooks.setup({ _ => None })
        match (AuthHooks.global()) {
            case Some(hooks) => @Expect(hooks.doValidateToken("any").isNone(), true)
            case None => @Fail("expected AuthHooks global")
        }
        AuthHooks.reset()
    }

    func serializeJson(v: JsonSerializable): String {
        let buf = ByteBuffer()
        let w = JsonWriter(buf)
        v.toJson(w)
        w.flush()
        buf.flush()
        String.fromUtf8(buf.bytes())
    }

    @TestCase
    public func testDenyMsgWithPath(): Unit {
        let d = DenyMsg("无权限访问", path: "/admin/login")
        let json = serializeJson(d)
        @Expect(json.contains("\"kind\":\"deny\""), true)
        @Expect(json.contains("\"path\":\"/admin/login\""), true)
        @Expect(json.contains("\"reason\":\"无权限访问\""), true)
    }

    @TestCase
    public func testDenyMsgNoPath(): Unit {
        let d = DenyMsg("无权限访问")
        let json = serializeJson(d)
        @Expect(json.contains("\"path\""), false)
    }

    @TestCase
    public func testAuthMsg(): Unit {
        let a = AuthMsg("tok-123")
        let json = serializeJson(a)
        @Expect(json.contains("\"kind\":\"auth\""), true)
        @Expect(json.contains("\"token\":\"tok-123\""), true)
    }

    @TestCase
    public func testTokenKey(): Unit {
        @Expect(TOKEN_KEY, "token")
    }
}
