package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// DatePicker 清空契约（2026-10-23 补）
//
// 背景（真实缺陷）：点 × 后服务端 `setValue("")` 生效、不再输出 `value` 属性，
// 但前端 applyAttrs 只在「有 value 属性」时写 `el.value`、且遍历移除属性时
// 对 `value` 直接 `continue` —— 于是「服务端已清空、界面仍显示旧值」。
// 修复在前端（`valueMissing` 分支），这里从**渲染产物**侧锁住契约：
// 清空后不得再输出该 input 的 value 属性。
@Test
public class DatePickerTest {
    func json(node: IComponent): String {
        let expanded = RenderContext.expandTree(node, "")
        let handlerMap = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, handlerMap)
        RenderContext.clearDirty()
        out
    }

    @TestCase
    public func testValueRenderedWhenSignalHasValue(): Unit {
        let sig = Signal<String>("2026-08-05")
        let out = this.json(DatePicker().bind(sig).clearable())
        @Expect(out.contains("2026-08-05"), true)
    }

    @TestCase
    public func testNoValueAttrAfterClear(): Unit {
        // 信号置空 = 清空。产物里不应再有该日期的 value
        let sig = Signal<String>("2026-08-05")
        let dp = DatePicker().bind(sig).clearable()
        @Expect(this.json(dp).contains("2026-08-05"), true)
        sig.set("")
        let after = this.json(dp)
        @Expect(after.contains("2026-08-05"), false)
    }

    @TestCase
    public func testClearIconOnlyWhenClearableAndHasValue(): Unit {
        // × 只在 clearable + 有值时出现（EP 语义）
        let sig = Signal<String>("2026-08-05")
        let withClear = this.json(DatePicker().bind(sig).clearable())
        @Expect(withClear.contains("el-input__suffix"), true)

        let noClear = this.json(DatePicker().bind(sig))
        @Expect(noClear.contains("el-input__suffix"), false)
    }

    @TestCase
    public func testClearIconHidesWhenValueEmpty(): Unit {
        let sig = Signal<String>("")
        let out = this.json(DatePicker().bind(sig).clearable())
        @Expect(out.contains("el-input__suffix"), false)
    }

    @TestCase
    public func testEditorIsRelativeForClearPositioning(): Unit {
        // × 用 absolute right:8px 定位，依赖 editor 的 position:relative；
        // 丢失会让 × 跑到容器外（历史踩过）
        let out = this.json(DatePicker().bind(Signal<String>("2026-08-05")).clearable())
        @Expect(out.contains("position:relative"), true)
    }

    @TestCase
    public func testClearHandlerResetsSignal(): Unit {
        // 取 clear 的 action 执行，信号应被置空
        let sig = Signal<String>("2026-08-05")
        let dp = DatePicker().bind(sig).clearable()
        let expanded = RenderContext.expandTree(dp, "")
        let hm = HashMap<String, ActionHandler>()
        let out = serializeSubtree(expanded, hm)
        RenderContext.clearDirty()
        // handler 已收集到 hm（点击 × 走这条链路）
        @Expect(hm.size > 0, true)
        // 执行所有 handler（此组件只有一个可点击动作：clear）
        for ((_, h) in hm) {
            let ctx = ActionContext("s-dp", HashMap<String, String>(), HashMap<String, String>(),
                Router("s-dp", { _ => () }))
            let _ = h(ctx)
        }
        @Expect(sig.get(), "")
    }
}
