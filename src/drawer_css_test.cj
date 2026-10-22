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
    // 取出所有以 `.el-drawer.<dir>` 开头的规则块正文（sass 可能把同一方向类拆成多条规则，
    // 例如 `.el-drawer.rtl { height/top/bottom }` 与 `.el-drawer.rtl { right: 0 }` 分开，
    // 所以不能只看第一条规则的固定字符窗口）
    func ruleBodies(dir: String): String {
        let prefix = ".el-drawer.${dir}"
        var out = ""
        var from: Int64 = 0
        var searching = true
        while (searching) {
            match (_componentCSS.indexOf(prefix, from)) {
                case Some(i) =>
                    // 选择器前缀之后必须紧跟空白或 `{`/`,`，避免匹配到 `.el-drawer.rtlx`
                    let after = i + prefix.size
                    let isBoundary = after >= _componentCSS.size ||
                        _componentCSS[after..(after + 1)] == " " ||
                        _componentCSS[after..(after + 1)] == "{" ||
                        _componentCSS[after..(after + 1)] == ","
                    if (!isBoundary) {
                        from = after
                    } else {
                        // 从选择器起点到该规则块结尾（第一个 `}`）
                        match (_componentCSS.indexOf("}", after)) {
                            case Some(end) =>
                                out = out + _componentCSS[i..(end + 1)]
                                from = end + 1
                            case None => searching = false
                        }
                    }
                case None => searching = false
            }
        }
        out
    }

    @TestCase
    public func testDirectionClassesArePositioned(): Unit {
        @Expect(_componentCSS.contains(".el-drawer.rtl"), true)
        @Expect(_componentCSS.contains(".el-drawer.ltr"), true)
        @Expect(_componentCSS.contains(".el-drawer.ttb"), true)
        @Expect(_componentCSS.contains(".el-drawer.btt"), true)
        // 各方向必须真的贴对应边（不是靠 transform 平移）
        @Expect(this.ruleBodies("rtl").contains("right: 0"), true)
        @Expect(this.ruleBodies("ltr").contains("left: 0"), true)
        @Expect(this.ruleBodies("ttb").contains("top: 0"), true)
        @Expect(this.ruleBodies("btt").contains("bottom: 0"), true)
    }
}
