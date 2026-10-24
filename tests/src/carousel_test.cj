package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Carousel 测试。
// 对齐点：
// - DOM：.el-carousel.el-carousel--<direction> > (.el-carousel__arrow--left/right | .el-carousel__container
//   > .el-carousel__item(+.is-active) | ul.el-carousel__indicators--<direction> > li.el-carousel__indicator(+.is-active))
// - 位移用百分比 translate 表达（相对元素自身尺寸），不依赖容器像素宽度
// - 边界：loop 首尾折返，非 loop 夹到端点
@Test
public class CarouselTest {
    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    func threeSlides(): Carousel {
        Carousel([
            CarouselItem([text("A")]),
            CarouselItem([text("B")]),
            CarouselItem([text("C")]),
        ])
    }

    @TestCase
    public func testBasicStructure(): Unit {
        // 根类 + 容器 + 三个 item + 指示器
        let out = this.json(this.threeSlides())
        @Expect(out.contains("el-carousel el-carousel--horizontal"), true)
        @Expect(out.contains("el-carousel__container"), true)
        @Expect(out.contains("el-carousel__item"), true)
        @Expect(out.contains("el-carousel__indicators el-carousel__indicators--horizontal"), true)
        @Expect(out.contains("el-carousel__indicator el-carousel__indicator--horizontal"), true)
    }

    @TestCase
    public func testFirstItemActiveByDefault(): Unit {
        // 默认激活第 0 项，且只有一个 is-active
        let out = this.json(this.threeSlides())
        @Expect(out.contains("is-active"), true)
        @Expect(countOccurrences(out, "el-carousel__item is-active"), 1)
    }

    @TestCase
    public func testInitialIndexSelectsItem(): Unit {
        // initialIndex(2) → 第 3 项激活
        let out = this.json(this.threeSlides().initialIndex(2))
        @Expect(countOccurrences(out, "el-carousel__item is-active"), 1)
        // 第 0 项相对激活项偏移 -2 个身位
        @Expect(out.contains("translateX(-200%)"), true)
    }

    @TestCase
    public func testBindSignalDrivesActive(): Unit {
        // bind(Signal<Int64>) 驱动当前页：激活项位移归零
        let sig = Signal<Int64>(1)
        let out = this.json(this.threeSlides().bind(sig))
        @Expect(countOccurrences(out, "el-carousel__item is-active"), 1)
        // 激活项（index=1）translateX(0%)；前后两项分别是 -100% / 100%
        @Expect(out.contains("translateX(0%)"), true)
        @Expect(out.contains("translateX(-100%)"), true)
        @Expect(out.contains("translateX(100%)"), true)
    }

    @TestCase
    public func testLoopWrapsIndexAtBothEnds(): Unit {
        // loop（默认 true）：index=-1 → 末项，index=3(=count) → 首项
        let back = this.json(this.threeSlides().bind(Signal<Int64>(-1)))
        @Expect(back.contains("translateX(0%)"), true)
        let forward = this.json(this.threeSlides().bind(Signal<Int64>(3)))
        @Expect(forward.contains("translateX(0%)"), true)
    }

    @TestCase
    public func testNoLoopClampsIndex(): Unit {
        // loop(false)：越界夹到端点（index=9 → 末项 index=2）
        let out = this.json(this.threeSlides().loop(false).bind(Signal<Int64>(9)))
        @Expect(out.contains("translateX(0%)"), true)
        @Expect(countOccurrences(out, "el-carousel__item is-active"), 1)
    }

    @TestCase
    public func testVerticalDirectionTranslatesOnY(): Unit {
        // vertical：类名切换 + translateY 而非 translateX
        let out = this.json(this.threeSlides().direction(CarouselDirection.Vertical).bind(Signal<Int64>(1)))
        @Expect(out.contains("el-carousel--vertical"), true)
        @Expect(out.contains("el-carousel__indicators--vertical"), true)
        @Expect(out.contains("translateY(-100%)"), true)
        @Expect(out.contains("translateX("), false)
    }

    @TestCase
    public func testVerticalHidesArrows(): Unit {
        // EP: arrowDisplay = arrow !== 'never' && !isVertical → 纵向没有箭头
        let out = this.json(this.threeSlides().direction(CarouselDirection.Vertical))
        @Expect(out.contains("el-carousel__arrow"), false)
    }

    @TestCase
    public func testHorizontalRendersArrows(): Unit {
        let out = this.json(this.threeSlides())
        @Expect(out.contains("el-carousel__arrow--left"), true)
        @Expect(out.contains("el-carousel__arrow--right"), true)
    }

    @TestCase
    public func testArrowNeverHidesArrows(): Unit {
        let out = this.json(this.threeSlides().arrow("never"))
        @Expect(out.contains("el-carousel__arrow"), false)
    }

