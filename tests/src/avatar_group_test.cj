package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// AvatarGroup 渲染结构测试。
// 对齐点：EP avatar-group.tsx 的 `.el-avatar-group` 容器 + 子 Avatar 原样渲染、
// collapseAvatars/maxCollapseAvatars 的 "+ N" 溢出项（复用 ElAvatar 结构）、
// 组级 size/shape 下发给未单独设置的头像。
func renderAvatarGroupJson(t: IComponent): (String, HashMap<String, ActionHandler>) {
    let expanded = RenderContext.expandTree(t, "")
    let handlerMap = HashMap<String, ActionHandler>()
    let json = serializeSubtree(expanded, handlerMap)
    RenderContext.clearDirty()
    (json, handlerMap)
}

@Test
public class AvatarGroupTest {
    @TestCase
    public func testContainerAndChildren(): Unit {
        // div.el-avatar-group 包住三个 Avatar（scss 用 :not(:first-child) 做叠压）
        let g = AvatarGroup([
            Avatar().children([text("A")]),
            Avatar().children([text("B")]),
            Avatar().children([text("C")]),
        ])
        let (json, _) = renderAvatarGroupJson(g)
        @Expect(json.contains("el-avatar-group"), true)
        @Expect(json.contains("el-avatar"), true)
        @Expect(json.contains("\"A\""), true)
        @Expect(json.contains("\"B\""), true)
        @Expect(json.contains("\"C\""), true)
        // 未开折叠时没有 "+ N"
        @Expect(json.contains("\"+ "), false)
    }

    @TestCase
    public func testNoCollapseWhenUnderMax(): Unit {
        // EP: showCollapseAvatar = collapseAvatars && avatars.length > maxCollapseAvatars
        // 3 个头像、max=5 → 不折叠，全部渲染
        let g = AvatarGroup([
            Avatar().children([text("A")]),
            Avatar().children([text("B")]),
            Avatar().children([text("C")]),
        ]).maxCollapseAvatars(5)
        let (json, _) = renderAvatarGroupJson(g)
        @Expect(json.contains("+ "), false)
        @Expect(json.contains("\"A\""), true)
        @Expect(json.contains("\"C\""), true)
    }

    @TestCase
    public func testCollapseShowsPlusN(): Unit {
        // 5 个头像、max=2 → 显示前 2 个 + "+ 3"
        let g = AvatarGroup([
            Avatar().children([text("A")]),
            Avatar().children([text("B")]),
            Avatar().children([text("C")]),
            Avatar().children([text("D")]),
            Avatar().children([text("E")]),
        ]).maxCollapseAvatars(2)
        let (json, _) = renderAvatarGroupJson(g)
        @Expect(json.contains("el-avatar-group"), true)
        @Expect(json.contains("+ 3"), true)
        // 前两个可见，后三个不下发
        @Expect(json.contains("\"A\""), true)
        @Expect(json.contains("\"B\""), true)
        @Expect(json.contains("\"C\""), false)
        @Expect(json.contains("\"D\""), false)
        @Expect(json.contains("\"E\""), false)
        // 溢出项本身也是 el-avatar（EP 复用 ElAvatar）。
        // 用 probeCountClass 精确匹配类名边界——直接数子串会把 `el-avatar--circle`、
        // `el-avatar-group` 一并算进去（实测 7 而非 3）。
        @Expect(probeCountClass(json, "el-avatar"), 3)
    }

    @TestCase
    public func testCollapseAtExactlyMaxCollapses(): Unit {
        // EP 判据是 avatars.length > maxCollapseAvatars，等于时不折叠
        let g = AvatarGroup([
            Avatar().children([text("A")]),
            Avatar().children([text("B")]),
        ]).maxCollapseAvatars(2)
        let (json, _) = renderAvatarGroupJson(g)
        @Expect(json.contains("+ "), false)
    }

