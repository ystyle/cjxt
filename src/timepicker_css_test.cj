// TimePicker 面板的两处样式契约（回归）
//
// 背景：这两处都是**纯 CSS 缺陷**，DOM 结构本身是对的，单测断言 DOM 抓不到，
// 只有真在浏览器里看才暴露。用「断言编译产物里的规则」锁住，比截图断言稳。
//
// ① 选中横线只有一半
//    EP 用 .el-time-panel__content 的 ::before/::after 画选中区域的上下两条横线，
//    两者都是 z-index:-1（沉到内容之下、但要在**面板自己的背景**之上）。
//    EP 的 .el-time-panel 自带 background-color，所以 -1 层仍可见；
//    cjxt 的面板背景曾是透明的 → -1 层沉到外层 .el-picker__popper 的白底之下，横线被整片盖住。
//    修法：给 .el-time-panel 补不透明背景（--el-bg-color-overlay）。
//
// ② 滚动条太粗 + 把横线挤断
//    EP 每列是 el-scrollbar 组件，滚动条覆盖式、不占布局宽度，列内容宽 = 面板宽/3 = 60px。
//    而 ::before/::after 画横线时按 **180px 全宽** 算 margin:12%。
//    cjxt 用原生 overflow:auto，滚动条占去 10px → 列内容只有 50px、与横线基准错位，
//    表现为「横线每列断一截、列间有缝」。
//    修法：零宽滚动条（滚动能力保留，只是不绘制），列宽回到 60px。
package cjxt

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class TimePickerCssTest {
    // 取出以 selector 开头的所有规则块正文（同 drawer_css_test 的取法，避免字符偏移过脆）
    func ruleBodies(selector: String): String {
        var out = ""
        var from: Int64 = 0
        var searching = true
        while (searching) {
            match (_componentCSS.indexOf(selector, from)) {
                case Some(i) =>
                    let after = i + selector.size
                    let isBoundary = after >= _componentCSS.size ||
                        _componentCSS[after..(after + 1)] == " " ||
                        _componentCSS[after..(after + 1)] == "{" ||
                        _componentCSS[after..(after + 1)] == ","
                    if (!isBoundary) {
                        from = after
                    } else {
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
    public func testTimePanelHasOpaqueBackground(): Unit {
        // ① 没有不透明背景时，::before/::after 的 z-index:-1 会沉到 popper 白底之下
        let body = this.ruleBodies(".el-time-panel")
        @Expect(body.contains("background-color"), true)
        // 必须是实色变量，不能是 transparent/none
        @Expect(body.contains("transparent"), false)
    }

    @TestCase
    public func testTimeSpinnerWrapperHidesNativeScrollbar(): Unit {
        // ② 零宽滚动条：不再占布局宽度，列宽才能等于 面板宽/3
        let body = this.ruleBodies(".el-time-spinner__wrapper")
        @Expect(body.contains("scrollbar-width: none"), true)
        // WebKit 分支：宽度 0
        let webkit = this.ruleBodies(".el-time-spinner__wrapper::-webkit-scrollbar")
        @Expect(webkit.contains("width: 0"), true)
    }

    @TestCase
    public func testTimePanelContentDrawsSelectionLines(): Unit {
        // 前提保护：横线仍由伪元素画（若哪天改成别的实现，这条会提醒同步更新本测试）
        let before = this.ruleBodies(".el-time-panel__content::before")
        @Expect(before.contains("border-top"), true)
        @Expect(before.contains("border-bottom"), true)
        // z-index:-1 是 EP 的设计（沉到内容之下），依赖面板有背景——与①互为因果
        @Expect(before.contains("z-index") || this.ruleBodies(".el-time-panel__content::before, .el-time-panel__content::after").contains("z-index"), true)
    }
}
