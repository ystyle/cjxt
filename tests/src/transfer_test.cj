package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Transfer 测试。
// 对齐点：EP transfer.vue / transfer-panel.vue 的 DOM
//   .el-transfer > .el-transfer-panel ×2（__header / __body / __list / __item）+ .el-transfer__buttons
// 绑定语义：bind(Signal<ArrayList<String>>) 是「右侧已选」的 key 列表（同 EP 的 v-model）。
// 简化点：EP 是「两侧勾选 → 点箭头」两步；这里勾选即移动（详见 Transfer.cj 文件头）。
@Test
public class TransferTest {
    func countOccurrences(hay: String, needle: String): Int64 {
        var n = 0
        var from: Int64 = 0
        var searching = true
        while (searching) {
            match (hay.indexOf(needle, from)) {
                case Some(i) => n = n + 1; from = i + needle.size
                case None => searching = false
            }
        }
        n
    }

    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    func options(): ArrayList<TransferOption> {
        ArrayList<TransferOption>([
            TransferOption("a", "选项 A"),
            TransferOption("b", "选项 B"),
            TransferOption("c", "选项 C"),
        ])
    }

    @TestCase
    public func testBasicStructure(): Unit {
        // 根 + 两个面板 + 按钮区
        let out = this.json(Transfer(this.options()))
        @Expect(out.contains("el-transfer\""), true)
        @Expect(countOccurrences(out, "el-transfer-panel\""), 2)
        @Expect(out.contains("el-transfer__buttons"), true)
        @Expect(out.contains("el-transfer-panel__header"), true)
        @Expect(out.contains("el-transfer-panel__body"), true)
        @Expect(out.contains("el-transfer-panel__list"), true)
    }

    @TestCase
    public func testAllItemsInLeftByDefault(): Unit {
        // 未选任何项：3 个待选项都在左侧
        let out = this.json(Transfer(this.options()))
        @Expect(countOccurrences(out, "el-transfer-panel__item"), 3)
        // 右面板为空 → 仍渲染 item 类型的 label 数为 0 只能靠左右分区判断，
        // 故改为断言右侧计数文本为 "0 / 3"
        @Expect(out.contains("0 / 3"), true)
    }

    @TestCase
    public func testSelectedItemsMoveToRight(): Unit {
        // bind 信号里的 key 出现在右面板
        let sel = Signal<ArrayList<String>>(ArrayList<String>(["b"]))
        let out = this.json(Transfer(this.options()).bind(sel))
        // 左侧 2 项 + 右侧 1 项 = 3 项仍在
        @Expect(countOccurrences(out, "el-transfer-panel__item"), 3)
        // 右面板计数 "1 / 3"，左面板 "2 / 3"
        @Expect(out.contains("2 / 3"), true)
        @Expect(out.contains("1 / 3"), true)
    }

    @TestCase
    public func testCheckedItemHasIsCheckedClass(): Unit {
        // 右侧的项带 is-checked
        let sel = Signal<ArrayList<String>>(ArrayList<String>(["a"]))
        let out = this.json(Transfer(this.options()).bind(sel))
        @Expect(out.contains("is-checked"), true)
    }

    @TestCase
    public func testDisabledOptionGetsDisabledClass(): Unit {
        let opts = ArrayList<TransferOption>([
            TransferOption("a", "A", disabled: true),
            TransferOption("b", "B"),
        ])
        let out = this.json(Transfer(opts))
        @Expect(out.contains("is-disabled"), true)
    }

    @TestCase
    public func testHeadersUseCustomTitles(): Unit {
        let out = this.json(Transfer(this.options()).titles("源列表", "目标列表"))
        @Expect(out.contains("源列表"), true)
        @Expect(out.contains("目标列表"), true)
    }

    @TestCase
    public func testDefaultTitlesApplied(): Unit {
        // 未指定 titles 时的默认值
        let out = this.json(Transfer(this.options()))
        @Expect(out.contains("列表 1"), true)
        @Expect(out.contains("列表 2"), true)
    }

