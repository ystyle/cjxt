package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Popconfirm 服务端侧测试：render 产出 client:Popconfirm 节点 + props 正确 +
// onConfirm/onCancel 动作经 expandTree/serializeSubtree 派发为 data-action-*（前端 popconfirm.js 点击按钮按此派发）
@Test
public class PopconfirmTest {
    @TestCase
    public func testRenderProducesClientNodeWithProps(): Unit {
        let pc = Popconfirm("确定删除这条记录？", "删除")
            .confirmButtonText("是的").cancelButtonText("再想想").width(220)
        let expanded = RenderContext.expandTree(pc, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let json = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        @Expect(json.contains("client:Popconfirm"), true)
        @Expect(json.contains("确定删除这条记录？"), true)
        @Expect(json.contains("\"删除\""), true)
        @Expect(json.contains("\"是的\""), true)
        @Expect(json.contains("\"再想想\""), true)
        @Expect(json.contains("220"), true)
        @Expect(handlerMap.size, 0)
    }

    @TestCase
    public func testDefaultButtonTexts(): Unit {
        let pc = Popconfirm("提示", "点我")
        let expanded = RenderContext.expandTree(pc, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let json = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        @Expect(json.contains("\"确定\""), true)
        @Expect(json.contains("\"取消\""), true)
    }

    @TestCase
    public func testConfirmCancelActionsCollected(): Unit {
        let pc = Popconfirm("t", "x")
            .onConfirm({ ctx => PatchResult.ReRender })
            .onCancel({ ctx => PatchResult.ReRender })
        let expanded = RenderContext.expandTree(pc, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let json = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        @Expect(json.contains("\"confirm\""), true)
        @Expect(json.contains("\"cancel\""), true)
        @Expect(handlerMap.size, 2)
    }

    @TestCase
    public func testNoCallbacksNoActions(): Unit {
        let pc = Popconfirm("t", "x")
        let expanded = RenderContext.expandTree(pc, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let json = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        @Expect(json.contains("\"confirm\""), false)
        @Expect(json.contains("\"cancel\""), false)
        @Expect(handlerMap.size, 0)
    }
}
