// @Page 宏多行字符串回归测试：@Page["""..."""] 的多行路径/标题应被识别并注册路由。
// 此前 @Page 只认 TokenKind.STRING_LITERAL（单行双引号），多行字符串会被忽略导致不注册。
// 现改为 isStringKind 统一识别（STRING_LITERAL / MULTILINE_STRING / MULTILINE_RAW_STRING 等）。
// 注意：Cangjie 的 """...""" 必须紧跟换行开头，.value 会带首尾换行，宏内用 trimWhitespace 清理。
package cjxt

import cjxt.macros.*
import std.unittest.*
import std.unittest.testmacro.*

@Page["""
/__test-multiline-path
""", """
多行标题
"""]
class TestMultilinePage <: Component {
    public init() {}
    public func render(): IComponent {
        div([text("multiline ok")])
    }
}

@Test
public class PageMacroTest {
    @TestCase
    public func testMultilinePathResolves(): Unit {
        let m = RouteRegistry.global().create("/__test-multiline-path")
        match (m) {
            case Some(page) =>
                @Expect(serializeTestNode(page.renderWithScope()).contains("multiline ok"))
            case None => @Fail("expected @Page multi-line string path to register")
        }
    }
}
