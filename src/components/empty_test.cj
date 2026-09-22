// Empty 默认插图的配色变量（回归）
//
// 契约：插图里的 fill 必须引用**本仓 CSS 真的定义了**的变量。原来写的是
// `var(--el-fill-color-1)`，而 vendored 的 EP 样式里只定义了 `--el-empty-fill-color-*` ——
// var() 解析失败会让 fill 回落到初始值 **黑色**，于是空态插图变成几块黑色方块
// （看着像图裂了）。这条守住"引用名与 CSS 定义一致"。
package cjxt.components

import cjxt.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class EmptyImageCssTest {
    @TestCase
    public func testDefaultSvgReferencesDefinedVariables(): Unit {
        let rendered = serializeSubtree(Empty().description("空"), HashMap<String, ActionHandler>())
        // 用的是 CSS 里定义过的那套变量
        @Expect(rendered.contains("var(--el-empty-fill-color-1)"), true)
        // 没有引用未定义的 --el-fill-color-N
        @Expect(rendered.contains("var(--el-fill-color-"), false)
        // 且这些变量确实在组件 CSS 里有定义（防止将来又改回一个不存在的名字）
        @Expect(_componentCSS.contains("--el-empty-fill-color-1:"), true)
    }
}