    @TestCase
    public func testHeightSetsContainerStyle(): Unit {
        // height 落在容器内联 style 上（EP 的 containerStyle）
        let out = this.json(this.threeSlides().height("400px"))
        @Expect(out.contains("height:400px"), true)
    }

    @TestCase
    public func testHeightBareNumberBecomesPx(): Unit {
        let out = this.json(this.threeSlides().height("300"))
        @Expect(out.contains("height:300px"), true)
    }

    @TestCase
    public func testIndicatorPositionNoneHidesIndicators(): Unit {
        let out = this.json(this.threeSlides().indicatorPosition("none"))
        @Expect(out.contains("el-carousel__indicators"), false)
    }

    @TestCase
    public func testIndicatorPositionOutside(): Unit {
        let out = this.json(this.threeSlides().indicatorPosition("outside"))
        @Expect(out.contains("el-carousel__indicators--outside"), true)
    }

    @TestCase
    public func testCardTypeAddsCardClassesAndMask(): Unit {
        // card 类型：root 加 --card，item 加 --card，非激活项盖 __mask
        let out = this.json(this.threeSlides().carouselType(CarouselType.Card).bind(Signal<Int64>(1)))
        @Expect(out.contains("el-carousel--card"), true)
        @Expect(out.contains("el-carousel__item--card"), true)
        @Expect(out.contains("el-carousel__mask"), true)
        // 3 项里 2 项非激活 → 2 个遮罩
        @Expect(countOccurrences(out, "el-carousel__mask"), 2)
    }

    @TestCase
    public func testDefaultTypeHasNoCardClass(): Unit {
        // CarouselType.Default.asClass() 返回 ""（EP 无对应类），不得出现 --card
        let out = this.json(this.threeSlides())
        @Expect(out.contains("el-carousel--card"), false)
        @Expect(out.contains("el-carousel__mask"), false)
    }

    @TestCase
    public func testLabelsRenderInIndicators(): Unit {
        // 有 label 时指示器加 --labels，按钮内渲染 label 文本
        let c = Carousel([
            CarouselItem([text("A")]).label("第一"),
            CarouselItem([text("B")]).label("第二"),
        ])
        let out = this.json(c)
        @Expect(out.contains("el-carousel__indicators--labels"), true)
        @Expect(out.contains("第一"), true)
        @Expect(out.contains("第二"), true)
    }

    @TestCase
    public func testNoLabelsKeepsPlainIndicators(): Unit {
        let out = this.json(this.threeSlides())
        @Expect(out.contains("el-carousel__indicators--labels"), false)
    }

    @TestCase
    public func testNonActiveItemHasClickAction(): Unit {
        // 非激活项可点击切换（服务端 action 已注册）
        let out = this.json(this.threeSlides())
        @Expect(out.contains("\"click\""), true)
    }

    @TestCase
    public func testDataNameAttribute(): Unit {
        // name 落到 data-name（EP 的 setActiveItem 按 name 定位）
        let c = Carousel([
            CarouselItem([text("A")]).name("first"),
            CarouselItem([text("B")]).name("second"),
        ])
        let out = this.json(c)
        @Expect(out.contains("data-name"), true)
        @Expect(out.contains("first"), true)
    }

    @TestCase
    public func testEmptyCarouselDoesNotCrash(): Unit {
        // 无 item：不崩，容器仍在
        let out = this.json(Carousel([]))
        @Expect(out.contains("el-carousel__container"), true)
    }

    // ── 纵向指示器的类名必须**只有** --vertical（2026-10-24 修）──────
    // 原缺陷：纵向时追加了 `el-carousel__indicators--right`（该类只有 right:0，
    // 没有垂直居中/竖排语义），于是指示器落在容器下半部、且只露出一半。
    // 旧用例只断言「包含 --vertical」，两个类同时存在时它照样通过 —— 所以没抓到。
    // 这里改为断言「不得出现 --right」。

    @TestCase
    public func testVerticalIndicatorsUseVerticalClassOnly(): Unit {
        let out = this.json(this.threeSlides().direction(CarouselDirection.Vertical).bind(Signal<Int64>(1)))
        @Expect(out.contains("el-carousel__indicators--vertical"), true)
        @Expect(out.contains("el-carousel__indicators--right"), false)
    }

    @TestCase
    public func testHorizontalIndicatorsUseHorizontalClass(): Unit {
        let out = this.json(this.threeSlides().bind(Signal<Int64>(1)))
        @Expect(out.contains("el-carousel__indicators--horizontal"), true)
        @Expect(out.contains("el-carousel__indicators--vertical"), false)
        @Expect(out.contains("el-carousel__indicators--right"), false)
    }
}