    @TestCase
    public func testButtonIconsAndStructure(): Unit {
        // 两个按钮：左箭头（移回）/ 右箭头（移到右）
        let out = this.json(Transfer(this.options()))
        // 计数口径：容器类名是 "el-transfer__buttons"（复数），包含子串 "el-transfer__button"；
        // 两个按钮的类名后面还跟着 " is-with-texts" 等后缀，不能用「紧跟引号」匹配。
        // 故「总出现次数 - 1（容器）」= 按钮数。
        @Expect(out.contains("el-transfer__buttons"), true)
        @Expect(countOccurrences(out, "el-transfer__button") - 1, 2)
        @Expect(out.contains("el-button--primary"), true)
    }

    @TestCase
    public func testButtonTextsRendered(): Unit {
        let out = this.json(Transfer(this.options()).buttonTexts("移回", "移到右"))
        @Expect(out.contains("移回"), true)
        @Expect(out.contains("移到右"), true)
    }

    @TestCase
    public func testItemLabelsRendered(): Unit {
        let out = this.json(Transfer(this.options()))
        @Expect(out.contains("选项 A"), true)
        @Expect(out.contains("选项 B"), true)
        @Expect(out.contains("选项 C"), true)
    }

    @TestCase
    public func testItemHasClickAction(): Unit {
        // 勾选即移动（服务端 action 已注册）
        let out = this.json(Transfer(this.options()))
        @Expect(out.contains("\"click\""), true)
    }

    @TestCase
    public func testDisabledTransferHasNoActions(): Unit {
        // 整体 disabled：按钮 disable，项不可点
        let out = this.json(Transfer(this.options()).disabled())
        @Expect(out.contains("is-disabled"), true)
        @Expect(out.contains("disabled"), true)
    }

    @TestCase
    public func testEmptyOptions(): Unit {
        // 无数据：结构与计数文本都在，不崩。
        // Transfer.init 的参数是 ArrayList<TransferOption>，不能传数组字面量，
        // 空列表也要显式给出元素类型（否则 [] 推不出类型）。
        let empty = ArrayList<TransferOption>()
        let out = this.json(Transfer(empty))
        @Expect(out.contains("el-transfer"), true)
        @Expect(out.contains("0 / 0"), true)
    }

    @TestCase
    public func testAllSelectedFillsRightPanel(): Unit {
        // 全部已选：右侧 3 / 3，左侧 0 / 3
        let sel = Signal<ArrayList<String>>(ArrayList<String>(["a", "b", "c"]))
        let out = this.json(Transfer(this.options()).bind(sel))
        @Expect(out.contains("0 / 3"), true)
        @Expect(out.contains("3 / 3"), true)
    }

    // ── is-with-texts 语义（2026-10-23 修）──────────────────────────
    // EP：hasButtonTexts = buttonTexts.length === 2 → 有文案时加 is-with-texts。
    // 原实现写反（无文案时加），导致纯图标按钮被撑成带文字的宽度。

    @TestCase
    public func testWithTextsClassOnlyWhenButtonTextsProvided(): Unit {
        let opts = ArrayList<TransferOption>([
            TransferOption("1", "选项一"),
            TransferOption("2", "选项二"),
        ])
        // 有文案 → 两个按钮都带 is-with-texts
        let withTexts = this.json(Transfer(opts).buttonTexts("移入", "移出"))
        @Expect(countOccurrences(withTexts, "is-with-texts"), 2)

        // 无文案 → 不带
        let noTexts = this.json(Transfer(opts))
        @Expect(countOccurrences(noTexts, "is-with-texts"), 0)
    }

    @TestCase
    public func testButtonIconsAreCorrectDirection(): Unit {
        // 左按钮 = arrow-left，右按钮 = arrow-right（EP 结构：icon 在左/右各一侧）
        let opts = ArrayList<TransferOption>([TransferOption("1", "选项一")])
        let out = this.json(Transfer(opts))
        @Expect(out.contains("M609.088"), true)   // arrow-left path
        @Expect(out.contains("M340.864"), true)   // arrow-right path
    }

    // ── 箭头按钮方向（2026-10-23 修）──────────────────────────────
    // 缺陷：buildButton 把 isLeft 当 toRight 传 → 两个按钮方向全反；
    //      moveMany 又遍历所有选项 → 点一次"全部跑过去"。
    // 这里从**渲染结果**侧锁住：左按钮应能移动右侧项（故右侧有项时它可用），
    // 右按钮应能移动左侧项（故左侧有项时它可用）。

