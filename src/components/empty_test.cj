// Empty 默认插图（回归）
//
// 契约：默认插图必须逐元素就是 Element Plus 官方那张（img-empty.vue 的 template），且
//   ① 配色只引用本仓 CSS **真的定义了**的变量 —— 原来写的 `var(--el-fill-color-N)` 在 vendored
//      EP 样式里不存在，var() 解析失败会让 fill 回落到初始值**黑色**（空态变成几块黑方块）；
//   ② 渐变 id 逐实例唯一 —— 写死的 id 在同页多个空态之间会重复（EP 用 useId() 正是为此）；
//   ③ 不留悬空引用 —— EP 源码里 `url(#mask-4-…)` 的 mask 在 defs 中并未定义，翻译时不能照抄。
package cjxt.components

import cjxt.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// 默认插图的原始标记（renderDefaultSvg 把标记放在 VNode 的 innerHTML 属性上）
func defaultEmptySvg(e: Empty): String {
    match (e.renderDefaultSvg()) {
        case v: VNode =>
            match (v._attrs) {
                case Some(m) =>
                    match (m.get("innerHTML")) {
                        case Some(s) => s
                        case None => ""
                    }
                case None => ""
            }
        case _ => ""
    }
}

// s 里 marker 与 close 之间的全部片段（用于取 id="…" / url(#…) 里的名字）
func betweenAll(s: String, marker: String, close: String): ArrayList<String> {
    let out = ArrayList<String>()
    var from = 0
    var go = true
    while (go) {
        match (s.indexOf(marker, from)) {
            case Some(i) =>
                let vs = i + marker.size
                match (s.indexOf(close, vs)) {
                    case Some(ve) =>
                        out.add(s[vs..ve])
                        from = ve + close.size
                    case None => go = false
                }
            case None => go = false
        }
    }
    out
}

func emptySvgCountOf(s: String, sub: String): Int64 {
    var count = 0
    var idx = 0
    var searching = true
    while (searching) {
        match (s.indexOf(sub, idx)) {
            case Some(pos) =>
                count += 1
                idx = pos + sub.size
            case None => searching = false
        }
    }
    count
}

@Test
public class EmptyImageTest {
    // ① 引用的配色变量必须在组件 CSS 里有定义
    @TestCase
    public func testDefaultSvgReferencesDefinedVariables(): Unit {
        let svg = defaultEmptySvg(Empty())
        @Expect(svg.contains("var(--el-empty-fill-color-1)"), true)
        @Expect(svg.contains("var(--el-fill-color-"), false)
        @Expect(_componentCSS.contains("--el-empty-fill-color-1:"), true)
    }

    // ② 是 EP 官方那张，不是手绘仿制品
    @TestCase
    public func testDefaultSvgIsOfficialIllustration(): Unit {
        let svg = defaultEmptySvg(Empty())
        @Expect(svg.contains("viewBox=\"0 0 79 86\""), true)
        // 官方 2 个渐变（仿制品是 3 个）
        @Expect(emptySvgCountOf(svg, "<linearGradient"), 2)
        // 官方用到 8/9 两个色阶（仿制品只用到 1..7）
        @Expect(svg.contains("var(--el-empty-fill-color-8)"), true)
        @Expect(svg.contains("var(--el-empty-fill-color-9)"), true)
        // 官方独有的图元（仿制品里没有这段坐标）
        @Expect(svg.contains("points=\"7 0 24 0 20 18 7 16.5\""), true)
        // 仿制品的特征不应残留
        @Expect(svg.contains("points=\"58 12 72 12 72 14 58 14\""), false)
        // <use> 已内联为 <rect>，不再依赖 xlink 命名空间
        @Expect(svg.contains("<use"), false)
        @Expect(svg.contains("xlink"), false)
    }

    // ③ 渐变 id 逐实例唯一，且引用指向自己那一份
    @TestCase
    public func testGradientIdsAreUniquePerInstance(): Unit {
        let a = defaultEmptySvg(Empty())
        let b = defaultEmptySvg(Empty())
        let a1 = betweenAll(a, "id=\"el-empty-g1-", "\"")
        let b1 = betweenAll(b, "id=\"el-empty-g1-", "\"")
        @Expect(a1.size, 1)
        @Expect(b1.size, 1)
        @Expect(a1[0] != b1[0], true)
        @Expect(a.contains("url(#el-empty-g1-${a1[0]})"), true)
        @Expect(b.contains("url(#el-empty-g1-${b1[0]})"), true)
    }

    // ④ 不留悬空引用：每个 url(#x) 都要能找到 id="x"
    @TestCase
    public func testNoDanglingSvgReferences(): Unit {
        let svg = defaultEmptySvg(Empty())
        let ids = betweenAll(svg, "id=\"", "\"")
        let refs = betweenAll(svg, "url(#", ")")
        @Expect(refs.size > 0, true)
        for (r in refs) {
            @Expect(ids.contains(r), true)
        }
    }
}
