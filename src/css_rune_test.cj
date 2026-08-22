// 中文 CSS 注释回归测试：@importCSS 按 Rune 处理，多字节 UTF-8 内容
// （中文注释/字符串）不得导致宏编译失败（此前逐字节处理会抛
// "Invalid utf8 byte sequence"）。此文件在 cjpm test 编译期触发宏。
package cjxt

import cjxt.macros.*
import std.unittest.*
import std.unittest.testmacro.*

// 含中文注释与中文内容的 CSS（编译期验证宏的 Rune 处理）
let cnCSS = @importCSS("_test_cn.css")

@Test
public class CssRuneTest {
    @TestCase
    public func testCnClassScoped(): Unit {
        // 中文注释存在时，类名仍被正确 scoped 并可通过 cls() 取到
        let c = cnCSS.get("cn-btn")
        @Expect(c.contains("cn-btn_"), true)
        let css = cnCSS.get("_css")
        @Expect(css.contains("cn-btn_"), true)
        // 中文内容原样保留在产物里
        @Expect(css.contains("按钮"), true)
    }
}
