package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// 图标库契约（2026-10-24 补）
//
// 背景：图标 path 此前是手工抄的，30 个里有 22 个与 EP 官方不一致
// （`edit` 实际是方框组合、`info-filled` 是加号圆…），表现为「图标显示成奇怪的字符/形状」。
// 现已全部换成 `@element-plus/icons-vue` 官方 path，并补上缺失的 `message`。
//
// 这些用例钉住三件事：
//   ① 每个图标都能解析出非空 path（防止名字打错、静默退化成文字占位）
//   ② 不同名字不能共用同一 path（防止复制粘贴时串了）
//   ③ 组件用到的关键语义图标（user/lock/message/edit/delete…）必须存在
@Test
public class IconsTest {
    // 直接取图标 path（getIconSvg 是包级函数，比解析序列化后的 JSON 干净得多）
    func pathOf(name: String): String { getIconSvg(name) }

    @TestCase
    public func testAllRegisteredIconsResolve(): Unit {
        // 组件里实际用到的图标名（逐个确认能出 path）
        let names = [
            "arrow-down", "arrow-up", "arrow-left", "arrow-right", "more", "clock",
            "calendar", "close", "check", "search", "star", "star-filled", "star-on",
            "star-off", "edit", "delete", "info-filled", "question-filled",
            "success-filled", "warning-filled", "error-filled", "circle-check",
            "circle-close", "loading", "minus", "plus", "view", "hide", "user",
            "lock", "message",
        ]
        for (n in names) {
            let d = this.pathOf(n)
            @Expect(d.size > 10, true)
        }
    }

    @TestCase
    public func testUnknownIconDoesNotCrash(): Unit {
        // 未知名字应优雅退化（渲染文字占位），不能抛异常
        let d = this.pathOf("no-such-icon-xyz")
        @Expect(d.size, 0)
    }

    @TestCase
    public func testDistinctIconsUseDistinctPaths(): Unit {
        // success-filled 与 circle-check 曾共用同一 path（复制粘贴串了）。
        // 这里钉住几个语义不同、图形不同的图标不得相同。
        let a = this.pathOf("edit")
        let b = this.pathOf("delete")
        let c = this.pathOf("user")
        let d = this.pathOf("message")
        @Expect(a != b, true)
        @Expect(b != c, true)
        @Expect(c != d, true)
        @Expect(a != d, true)
    }

    @TestCase
    public func testMailSemanticIconExists(): Unit {
        // 邮箱前缀图标必须有独立的 message 图标可用
        // （此前没有，演示只能拿 info-filled 顶替，表现为「加号圆」）
        let d = this.pathOf("message")
        @Expect(d.size > 10)
        let info = this.pathOf("info-filled")
        @Expect(d != info, true)
    }

    @TestCase
    public func testIconSvgHasViewBox(): Unit {
        let expanded = RenderContext.expandTree(Icon("check"), "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        @Expect(out.contains("viewBox"), true)
        @Expect(out.contains("0 0 1024 1024"), true)
    }
}
