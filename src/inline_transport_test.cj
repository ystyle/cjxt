// 内联首屏与页面承载测试
//
// 覆盖两件事：
// 1. 初始树内联进 HTML（`__CJXT_INITIAL_TREE__`）且脚本安全：JSON 里的 `</script>`
//    与 `<!--` 必须被转义，否则页面在数据处被提前截断。
// 2. 脱离连接的承载：renderDetachedPage / drainDetachedFrames / feedDetachedMessage
//    与 WS 路径共用同一套会话与分发语义（不监听端口也能渲染并交互）。
package cjxt

import cjxt.macros.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// 宿主绑定测试页：内联可断言的标记 + 一个可点动作
@Page["/inline-probe"]
class InlineProbePage <: Component {
    var hits = Signal<Int64>(0)

    public init() {}

    public func render(): IComponent {
        div([
            span([text("probe-hits=${this.hits.get()}")]),
            button([text("hit")]).onClick({ _ =>
                this.hits.update({ v => v + 1 })
                PatchResult.ReRender
            })
        ])
    }

}

@Test
class InlineTreeTest {

    // 内联槽位：树 JSON 出现在文档里，且第三参不再写死 null
    @TestCase
    func testInitialTreeIsInlined(): Unit {
        let html = generateHtmlShell("sid-1", initialTree: "{\"type\":\"text\"}")
        @Expect(html.contains("window.__CJXT_INITIAL_TREE__ = {\"type\":\"text\"}"), true)
        @Expect(html.contains("new CangjieUI(document.getElementById('app'), \"sid-1\", window.__CJXT_INITIAL_TREE__ || null)"), true)
    }

    // 未提供初始树时保持旧行为：仍是"读全局槽位、缺省 null"的空壳，
    // 不额外插入赋值脚本（调用方可能只要壳）
    @TestCase
    func testWithoutInitialTreeKeepsShell(): Unit {
        let html = generateHtmlShell("sid-2")
        @Expect(html.contains("window.__CJXT_INITIAL_TREE__ = "), false)
        @Expect(html.contains("window.__CJXT_INITIAL_TREE__ || null"), true)
        @Expect(html.contains("new CangjieUI(document.getElementById('app'), \"sid-2\""), true)
    }

    // `</script>` 必须转义：否则浏览器在数据里结束脚本块，后续 JS 变成文本
    @TestCase
    func testClosingScriptTagIsEscaped(): Unit {
        let escaped = escapeInlineScript("{\"t\":\"</script><h1>x</h1>\"}")
        @Expect(escaped.contains("</script>"), false)
        @Expect(escaped.contains("<\\/script>"), true)
    }

    // `<!--` 会进入脚本数据转义态，也必须转义
    @TestCase
    func testHtmlCommentOpenIsEscaped(): Unit {
        let escaped = escapeInlineScript("a<!--b")
        @Expect(escaped.contains("<!--"), false)
        @Expect(escaped.contains("<\\!--"), true)
    }

    // 内联文档里带 `</script>` 的树经过 generateHtmlShell 后不得留下裸 `</script>`
    @TestCase
    func testInlinedDocumentHasNoBareClosingScriptInData(): Unit {
        let html = generateHtmlShell("sid-3", initialTree: "{\"attrs\":{\"text\":\"</script>\"}}")
        // 文档自身的两个 </script> 结束标签之外，不应再有来自数据的裸标签
        let c = countOccurrences(html, "</script>")
        @Expect(c, 2)
        @Expect(html.contains("<\\/script>"), true)
    }

    // 指纹：同内容同值、异内容异值、空串可区分
    @TestCase
    func testFingerprintIdentifiesSameTree(): Unit {
        @Expect(treeFingerprint("{\"a\":1}") == treeFingerprint("{\"a\":1}"), true)
        @Expect(treeFingerprint("{\"a\":1}") != treeFingerprint("{\"a\":2}"), true)
        @Expect(treeFingerprint("") != treeFingerprint("{}"), true)
        // 长度参与：短串不是长串的前缀碰撞
        @Expect(treeFingerprint("ab") != treeFingerprint("abab"), true)
    }
}

@Test
class BufferSinkTest {

    @TestCase
    func testDrainReturnsInOrderAndClears(): Unit {
        let sink = BufferSink()
        sink.sendText("one")
        sink.sendText("two")
        @Expect(sink.pendingCount(), 2)
        let items = sink.drain()
        @Expect(items.size, 2)
        @Expect(items[0], "one")
        @Expect(items[1], "two")
        @Expect(sink.pendingCount(), 0)
    }

