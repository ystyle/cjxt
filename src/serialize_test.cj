package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class SerializeTest {
    @TestCase
    public func testSerializeSimpleText(): Unit {
        let handlerMap = HashMap<String, ActionHandler>()
        let json = serializeSubtree(text("hello"), handlerMap)
        @Expect(json.contains("hello"), true)
        @Expect(json.contains("text"), true)
    }

    @TestCase
    public func testSerializeWithHandler(): Unit {
        let handlerMap = HashMap<String, ActionHandler>()
        let node = div([text("ok")]).onClick({ _ => PatchResult.ReRender })
        let json = serializeSubtree(node, handlerMap)

        @Expect(json.contains("ok"), true)
        @Expect(handlerMap.size > 0, true)

        // 验证 handler ID 出现在 JSON 中
        for ((id, _) in handlerMap) {
            @Expect(json.contains(id), true)
        }
    }

    @TestCase
    public func testSerializeHandlersConsistent(): Unit {
        let handlerMap = HashMap<String, ActionHandler>()
        let node = div([span([text("a")]).onClick({ _ => PatchResult.ReRender }), span([text("b")]).onClick({ _ => PatchResult.ReRender })])
        let json = serializeSubtree(node, handlerMap)

        // 每个 handler 都应该在 JSON 中有对应 ID
        @Expect(handlerMap.size, 2)
        for ((id, _) in handlerMap) {
            @Expect(json.contains(id), true)
        }
    }
}
