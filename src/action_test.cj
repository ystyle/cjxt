package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

class RouterSpy {
    var lastPath: String = ""

    public func record(path: String): Unit {
        this.lastPath = path
    }
}

@Test
public class ActionTest {
    @TestCase
    public func testRouterPush(): Unit {
        let spy = RouterSpy()
        let router = Router("s1", { path => spy.record(path) })
        router.push("/order/list")
        @Expect(spy.lastPath, "/order/list")
    }

    @TestCase
    public func testPatchEntry(): Unit {
        let p = PatchEntry("replace", "/children/0", Some("hello"), None)
        @Expect(p.op, "replace")
        @Expect(p.path, "/children/0")
    }

    @TestCase
    public func testPatchEntryNone(): Unit {
        let p = PatchEntry("remove", "/children/0", None, None)
        @Expect(p.op, "remove")
        @Expect(p.path, "/children/0")
    }

    @TestCase
    public func testActionContext(): Unit {
        let params = HashMap<String, String>()
        params["id"] = "123"
        let router = Router("s1", { _ => () })
        let ctx = ActionContext("s1", HashMap<String, String>(), params, router)
        @Expect(ctx.sessionId, "s1")
        match (ctx.params.get("id")) {
            case Some(v) => @Expect(v, "123")
            case None => @Fail("expected id")
        }
    }

    @TestCase
    public func testPatchResultReRender(): Unit {
        let r = PatchResult.ReRender
        match (r) {
            case ReRender => @Expect(true, true)
            case _ => @Fail("expected ReRender")
        }
    }
}
