package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// MessageBox 服务端侧测试：显隐/三种 kind 结构/图标类/动作收集/Input.onKeydown 透传
func renderMessageBoxJson(mb: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(mb, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

@Test
public class MessageBoxTest {
    @TestCase
    public func testHiddenRendersEmpty(): Unit {
        let vis = Signal<Bool>(false)
        let mb = MessageBox(vis).kind(MessageBoxKind2.Alert).title("t")
        let (json, handlers) = renderMessageBoxJson(mb)
        @Expect(json.contains("el-message-box"), false)
        @Expect(handlers.size, 0)
    }

    @TestCase
    public func testAlertStructure(): Unit {
        let vis = Signal<Bool>(true)
        let mb = MessageBox(vis)
            .kind(MessageBoxKind2.Alert)
            .title("操作提示")
            .message("这是一条 Alert 提示信息")
        let (json, handlers) = renderMessageBoxJson(mb)
        @Expect(json.contains("el-overlay is-message-box"), true)
        @Expect(json.contains("el-message-box__title"), true)
        @Expect(json.contains("el-message-box__message"), true)
        @Expect(json.contains("el-message-box__headerbtn"), true)
        @Expect(json.contains("el-message-box__close"), true)
        // Alert：只有确定按钮，无取消
        @Expect(json.contains("el-button--primary"), true)
        @Expect(json.contains("el-message-box-icon--warning"), false)
        @Expect(handlers.size, 4) // close + noop + confirm + overlay-click
    }

    @TestCase
    public func testConfirmHasCancelAndWarningIcon(): Unit {
        let vis = Signal<Bool>(true)
        let mb = MessageBox(vis)
            .kind(MessageBoxKind2.Confirm)
            .title("确认删除")
            .message("确定要继续吗？")
            .onConfirm({ ctx => PatchResult.ReRender })
            .onCancel({ ctx => PatchResult.ReRender })
        let (json, handlers) = renderMessageBoxJson(mb)
        @Expect(json.contains("el-message-box-icon--warning"), true)
        @Expect(handlers.size, 5) // close + noop + cancel + confirm + overlay-click
    }

    @TestCase
    public func testCustomIconError(): Unit {
        let vis = Signal<Bool>(true)
        let mb = MessageBox(vis)
            .kind(MessageBoxKind2.Confirm)
            .icon(MessageBoxIcon2.Error)
            .title("t")
        let (json, _) = renderMessageBoxJson(mb)
        @Expect(json.contains("el-message-box-icon--error"), true)
        @Expect(json.contains("el-message-box-icon--warning"), false)
    }

    @TestCase
    public func testPromptHasInputAndBind(): Unit {
        let vis = Signal<Bool>(true)
        let val = Signal<String>("")
        let mb = MessageBox(vis)
            .kind(MessageBoxKind2.Prompt)
            .title("请输入名称")
            .placeholder("项目名称")
            .value(val)
        let (json, _) = renderMessageBoxJson(mb)
        @Expect(json.contains("el-message-box__input"), true)
        @Expect(json.contains("el-input__inner"), true)
        // bind：input 带 data-bind-id 且 value 来自信号
        @Expect(json.contains("data-bind-id"), true)
        @Expect(json.contains("\"value\":\"\""), true)
    }

    @TestCase
    public func testInputKeydownForwarded(): Unit {
        let vis = Signal<Bool>(true)
        let mb = MessageBox(vis)
            .kind(MessageBoxKind2.Prompt)
            .title("t")
        let (json, handlers) = renderMessageBoxJson(mb)
        // on("keydown") → node.actions 含 keydown（前端渲染时写 data-action-keydown）
        @Expect(json.contains("\"keydown\""), true)
        @Expect(handlers.size >= 4, true)
    }
}
