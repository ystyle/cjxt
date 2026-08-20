package cjxt

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

/**
 * Session 级 handler 注册表回归：
 * refreshHandlers 从树重建 handlers，且多次调用只保留最新（不会累积/丢失）。
 * 这是「异步 pushUpdate 渲染出的 handler（如会话列表删除按钮）
 * 必须能被 listenLoop 分发到」的基础——handlers 存在 Session 而非
 * 每次新建的 SessionState 上。
 */
@Test
public class SessionTest {

    @TestCase
    public func testRefreshHandlersRebuildsFromTree(): Unit {
        let session = Session("s1", div([]), div([]))
        // 树1：只有 clickA
        let t1 = div([button([text("a")]).onClick({ _ => PatchResult.ReRender })])
        session.refreshHandlers(RenderContext.expandTree(t1, ""))
        @Expect(session.handlers.size > 0)
        var hasClick = false
        for ((id, _) in session.handlers) {
            if (id.contains("click")) { hasClick = true }
        }
        @Expect(hasClick)
        let size1 = session.handlers.size

        // 树2：换一批 handler（点击 b）——refreshHandlers 应整体重建
        let t2 = div([button([text("b")]).onClick({ _ => PatchResult.ReRender })])
        session.refreshHandlers(RenderContext.expandTree(t2, ""))
        @Expect(session.handlers.size, size1)
        // 树2 的 click handler 仍在（重建后仍可分发）
        var stillClick = false
        for ((id, _) in session.handlers) {
            if (id.contains("click")) { stillClick = true }
        }
        @Expect(stillClick)
    }

    @TestCase
    public func testRefreshHandlersDoesNotAccumulate(): Unit {
        let session = Session("s2", div([]), div([]))
        // 连续两次 refresh：第二次后数量应与第一次一致（不累积旧 handler）
        let t1 = div([button([text("a")]).onClick({ _ => PatchResult.ReRender })])
        session.refreshHandlers(RenderContext.expandTree(t1, ""))
        let n1 = session.handlers.size
        let t2 = div([button([text("b")]).onClick({ _ => PatchResult.ReRender })])
        session.refreshHandlers(RenderContext.expandTree(t2, ""))
        let n2 = session.handlers.size
        @Expect(n2, n1)
    }

    @TestCase
    public func testBindHandlerCollectedFromTree(): Unit {
        // bind 也是 handler 注册的一部分，refreshHandlers 应能收集到
        let s = Signal<String>("")
        let session = Session("s3", div([]), div([]))
        let t = div([input().bind(s)])
        session.refreshHandlers(RenderContext.expandTree(t, ""))
        var hasBind = false
        for ((id, _) in session.handlers) {
            if (id.contains("bind")) { hasBind = true }
        }
        @Expect(hasBind)
    }
}
