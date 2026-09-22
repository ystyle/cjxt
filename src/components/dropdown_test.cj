// Dropdown 命令回调（回归）
//
// 契约：菜单项点击本身就是一个 action，框架给出的 ActionContext 必须能交到调用方手里 ——
// 按命令做事的地方要**按操作者**鉴权 / 写审计（谁点的这一项）。只给命令字符串的话，调用方
// 要么拿不到 ctx，要么自己再拼一份下拉结构。
package cjxt.components

import cjxt.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// 渲染一棵树并收集其中所有 action handler（key 为事件名或 handler id）
func dropdownHandlers(root: IComponent): ArrayList<ActionHandler> {
    let out = ArrayList<ActionHandler>()
    collectDropdownHandlers(root, out)
    out
}

func collectDropdownHandlers(c: IComponent, out: ArrayList<ActionHandler>): Unit {
    match (c) {
        case v: VNode =>
            match (v._handlers) {
                case Some(h) => for ((_, fn) in h) { out.add(fn) }
                case None => ()
            }
            for (child in v._children) { collectDropdownHandlers(child, out) }
        case f: FragmentNode => for (child in f._children) { collectDropdownHandlers(child, out) }
        case comp: Component =>
            // 组件级事件挂在渲染结果的根 VNode 上，展开后再收一遍
            collectDropdownHandlers(RenderContext.expandTree(comp, ""), out)
        case _ => ()
    }
}

func dropdownCtx(sid: String): ActionContext {
    ActionContext(sid, HashMap<String, String>(), HashMap<String, String>(), Router(sid, { _ => () }))
}

// 回调里要记状态：闭包只能捕获**不可变**变量，所以用一个小对象当探针（引用类型）
class DropdownProbe {
    var cmd: String = ""
    var sid: String = ""
    var plain: Bool = false
}

@Test
public class DropdownCommandTest {
    // onCommandCtx 拿到 ctx 与命令；同时设了 onCommand 时以 ctx 版优先
    @TestCase
    public func testCommandCtxReceivesContextAndCommand(): Unit {
        let probe = DropdownProbe()
        let dd = Dropdown(text("菜单"))
            .menu([
                DropdownItem().content("详情").command("detail"),
                DropdownItem().content("删除").command("del"),
            ])
            .onCommand({ _ => probe.plain = true })
            .onCommandCtx({ ctx, cmd =>
                probe.sid = ctx.sessionId
                probe.cmd = cmd
            })
        let tree = RenderContext.expandTree(dd, "")
        let ctx = dropdownCtx("s-1")
        for (h in dropdownHandlers(tree)) {
            let _ = h(ctx)
        }
        @Expect(probe.cmd != "", true)
        @Expect(probe.sid, "s-1")
        @Expect(probe.plain, false)
    }

    // 只用 onCommand（旧用法）时照样被调用
    @TestCase
    public func testPlainCommandStillWorks(): Unit {
        let probe = DropdownProbe()
        let dd = Dropdown(text("菜单"))
            .menu([DropdownItem().content("详情").command("detail")])
            .onCommand({ cmd => probe.cmd = cmd })
        let tree = RenderContext.expandTree(dd, "")
        let ctx = dropdownCtx("s-2")
        for (h in dropdownHandlers(tree)) {
            let _ = h(ctx)
        }
        @Expect(probe.cmd, "detail")
    }
}
