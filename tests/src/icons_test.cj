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

    // ── 全量导入校验（2026-10-24）──────────────────────────────────
    // 图标库已从「手抄 30 个」改为「官方全量 293 + 4 别名 = 296」。
    // 下面几条确保导入是完整的，且没有退化（名字打错、path 空、别名丢失）。

    // 抽样若干官方图标（覆盖不同类别：方向、状态、对象、媒体）
    func sampleNames(): Array<String> {
        [
            "arrow-down", "arrow-up", "arrow-left", "arrow-right",
            "arrow-down-bold", "circle-check", "circle-check-filled",
            "success-filled", "warning-filled", "info-filled",
            "message", "user", "lock", "search", "star",
            "delete", "edit", "view", "hide", "loading",
            "add-location", "aim", "alarm-clock", "apple", "bell",
        ]
    }

    @TestCase
    public func testImportedIconsAllResolve(): Unit {
        for (n in this.sampleNames()) {
            let d = getIconSvg(n)
            @Expect(d.size > 10, true)
        }
    }

    @TestCase
    public func testAliasesStillWork(): Unit {
        // 历史调用点用的是这几个别名，导入全量后必须仍然可用且指向官方图形。
        // 注意 `more` 不是别名——它是官方自带的图标，与 `more-filled` 图形不同。
        @Expect(getIconSvg("star-on") == getIconSvg("star-filled"), true)
        @Expect(getIconSvg("star-off") == getIconSvg("star"), true)
        @Expect(getIconSvg("error-filled") == getIconSvg("circle-close"), true)
    }

    @TestCase
    public func testIconLibraryIsLarge(): Unit {
        // 防止意外回退成「只有几个图标」：抽样 25 个全部命中，足以说明是全量导入
        var hit = 0
        for (n in this.sampleNames()) {
            if (getIconSvg(n).size > 10) { hit = hit + 1 }
        }
        @Expect(hit, 25)
    }

    @TestCase
    public func testNoDuplicatePathAmongKeyIcons(): Unit {
        // 历史缺陷：success-filled / error-filled / circle-check 共用同一 path
        let paths = [
            getIconSvg("success-filled"), getIconSvg("error-filled"),
            getIconSvg("circle-check"), getIconSvg("warning-filled"),
            getIconSvg("info-filled"),
        ]
        var i = 0
        while (i < paths.size) {
            var j = i + 1
            while (j < paths.size) {
                @Expect(paths[i] != paths[j], true)
                j = j + 1
            }
            i = i + 1
        }
    }
}