    @TestCase
    public func testDefaultMaxCollapseIsOne(): Unit {
        // EP: maxCollapseAvatars 默认 1
        let g = AvatarGroup([
            Avatar().children([text("A")]),
            Avatar().children([text("B")]),
            Avatar().children([text("C")]),
        ]).collapseAvatars()
        let (json, _) = renderAvatarGroupJson(g)
        @Expect(json.contains("+ 2"), true)
        @Expect(json.contains("\"A\""), true)
        @Expect(json.contains("\"B\""), false)
    }

    @TestCase
    public func testGroupSizeAppliesToChildrenWithoutOwnSize(): Unit {
        // 组级 size 只补齐"自己没设"的头像（EP 的 props.size ?? context.size）
        let a1 = Avatar().children([text("A")])                 // 无 size → 继承组
        let a2 = Avatar().children([text("B")]).size("large")   // 自带 size → 保留
        let g = AvatarGroup([a1, a2]).size("small")
        let (json, _) = renderAvatarGroupJson(g)
        @Expect(json.contains("el-avatar--small"), true)
        @Expect(json.contains("el-avatar--large"), true)
    }

    @TestCase
    public func testNumericGroupSizeUsesCssVar(): Unit {
        // 数字尺寸走 --el-avatar-size（与 Avatar 自身一致）
        let g = AvatarGroup([Avatar().children([text("A")])]).size("32")
        let (json, _) = renderAvatarGroupJson(g)
        @Expect(json.contains("--el-avatar-size:32px"), true)
    }

    @TestCase
    public func testGroupShapeAppliesToChildren(): Unit {
        let g = AvatarGroup([Avatar().children([text("A")])]).shape(AvatarShape.Square)
        let (json, _) = renderAvatarGroupJson(g)
        @Expect(json.contains("el-avatar--square"), true)
        @Expect(json.contains("el-avatar--circle"), false)
    }

    @TestCase
    public func testCollapseAvatarInheritsSizeAndClass(): Unit {
        let g = AvatarGroup([
            Avatar().children([text("A")]),
            Avatar().children([text("B")]),
        ]).maxCollapseAvatars(1).size("small").collapseClass("my-plus")
        let (json, _) = renderAvatarGroupJson(g)
        @Expect(json.contains("my-plus"), true)
        @Expect(json.contains("+ 1"), true)
        // 溢出项也吃组级 size 修饰类：可见 1 + 溢出 1 = 2 个 el-avatar--small
        @Expect(countToken(json, "el-avatar--small"), 2)
    }

    @TestCase
    public func testCollapseTooltipTitle(): Unit {
        // EP 用 ElTooltip 展示被折叠头像；这里退化为原生 title（不引入客户端组件）
        let g = AvatarGroup([
            Avatar().children([text("A")]),
            Avatar().children([text("B")]),
            Avatar().children([text("C")]),
        ]).maxCollapseAvatars(1).collapseAvatarsTooltip()
        let (json, _) = renderAvatarGroupJson(g)
        @Expect(json.contains("\"title\""), true)
        @Expect(json.contains("还有 2 个头像"), true)

        // 未开启 tooltip 时不得有 title
        let g2 = AvatarGroup([
            Avatar().children([text("A")]),
            Avatar().children([text("B")]),
            Avatar().children([text("C")]),
        ]).maxCollapseAvatars(1)
        let (j2, _) = renderAvatarGroupJson(g2)
        @Expect(j2.contains("\"title\""), false)
    }
}

// 统计 JSON 里某个 class token 出现次数（按空格/引号边界，避免 el-avatar 命中 el-avatar--small）
func countToken(s: String, token: String): Int64 {
    var count = 0
    var from = 0
    var go = true
    while (go) {
        match (s.indexOf(token, from)) {
            case Some(i) =>
                let beforeOk = i == 0 || s[i - 1..i] == " " || s[i - 1..i] == "\""
                let afterAt = i + token.size
                let afterOk = afterAt >= s.size || s[afterAt..afterAt + 1] == " " || s[afterAt..afterAt + 1] == "\""
                if (beforeOk && afterOk) { count += 1 }
                from = afterAt
            case None => go = false
        }
    }
    count
}
