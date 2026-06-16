package cjxt

import std.collection.*
import std.reflect.*
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

    @TestCase
    public func testGetState(): Unit {
        let st = HashMap<String, AppState>()
        let key = TypeInfo.of<CounterState>().qualifiedName
        st.add(key, CounterState())
        let router = Router("s1", { _ => () })
        let ctx = ActionContext("s1", HashMap<String, String>(), HashMap<String, String>(), router, sessionStates: st)
        let s = ctx.getState<CounterState>()
        @Expect(s.counter.get(), 0)
        s.counter.set({ _ => 42 })
        @Expect(s.counter.get(), 42)
    }

    @TestCase
    public func testDoGetState(): Unit {
        let cs: AppState = CounterState()
        let r = doGetState<CounterState>(cs)
        @Expect(r.counter.get(), 0)
    }
}

class CounterState <: AppState {
    var counter = Store<Int64>(0)
}
