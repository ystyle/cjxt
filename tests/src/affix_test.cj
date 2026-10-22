package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Affix 渲染结构测试。
// 对齐点：EP affix.vue 的 `.el-affix` 容器；position/offset/zIndex 的落地方式。
//
// 本仓的 Affix **不是** EP 那套 JS 滚动测量，而是 CSS position: sticky（见 Affix.cj 文件头）。
// 因此断言的落脚点是「定位方式 + 吸附边 + offset 距离」这三件事，而不是 EP 的
// `.el-affix--fixed`（那是运行时「此刻已吸附」状态类，与静态 sticky 不是同一回事）。
func renderAffixJson(t: IComponent): String {
    let expanded = RenderContext.expandTree(t, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    json
}

@Test
public class AffixTest {
    @TestCase
    public func testBasicStructure(): Unit {
        let json = renderAffixJson(Affix([text("工具栏")]))
        @Expect(json.contains("el-affix"), true)
        @Expect(json.contains("\"div\""), true)
        @Expect(json.contains("工具栏"), true)
        // data 标记供前端/业务 CSS 识别（将来接滚动监听时按它挂）
        @Expect(json.contains("data-affix"), true)
    }

    @TestCase
    public func testDefaultIsStickyTopZero(): Unit {
        // 默认 position=Fixed + offset=0 → sticky 吸附在 top:0
        let json = renderAffixJson(Affix([text("bar")]))
        @Expect(json.contains("position:sticky"), true)
        @Expect(json.contains("top:0px"), true)
        @Expect(json.contains("data-affix-position"), true)
        @Expect(json.contains("\"fixed\""), true)
    }

    @TestCase
    public func testOffsetMovesAdsorbEdge(): Unit {
        // EP offset：吸附时到视口边缘的距离 → 内联 top 像素值
        let json = renderAffixJson(Affix([text("bar")]).offset(64))
        @Expect(json.contains("top:64px"), true)

        let json0 = renderAffixJson(Affix([text("bar")]).offset(0))
        @Expect(json0.contains("top:0px"), true)
    }

    @TestCase
    public func testAbsolutePositionIsNotSticky(): Unit {
        // AffixPosition.Absolute = 相对已定位祖先固定、不跟随滚动
        let json = renderAffixJson(Affix([text("bar")]).position(AffixPosition.Absolute))
        @Expect(json.contains("position:absolute"), true)
        @Expect(json.contains("position:sticky"), false)
        @Expect(json.contains("\"absolute\""), true)
    }

    @TestCase
    public func testBottomAnchorsToBottomEdge(): Unit {
        // EP position="bottom" → 吸附到容器底部；这里换成 bottom() 开关（position 已被定位方式占用）
        let json = renderAffixJson(Affix([text("bar")]).bottom().offset(20))
        @Expect(json.contains("bottom:20px"), true)
        @Expect(json.contains("top:"), false)
    }

    @TestCase
    public func testZIndexWritable(): Unit {
        let json = renderAffixJson(Affix([text("bar")]).zIndex(2000))
        @Expect(json.contains("z-index:2000"), true)
        // 默认 100（与 EP affixProps zIndex 默认值一致）
        let jsonDefault = renderAffixJson(Affix([text("bar")]))
        @Expect(jsonDefault.contains("z-index:100"), true)
    }

    @TestCase
    public func testTargetSelectorExposedAsDataAttr(): Unit {
        // EP target 是滚动容器选择器；sticky 下由浏览器自动选滚动容器，
        // 但 prop 保留（API 对齐），以 data 属性输出
        let json = renderAffixJson(Affix([text("bar")]).target("#scroller"))
        @Expect(json.contains("data-affix-target"), true)
        @Expect(json.contains("#scroller"), true)
    }

    @TestCase
    public func testStylePassthroughMergedAfterPositioning(): Unit {
        // 调用方样式追加在定位样式之后（后写者胜，业务可覆盖 background 等）
        let json = renderAffixJson(Affix([text("bar")]).offset(10).style("background:red"))
        @Expect(json.contains("position:sticky"), true)
        @Expect(json.contains("top:10px"), true)
        @Expect(json.contains("background:red"), true)
    }
}