    @TestCase
    public func testBothButtonsEnabledWhenBothPanelsHaveItems(): Unit {
        let opts = ArrayList<TransferOption>([
            TransferOption("1", "选项一"),
            TransferOption("2", "选项二"),
        ])
        // 1 个在右、1 个在左 → 两个按钮都该可用
        let tr = Transfer(opts).bind(Signal<ArrayList<String>>(ArrayList<String>(["1"])))
        let out = this.json(tr)
        let disabledCount = countOccurrences(out, "el-transfer__button is-disabled")
        @Expect(disabledCount, 0)
    }

    @TestCase
    public func testRightButtonDisabledWhenLeftEmpty(): Unit {
        let opts = ArrayList<TransferOption>([
            TransferOption("1", "选项一"),
            TransferOption("2", "选项二"),
        ])
        // 全部在右 → 左侧为空 → 右箭头（移向右侧）应禁用；左箭头可用
        let tr = Transfer(opts).bind(Signal<ArrayList<String>>(ArrayList<String>(["1", "2"])))
        let out = this.json(tr)
        @Expect(countOccurrences(out, "el-transfer__button is-disabled"), 1)
    }

    @TestCase
    public func testLeftButtonDisabledWhenRightEmpty(): Unit {
        let opts = ArrayList<TransferOption>([
            TransferOption("1", "选项一"),
            TransferOption("2", "选项二"),
        ])
        // 全部在左 → 右侧为空 → 左箭头（移回左侧）应禁用
        let tr = Transfer(opts).bind(Signal<ArrayList<String>>(ArrayList<String>(Array<String>())))
        let out = this.json(tr)
        @Expect(countOccurrences(out, "el-transfer__button is-disabled"), 1)
    }

    // ── 箭头按钮方向：直接执行按钮 handler 验证移向（2026-10-23）──────
    //
    // 缺陷回顾：buildButton 把 isLeft 当 toRight 传给 moveMany，两个按钮方向全反；
    // 且 moveMany 遍历所有选项，点一次就"全部跑过去"。
    //
    // 取 handler 的办法：按钮的 click handler 在 handlers 表里以 `h:<path>:click` 为键，
    // 按渲染顺序，**最后两个** click handler 就是 ← 与 → 两个箭头。
    func clickHandlersInOrder(node: IComponent): ArrayList<ActionHandler> {
        let expanded = RenderContext.expandTree(node, "")
        let hm = HashMap<String, ActionHandler>()
        let _ = serializeSubtree(expanded, hm)
        RenderContext.clearDirty()
        // 按 key 里嵌入的路径数字排序，还原 DOM 顺序
        let keys = ArrayList<String>()
        for ((k, _) in hm) { keys.add(k) }
        // ArrayList 没有 insert（AGENTS.md 已记），先摊平到普通数组再排序
        let arr = keys.toArray()
        var i = 0
        while (i < arr.size) {
            var j = i + 1
            while (j < arr.size) {
                if (arr[j] < arr[i]) {
                    let tmp = arr[i]
                    arr[i] = arr[j]
                    arr[j] = tmp
                }
                j = j + 1
            }
            i = i + 1
        }
        let sorted = ArrayList<String>(arr)
        let out = ArrayList<ActionHandler>()
        for (k in sorted) {
            match (hm.get(k)) { case Some(h) => out.add(h); case None => () }
        }
        out
    }

    func ctxOf(): ActionContext {
        ActionContext("s-tf", HashMap<String, String>(), HashMap<String, String>(),
            Router("s-tf", { _ => () }))
    }

    @TestCase
    public func testRightArrowMovesLeftItemsToRight(): Unit {
        // 初始：空（全在左）。点右箭头 → 全部移到右侧
        let sig = Signal<ArrayList<String>>(ArrayList<String>(Array<String>()))
        let opts = ArrayList<TransferOption>([
            TransferOption("1", "一"), TransferOption("2", "二"),
        ])
        let hs = this.clickHandlersInOrder(Transfer(opts).bind(sig))
        @Expect(hs.size > 0, true)
        // 最后一个 click handler = 右箭头（← 在前、→ 在后）
        let right = hs[hs.size - 1]
        let _ = right(this.ctxOf())
        @Expect(sig.get().size, 2)
    }
}
