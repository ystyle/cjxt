package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Timeline 渲染结构测试。
// 对齐点：EP timeline.vue / timeline-item.vue 的 DOM 层级、
// `is-{mode}` 同时挂在 ul 与 li 上、`__node--{size}`/`__node--{type}`/`.is-hollow`、
// timestamp 的 top/bottom 位置、dot 插槽替代默认 node、reverse 逆序。
func renderTimelineJson(t: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(t, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

@Test
public class TimelineTest {
    @TestCase
    public func testStructureMatchesEp(): Unit {
        // ul.el-timeline > li.el-timeline-item > __tail / __node / __wrapper > __content
        let t = Timeline([
            TimelineItem([text("事件一")]).timestamp("2026-10-01")
        ])
        let (json, _) = renderTimelineJson(t)
        @Expect(json.contains("\"ul\""), true)
        @Expect(json.contains("el-timeline is-start"), true)
        @Expect(json.contains("\"li\""), true)
        @Expect(json.contains("el-timeline-item"), true)
        @Expect(json.contains("el-timeline-item__tail"), true)
        @Expect(json.contains("el-timeline-item__node"), true)
        @Expect(json.contains("el-timeline-item__wrapper"), true)
        @Expect(json.contains("el-timeline-item__content"), true)
        @Expect(json.contains("事件一"), true)
    }

    @TestCase
    public func testTimestampDefaultPlacementIsBottom(): Unit {
        // EP timelineItemProps.placement 默认 'bottom' → timestamp 在 content 之后
        let (json, _) = renderTimelineJson(Timeline([
            TimelineItem([text("c")]).timestamp("10:00")
        ]))
        @Expect(json.contains("el-timeline-item__timestamp is-bottom"), true)
        @Expect(json.contains("el-timeline-item__timestamp is-top"), false)
        // bottom 位置：timestamp 出现在 content 之后
        let contentIdx = json.indexOf("el-timeline-item__content")
        let tsIdx = json.indexOf("el-timeline-item__timestamp is-bottom")
        @Expect(contentIdx.isSome(), true)
        @Expect(tsIdx.isSome(), true)
        match ((contentIdx, tsIdx)) {
            case (Some(c), Some(t)) => @Expect(t > c, true)
            case _ => @Expect(false, true)
        }
    }

    @TestCase
    public func testTimestampTopPlacement(): Unit {
        let (json, _) = renderTimelineJson(Timeline([
            TimelineItem([text("c")]).timestamp("10:00").placement(TimelineItemPlacement.Top)
        ]))
        @Expect(json.contains("el-timeline-item__timestamp is-top"), true)
        let tsIdx = json.indexOf("el-timeline-item__timestamp is-top")
        let contentIdx = json.indexOf("el-timeline-item__content")
        match ((tsIdx, contentIdx)) {
            case (Some(t), Some(c)) => @Expect(t < c, true)
            case _ => @Expect(false, true)
        }
    }

    @TestCase
    public func testHideTimestamp(): Unit {
        let (json, _) = renderTimelineJson(Timeline([
            TimelineItem([text("c")]).timestamp("10:00").hideTimestamp()
        ]))
        @Expect(json.contains("el-timeline-item__timestamp"), false)
        // 隐藏的只是时间戳，wrapper/content 照旧
        @Expect(json.contains("el-timeline-item__content"), true)
    }

    @TestCase
    public func testNodeSizeAndTypeClasses(): Unit {
        // EP: ns.em('node', size) + ns.em('node', type) → __node--normal / __node--large / __node--primary
        let (j1, _) = renderTimelineJson(Timeline([TimelineItem([text("a")])]))
        @Expect(j1.contains("el-timeline-item__node--normal"), true)
        // 未设 type 时不得出现空的 `__node--` 残类（EP 的 em() 空 modifier 返回空串）
        @Expect(j1.contains("__node-- "), false)

        let (j2, _) = renderTimelineJson(Timeline([
            TimelineItem([text("a")]).size(TimelineItemSize.Large).itemType(TimelineItemType.Primary)
        ]))
        @Expect(j2.contains("el-timeline-item__node--large"), true)
        @Expect(j2.contains("el-timeline-item__node--primary"), true)
    }

    @TestCase
    public func testAllTypeVariants(): Unit {
        // 五种类型色都要能落到类名上（EP 的 $type 循环：primary/success/warning/danger/info）
        let cases: Array<(TimelineItemType, String)> = [
            (TimelineItemType.Primary, "primary"),
            (TimelineItemType.Success, "success"),
            (TimelineItemType.Warning, "warning"),
            (TimelineItemType.Danger, "danger"),
            (TimelineItemType.Info, "info"),
        ]
        for ((typ, name) in cases) {
            let (json, _) = renderTimelineJson(Timeline([TimelineItem([text("a")]).itemType(typ)]))
            @Expect(json.contains("el-timeline-item__node--${name}"), true)
        }
    }

    @TestCase
    public func testHollowNode(): Unit {
        // EP: ns.is('hollow') → .is-hollow（scss：白底 + 2px 实线边框）
        let (json, _) = renderTimelineJson(Timeline([TimelineItem([text("a")]).hollow()]))
        @Expect(json.contains("is-hollow"), true)
    }

    @TestCase
    public func testColorInlineStyle(): Unit {
        // EP 的 node 上 v-bind style backgroundColor
        let (json, _) = renderTimelineJson(Timeline([
            TimelineItem([text("a")]).color("#ff6600")
        ]))
        @Expect(json.contains("background-color:#ff6600"), true)
    }

    @TestCase
    public func testIconRenderedInsideNode(): Unit {
        let (json, _) = renderTimelineJson(Timeline([
            TimelineItem([text("a")]).icon("check")
        ]))
        @Expect(json.contains("el-timeline-item__icon"), true)
        @Expect(json.contains("\"svg\""), true)
    }

    @TestCase
    public func testDotReplacesDefaultNode(): Unit {
        // 给了 dot 内容就不渲染默认 node（EP 的 v-if/v-else）
        let (json, _) = renderTimelineJson(Timeline([
            TimelineItem([text("a")]).dot([text("★")])
        ]))
        @Expect(json.contains("el-timeline-item__dot"), true)
        @Expect(json.contains("★"), true)
        @Expect(json.contains("el-timeline-item__node"), false)
    }

    @TestCase
    public func testModeClassOnBothUlAndLi(): Unit {
        // EP 的 TimelineItem 从父级 inject 取 mode 并加到自身 li 上——
        // alternate 系列的左右分布完全依赖 li 上这个类，缺了就只有单侧
        let (json, _) = renderTimelineJson(Timeline([
            TimelineItem([text("a")]),
            TimelineItem([text("b")]),
        ]).mode("alternate"))
        @Expect(json.contains("el-timeline is-alternate"), true)
        @Expect(json.contains("el-timeline-item is-alternate"), true)
        // 两个 item 都要带上
        @Expect(countTimelineOccurrences(json, "el-timeline-item is-alternate"), 2)
    }

    @TestCase
    public func testReverseOrder(): Unit {
        let (json, _) = renderTimelineJson(Timeline([
            TimelineItem([text("第一")]),
            TimelineItem([text("第二")]),
        ]).reverse())
        let first = json.indexOf("第二")
        let second = json.indexOf("第一")
        match ((first, second)) {
            case (Some(f), Some(s)) => @Expect(f < s, true)
            case _ => @Expect(false, true)
        }
    }

    @TestCase
    public func testCenterClass(): Unit {
        // EP: { [ns.e('center')]: props.center } → li 上多加 __center
        let (json, _) = renderTimelineJson(Timeline([TimelineItem([text("a")]).center()]))
        @Expect(json.contains("el-timeline-item__center"), true)
    }
}

// 数子串出现次数（String.indexOf 返回 Option<Int64>，需要带起点的重载）
func countTimelineOccurrences(s: String, sub: String): Int64 {
    var count = 0
    var from = 0
    var searching = true
    while (searching) {
        match (s.indexOf(sub, from)) {
            case Some(i) =>
                count += 1
                from = i + sub.size
            case None => searching = false
        }
    }
    count
}
