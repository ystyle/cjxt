// Drawer 的方向定位样式（回归）
//
// 契约：`.el-drawer` 是 `position: absolute`，四个方向类必须各自贴边，否则抽屉会停在
// overlay 的左上角（vendored 的 EP 样式里曾经只剩 `.el-drawer .rtl` 这种**后代**选择器，
// 等于没有定位——组件渲染得出来，但位置是错的，只有真在浏览器里打开才看得出来）。
package cjxt

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class DrawerCssTest {
    @TestCase
    public func testDirectionClassesArePositioned(): Unit {
        @Expect(_componentCSS.contains(".el-drawer.rtl"), true)
        @Expect(_componentCSS.contains(".el-drawer.ltr"), true)
        @Expect(_componentCSS.contains(".el-drawer.ttb"), true)
        @Expect(_componentCSS.contains(".el-drawer.btt"), true)
        // 右抽屉必须真的贴右边（不是靠 transform 平移）
        let at = _componentCSS.indexOf(".el-drawer.rtl")
        match (at) {
            case Some(i) =>
                let seg = _componentCSS[i..(if (i + 60 < _componentCSS.size) { i + 60 } else { _componentCSS.size })]
                @Expect(seg.contains("right: 0"), true)
            case None => @Fail("找不到 .el-drawer.rtl")
        }
    }
}