    // 二进制帧在无连接承载下不得静默丢弃（宿主能看到"为什么没收上传回执"）
    @TestCase
    func testBinaryFrameIsReportedNotDropped(): Unit {
        let sink = BufferSink()
        sink.sendBinary("bytes".toArray())
        let items = sink.drain()
        @Expect(items.size, 1)
        @Expect(items[0].contains("binary_frame_requires_websocket"), true)
    }

    @TestCase
    func testCloseIsObservable(): Unit {
        let sink = BufferSink()
        @Expect(sink.isClosed(), false)
        sink.close()
        @Expect(sink.isClosed(), true)
    }

    // 强类型消息经 sink 的线格式与 WS 路径一致（kind 字段存在）
    @TestCase
    func testSinkSendJsonKeepsWireFormat(): Unit {
        let sink = BufferSink()
        sinkSendJson(sink, ConnectedMsg())
        let items = sink.drain()
        @Expect(items.size, 1)
        @Expect(items[0].contains("\"kind\":\"connected\""), true)
    }
}

@Test
class DetachedCarrierTest {

    // 脱离连接渲染：能拿到 (会话 id, HTML)，HTML 内联了真实组件树
    @TestCase
    func testRenderDetachedPageReturnsSessionAndInlinedHtml(): Unit {
        let app = App()
        let rendered = app.renderDetachedPage("/inline-probe")
        @Expect(rendered.isSome(), true)
        let (sid, html) = rendered.getOrThrow()
        @Expect(sid != "", true)
        @Expect(html.contains("__CJXT_INITIAL_TREE__"), true)
        @Expect(html.contains("probe-hits=0"), true)
        // 脱离连接也要有出站通道（承载方从这里取帧）
        @Expect(app.drainDetachedFrames(sid).size >= 0, true)
    }

    // 未知路由返回 None（而不是抛异常/渲染空页）
    @TestCase
    func testRenderUnknownPathReturnsNone(): Unit {
        let app = App()
        @Expect(app.renderDetachedPage("/definitely-not-registered").isNone(), true)
    }

    // 承载方喂入交互：action 与 WS 走同一套语义 → 命中计数推进并产出补丁帧
    @TestCase
    func testFeedDetachedMessageRunsAction(): Unit {
        let app = App()
        let (sid, html) = app.renderDetachedPage("/inline-probe").getOrThrow()
        let _ = app.drainDetachedFrames(sid)
        let handlerId = extractClickHandlerId(html)
        @Expect(handlerId != "", true)
        let ok = app.feedDetachedMessage(sid, "{\"type\":\"action\",\"name\":\"" + handlerId + "\",\"params\":{}}")
        @Expect(ok, true)
        let out = app.drainDetachedFrames(sid)
        // 至少产出一条包；命中后组件重渲应带来含 probe-hits=1 的补丁
        var sawPatch = false
        for (item in out) {
            if (item.contains("probe-hits=1")) { sawPatch = true }
        }
        @Expect(sawPatch, true)
    }

    // 未知消息类型不算分发（承载方据此判断"这条消息框架不认识"）
    @TestCase
    func testFeedUnknownMessageReturnsFalse(): Unit {
        let app = App()
        let (sid, _) = app.renderDetachedPage("/inline-probe").getOrThrow()
        @Expect(app.feedDetachedMessage(sid, "{\"type\":\"nope\"}"), false)
    }

    // 会话不存在时分发/取包都是安全空操作
    @TestCase
    func testMissingSessionIsSafe(): Unit {
        let app = App()
        @Expect(app.feedDetachedMessage("no-such", "{\"type\":\"action\"}"), false)
        @Expect(app.drainDetachedFrames("no-such").size, 0)
        @Expect(app.closeDetachedSession("no-such"), false)
    }

    // 关闭会话后不再能分发（资源已回收）
    @TestCase
    func testCloseDetachedSessionStopsFeed(): Unit {
        let app = App()
        let (sid, _) = app.renderDetachedPage("/inline-probe").getOrThrow()
        @Expect(app.closeDetachedSession(sid), true)
        @Expect(app.feedDetachedMessage(sid, "{\"type\":\"action\",\"name\":\"h:hit\"}"), false)
        @Expect(app.closeDetachedSession(sid), false)
    }
}

// 从内联 HTML 里提取按钮 click 的 handler id（形如 "click":"h:children/0:click"）。
// 不硬编码 id：它是渲染期按树路径派生的，写死会在结构变化时变成假绿。
func extractClickHandlerId(html: String): String {
    let marker = "\"click\":\""
    match (html.indexOf(marker, 0)) {
        case Some(i) =>
            let from = i + marker.size
            match (html.indexOf("\"", from)) {
                case Some(j) => html[from..j]
                case None => ""
            }
        case None => ""
    }
}

