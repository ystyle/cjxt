package cjxt

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class MarkdownRenderTest {
    @TestCase
    public func testHeading(): Unit {
        let html = renderMarkdown("# 标题一")
        @Expect(html.contains("<h1"), true)
        @Expect(html.contains("标题一"), true)
    }

    @TestCase
    public func testBoldItalicCode(): Unit {
        let html = renderMarkdown("**加粗** 和 *斜体* 和 `行内代码`")
        @Expect(html.contains("<strong>"), true)
        @Expect(html.contains("<em>"), true)
        @Expect(html.contains("<code>"), true)
    }

    @TestCase
    public func testFencedCodeBlock(): Unit {
        let html = renderMarkdown("```\nlet a = 1\n```")
        @Expect(html.contains("<pre>"), true)
        @Expect(html.contains("<code>"), true)
    }

    @TestCase
    public func testList(): Unit {
        let html = renderMarkdown("- 项目一\n- 项目二")
        @Expect(html.contains("<ul>"), true)
        @Expect(html.contains("<li>"), true)
    }

    @TestCase
    public func testBlockquote(): Unit {
        let html = renderMarkdown("> 引用内容")
        @Expect(html.contains("<blockquote>"), true)
    }

    @TestCase
    public func testEmpty(): Unit {
        @Expect(renderMarkdown(""), "")
    }

    @TestCase
    public func testEscapeFallback(): Unit {
        let out = escapeHtmlText("<script>alert(1)</script>")
        @Expect(out.contains("&lt;"), true)
        @Expect(out.contains("&gt;"), true)
        @Expect(out.contains("<script>"), false)
    }
}
