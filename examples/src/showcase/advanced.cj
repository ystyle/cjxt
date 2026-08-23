// 框架/进阶能力演示：Markdown / AutoScroll / Reactive / VirtualList / DomTx
package examples.showcase

import cjxt.*
import cjxt.components.*
import std.collection.{ArrayList, HashMap}

public func demoMarkdown(st: ShowcaseState): Array<IComponent> {
    let sample = """
# 欢迎使用 Markdown 组件

这是 **服务端渲染** 的 Markdown 内容（由 markit 解析为 HTML）。

## 支持的功能

- 标题、**加粗**、*斜体*、~~删除线~~、`行内代码`
- 代码块、列表、引用、表格、链接

```cangjie
public func main() {
    println("Hello, Cangjie!")
}
```

> 引用：仓颉 + cjxt 全栈服务端驱动。

| 组件 | 状态 |
|------|------|
| Markdown | ✅ 已完成 |
| 表格 | ✅ 支持 |

[访问 cjxt 文档](https://example.com/cjxt)
"""
    [
        demoSection("Markdown 渲染（服务端 markit 解析 → HTML）", [
            div([
                Markdown().content(sample),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoAutoScroll(st: ShowcaseState): Array<IComponent> {
    let appendH: ActionHandler = { ctx =>
        let n = st.chatCounter.get() + 1
        st.chatCounter.set(n)
        st.chatMessages.update({ list => let c = ArrayList<String>(list); c.add("这是第 ${n} 条模拟流式消息，内容会持续追加，用于测试自动滚动贴底跟随的行为是否正常。"); c })
        PatchResult.ReRender
    }
    let clearH: ActionHandler = { ctx => st.chatMessages.set(ArrayList<String>()); PatchResult.ReRender }
    [
        demoSection("自动滚动（data-auto-scroll：贴近底部时随内容贴底，回看历史时不打断）", [
            div([
                PrimaryButton("追加消息").onClick(appendH),
                DangerButton("清空").onClick(clearH),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            VNode("div", buildAutoScrollItems(st.chatMessages.get()), attrs: Some(HashMap<String, String>([("data-auto-scroll", ""), ("style", "height:240px;overflow-y:auto;border:1px solid #e5e7eb;border-radius:8px;padding:12px;background:#fafafa;width:100%")]))),
            div([text("当前消息数：${st.chatMessages.get().size}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoReactive(st: ShowcaseState): Array<IComponent> {
    let incH: ActionHandler = { ctx =>
        st.reactiveCount.update({ v => v + 1 })
        PatchResult.ReRender
    }
    let batchH: ActionHandler = { ctx =>
        batch({ =>
            st.reactiveCount.update({ v => v + 10 })
        })
        PatchResult.ReRender
    }
    let resetH: ActionHandler = { ctx =>
        st.reactiveCount.set(0)
        PatchResult.ReRender
    }
    [
        demoSection("响应式核心（Signal + Computed + Effect + batch）", [
            div([text("Signal count：${st.reactiveCount.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("Computed 派生（count × 2）：${st.reactiveDouble.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("Effect 自动跟随（= count）：${st.reactiveEffCount.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([
                PrimaryButton("+1").onClick(incH),
                PrimaryButton("+10（batch 一次通知）").onClick(batchH),
                DangerButton("重置").onClick(resetH),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("说明：computed 惰性缓存仅在依赖变化时重算；effect 随依赖自动重跑；batch 内多次 set 只触发一次重渲染")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

public func demoVirtualList(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("虚拟滚动（VirtualList：10000 项只渲染可视窗口）", [
            div([
                VirtualList<Int64>(st.virtualItems, { idx, item => virtualRow(idx, item) }, st.virtualScrollTop)
                    .itemHeight(40).height(320).buffer(3),
            ], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("总项数：${st.virtualItems.get().size}；滚动位置：${st.virtualScrollTop.get()}px（滚到中间验证窗口行号切换）")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("原理：客户端 rAF 节流上报 scrollTop（bind 消息）→ 服务端 computeVirtualWindow 只渲染可视行 + 占位保持总高度；配合 keyed reconciliation 每次滚动只 patch 窗口变化")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

func virtualRow(idx: Int64, item: Int64): IComponent {
    let a = HashMap<String, String>()
    a["class"] = "vlist-row"
    a["style"] = "height:40px;padding:0 12px;display:flex;align-items:center;border-bottom:1px solid #f0f2f5;font-size:13px"
    VNode("div", [text("第 ${item} 项（下标 ${idx}）")], attrs: Some(a))
}

public func demoDomTx(st: ShowcaseState): Array<IComponent> {
    [
        demoSection("DOM 事务（事件驱动：服务端发起命令/查询，前端执行，结果回传续体）", [
            div([DomTxWidget(st.domTxResult)], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("查询结果：${st.domTxResult.get()}")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
            div([text("原理：ctx.dom.command([...]) fire-and-forget（聚焦/滚动）；ctx.dom.query(path, prop){续体} —— 注册续体到 Session，dom_result 事件到达后驱动续体，无阻塞无死锁")], attrs: Some(HashMap<String, String>([("class", cls("row"))]))),
        ]),
    ]
}

// ============ Props ============

public func propsMarkdown(): IComponent {
    div([
        propRow("content", "String", "Markdown 原文"),
        propRow("bind(src)", "Readable<String>", "信号/计算值绑定（服务端 markit GFM 解析）"),
    ])
}

public func propsAutoScroll(): IComponent {
    div([
        propRow("data-auto-scroll", "容器属性", "贴底跟随：接近底部（<80px）时自动滚到底；回看历史不打断"),
    ])
}

public func propsReactive(): IComponent {
    div([
        propRow("Signal<T>", "响应式状态", "get/set、相等性守卫、batch 合并"),
        propRow("Computed<T>", "惰性派生值", "依赖变化自动失效，链条式"),
        propRow("Effect", "自动副作用", "依赖变化自动重跑（重入保护）"),
        propRow("batch / untracked", "顶层 API", "批量通知 / 不追踪读取"),
    ])
}

public func propsVirtualList(): IComponent {
    div([
        propRow("VirtualList(items)", "Signal<ArrayList<T>>", "数据源"),
        propRow("height", "Int64", "容器高度（px）"),
        propRow("itemHeight", "Int64", "行高（px）"),
        propRow("buffer", "Int64", "上下缓冲行数（默认 6）"),
    ])
}

public func propsDomTx(): IComponent {
    div([
        propRow("ctx.dom.command", "[domFocus/domScrollIntoView/domSetProperty]", "fire-and-forget 命令"),
        propRow("ctx.dom.query / queryAs", "ref + prop → String/JSON", "单查询（dom_result 驱动续体）"),
        propRow("ctx.dom.queryInt64", "ref + prop → Int64", "数值查询（解析字符串）"),
        propRow("ctx.dom.seq()", "DomSeq + timeout/cancel", "顺序命令/查询编排（不阻塞）"),
    ])
}