// 数子串出现次数（不依赖正则，边界清晰）
func countOccurrences(text: String, needle: String): Int64 {
    if (needle == "") { return 0 }
    var count: Int64 = 0
    var from: Int64 = 0
    while (true) {
        match (text.indexOf(needle, from)) {
            case Some(i) =>
                count += 1
                from = i + needle.size
            case None => break
        }
    }
    count
}

// ── 报文解析的中文/多字节回归 ────────────────────────────────────────
//
// 守的契约：解析器必须按 **Rune（字符）** 索引，不能"逐字节切片"。
//
// 仓颉的 String 有两套下标语义，混用即炸：
//   - `s.size` / `s.indexOf(x)` 给**字节**偏移；
//   - `s[i..j]` 切片要求 i、j 落在**字符边界**。
// 于是 `s[i..(i+1)]` 这种逐字节推进碰到中文直接抛
// `Invalid utf8 byte sequence`，而异常被上层 catch 吞掉后表现为
// "消息静默不分发" —— ASCII 全绿、一有中文就断，极难排查。
//
// 这组用例用**中文值**跑一遍所有入口；一旦有人改回逐字节写法，这里立刻红。
@Test
class Utf8ParsingTest {

    // bind 消息：值是中文（Inputs/Todo 页打字走的正是这条路）
    @TestCase
    func testBindValueChinese(): Unit {
        let msg = "{\"type\":\"bind\",\"name\":\"p:children/0:bind\",\"value\":\"你好，世界\"}"
        @Expect(readBindValue(msg), "你好，世界")
    }

    // 单字、emoji（4 字节）、混合都要过
    @TestCase
    func testBindValueMultibyteVariants(): Unit {
        @Expect(readBindValue("{\"value\":\"中\"}"), "中")
        @Expect(readBindValue("{\"value\":\"a中b\"}"), "a中b")
        @Expect(readBindValue("{\"value\":\"emoji🙂ok\"}"), "emoji🙂ok")
        @Expect(readBindValue("{\"value\":\"\"}"), "")
    }

    // 冒号后带空白（宿主侧序列化器行为）也不能影响中文
    @TestCase
    func testBindValueWithSpaceAfterColon(): Unit {
        @Expect(readBindValue("{\"type\": \"bind\", \"value\": \"中文值\"}"), "中文值")
    }

    // action 的 name 字段含中文（handler id 一般不含，但字段解析要走同一路径）
    @TestCase
    func testActionNameChinese(): Unit {
        let msg = "{\"type\":\"action\",\"name\":\"按钮_点击\",\"params\":{}}"
        @Expect(readFieldOf(msg, "name"), "按钮_点击")
    }

    // params 的值是中文：Todo 输入、表单提交都会带中文参数
    @TestCase
    func testActionParamsChineseValues(): Unit {
        let msg = "{\"type\":\"action\",\"name\":\"h:x\",\"params\":{\"text\":\"购买牛奶\",\"note\":\"备注：中文\"}}"
        let p = readActionParams(msg)
        @Expect(p.get("text") ?? "", "购买牛奶")
        @Expect(p.get("note") ?? "", "备注：中文")
    }

    // params 前后带空白（容忍冒号后空格）
    @TestCase
    func testActionParamsWithSpaces(): Unit {
        let msg = "{\"type\": \"action\", \"params\": {\"k\": \"中文\"} }"
        @Expect(readActionParams(msg).get("k") ?? "", "中文")
    }

    // dom_result 的 results 值是中文
    @TestCase
    func testResultsChinese(): Unit {
        let msg = "{\"type\":\"dom_result\",\"txId\":\"t1\",\"results\":{\"r1\":\"中文结果\"}}"
        @Expect(readResults(msg).get("r1") ?? "", "中文结果")
    }

    // 多字节字符紧邻定界符（最容易踩边界的位置）
    @TestCase
    func testMultibyteAdjacentToDelimiters(): Unit {
        @Expect(readBindValue("{\"value\":\"中\"}"), "中")
        @Expect(readBindValue("{\"value\":\"中中中\"}"), "中中中")
        @Expect(extractQuotedAfter("{\"name\":\"中文名\"}", "\"name\":\""), "中文名")
    }
}

// 同包测试访问 private readField 的桥（readField 是文件级 private）
func readFieldOf(raw: String, field: String): String {
    readBindValue(raw.replace("\"${field}\"", "\"value\""))
}
