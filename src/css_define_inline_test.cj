// 内联 @defineCSS 回归测试：raw string 定界符（"""）不得泄入产物，
// class 名应被正确 scoped。此文件在 cjpm test 编译期触发宏。
// 背景：此前 @defineCSS("""...""") 走 input.toString() 会把 """ 一并写进
// bundle.css，导致产物带多余定界符；现改走 token.value（不含定界符）。
package cjxt

import cjxt.macros.*
import std.unittest.*
import std.unittest.testmacro.*

let inlineCss = @defineCSS("""
.row { display: flex; gap: 12px; }
.card { background: #ffffff; border-radius: 6px; }
""")

@Test
public class CssDefineInlineTest {
    @TestCase
    public func testInlineScopesClasses(): Unit {
        let row = inlineCss.get("row")
        @Expect(row.contains("row_"), true)
        let card = inlineCss.get("card")
        @Expect(card.contains("card_"), true)
    }

    @TestCase
    public func testInlineCssHasNoRawStringDelimiters(): Unit {
        let css = inlineCss.get("_css")
        // 定界符不得泄入产物（回归本 bug）
        @Expect(css.contains("\"\"\""), false)
        // class 名 scoped 后仍在产物中
        @Expect(css.contains(".row_"), true)
    }

    @TestCase
    public func testInlineSassWorksAndNoDelimiters(): Unit {
        let sassCss = @defineCSS[sass]("""
$radius: 8px;
.pill { border-radius: $radius; }
""")
        let pill = sassCss.get("pill")
        @Expect(pill.contains("pill_"), true)
        let c = sassCss.get("_css")
        @Expect(c.contains("\"\"\""), false)
        @Expect(c.contains(".pill_"), true)
    }
}
