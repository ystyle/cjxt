package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.convert.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.base64.fromBase64String

// Watermark 测试。
// 对齐点：EP watermark.vue 的容器（position:relative）+ 绝对定位 repeat 背景浮层；
// EP 侧**没有 watermark.scss**，样式全部由 getMarkStyle() 内联生成——本组件同样内联。
// 实现差异：EP 用 canvas 画 PNG，服务端改用 SVG data URI（同样落成 background-image）。
@Test
public class WatermarkTest {
    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    @TestCase
    public func testContainerAndMarkStructure(): Unit {
        // 容器 + 内容 + 水印浮层
        let out = this.json(Watermark([text("内容")]))
        @Expect(out.contains("el-watermark"), true)
        @Expect(out.contains("el-watermark__mark"), true)
        @Expect(out.contains("内容"), true)
        // 容器必须 relative，否则绝对定位的浮层会锚到别处
        @Expect(out.contains("position:relative"), true)
    }

    @TestCase
    public func testMarkUsesRepeatAndPointerEventsNone(): Unit {
        // 平铺 + 不挡交互（EP getMarkStyle 的两个关键属性）
        let out = this.json(Watermark([text("x")]))
        @Expect(out.contains("background-repeat:repeat"), true)
        @Expect(out.contains("pointer-events:none"), true)
        @Expect(out.contains("position:absolute"), true)
    }

    @TestCase
    public func testMarkUsesSvgDataUri(): Unit {
        // 服务端实现：SVG data URI（EP 是 canvas PNG）
        let out = this.json(Watermark([text("x")]))
        @Expect(out.contains("data:image/svg+xml;base64,"), true)
        @Expect(out.contains("background-image:url("), true)
    }

    @TestCase
    public func testDefaultZIndexAndGap(): Unit {
        // EP 默认 zIndex 9。
        // 注意默认 content 是 "Cangjie UI"（非空），瓦片按文字估算会宽于 120，
        // 所以这里只断言 z-index 与「有 background-size」，不硬编 120。
        let out = this.json(Watermark([text("x")]))
        @Expect(out.contains("z-index:9"), true)
        @Expect(out.contains("background-size:"), true)
        @Expect(out.contains("64px"), true)
    }

    @TestCase
    public func testCustomZIndex(): Unit {
        let out = this.json(Watermark([text("x")]).zIndex(100))
        @Expect(out.contains("z-index:100"), true)
    }

    @TestCase
    public func testLongContentWidensMark(): Unit {
        // 长文字按字号估算加宽，避免被裁（EP 用 ctx.measureText 量）
        let shortOut = this.json(Watermark([text("x")]).content("A").fontSize(16))
        let longOut = this.json(Watermark([text("x")]).content("很长很长很长很长的水印文字内容").fontSize(16))
        @Expect(shortOut.contains("background-size:120px 64px"), true)
        @Expect(markWidth(longOut) > 120, true)
    }

    @TestCase
    public func testCjkWiderThanAscii(): Unit {
        // 同字符数下中文估算宽度应大于 ASCII（isWideRune 分支生效）
        let ascii = this.json(Watermark([text("x")]).content("abcdefghijklmnop"))
        let cjk = this.json(Watermark([text("x")]).content("中文水印文字中文水印文字"))
        @Expect(markWidth(ascii) < markWidth(cjk), true)
    }

    @TestCase
    public func testCustomColorAndRotateInSvg(): Unit {
        // color / rotate 必须真的进了 SVG（先解码 data URI 再断言明文）
        let out = this.json(Watermark([text("x")]).color("rgba(255,0,0,.3)").rotate(-45))
        let svg = svgOf(out)
        @Expect(svg.contains("rgba(255,0,0,.3)"), true)
        @Expect(svg.contains("rotate(-45"), true)
    }

    @TestCase
    public func testFontSizeInSvg(): Unit {
        let svg = svgOf(this.json(Watermark([text("x")]).content("TEST").fontSize(24)))
        @Expect(svg.contains("font-size=\"24\""), true)
    }

    @TestCase
    public func testXmlSpecialCharsEscaped(): Unit {
        // & < > 必须转义，否则 data URI 里的 XML 解析失败
        let svg = svgOf(this.json(Watermark([text("x")]).content("A&B<C>D")))
        @Expect(svg.contains("&amp;"), true)
        @Expect(svg.contains("&lt;"), true)
        @Expect(svg.contains("&gt;"), true)
        @Expect(svg.contains("A&B"), false)
    }

    @TestCase
    public func testEmptyContentStillRenders(): Unit {
        // 空内容不崩，仍是 120×64 瓦片
        let out = this.json(Watermark([text("x")]).content(""))
        @Expect(out.contains("el-watermark__mark"), true)
        @Expect(out.contains("background-size:120px 64px"), true)
    }
}

// ── 测试辅助：从渲染 JSON 里取 background-size 宽度 / 解码 SVG ──

func markWidth(json: String): Int64 {
    let marker = "background-size:"
    match (json.indexOf(marker, 0)) {
        case Some(pos) =>
            let tail = json[pos + marker.size..]
            match (tail.indexOf("px", 0)) {
                case Some(px) => parseOrZero(tail[0..px])
                case None => 0
            }
        case None => 0
    }
}

func parseOrZero(s: String): Int64 {
    try {
        Int64.parse(s.trimAscii(), radix: 10)
    } catch (e: Exception) {
        0
    }
}

func svgOf(json: String): String {
    let marker = "data:image/svg+xml;base64,"
    match (json.indexOf(marker, 0)) {
        case Some(pos) =>
            let tail = json[pos + marker.size..]
            // CSS 里是 url('<dataUri>')，base64 之后紧跟单引号再是右括号，
            // 两个都要当终止符，否则会把单引号带进 base64 导致解码失败。
            var end = tail.size
            match (tail.indexOf("'", 0)) {
                case Some(p) => end = p
                case None =>
                    match (tail.indexOf(")", 0)) {
                        case Some(p2) => end = p2
                        case None => ()
                    }
            }
            let b64 = tail[0..end]
            match (fromBase64String(b64)) {
                case Some(bytes) => String.fromUtf8(bytes)
                case None => ""
            }
        case None => ""
    }
}
