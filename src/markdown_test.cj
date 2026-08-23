package cjxt

import std.collection.ArrayList
import std.sync.{Mutex}
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


// ============ 并发解析稳定性（线上"偶尔空白"排查） ============
// 怀疑：markit/GFMBundle 首次初始化多线程竞态 → hasErrors 回退转义文本
@Test
public class MarkdownConcurrencyTest {
    @TestCase
    public func testConcurrentParseStable(): Unit {
        let sample = "# 欢迎使用 Markdown 组件\n\n**加粗** 与 `code`\n\n```cangjie\npublic func main() {}\n```\n\n| A | B |\n|---|---|\n| 1 | 2 |"
        @Expect(renderMarkdown(sample).contains("<h1"), true)
        let results = ArrayList<Bool>()
        let mutex = Mutex()
        let tasks = ArrayList<Future<Unit>>()
        for (i in 0..12) {
            let f = spawn {
                let html = renderMarkdown(sample)
                mutex.lock()
                results.add(html.contains("<h1"))
                mutex.unlock()
            }
            tasks.add(f)
        }
        for (t in tasks) {
            let _ = t.get()
        }
        @Expect(results.size, 12)
        for (ok in results) {
            @Expect(ok, true) // 任一并发失败 = markit 线程竞态
        }
    }
}
