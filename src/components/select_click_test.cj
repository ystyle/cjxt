// Select 点击语义（回归）
//
// 契约一：filterable 的 Select 里，**点击展开只由一个 handler 负责**。
//   曾经的 bug：搜索输入框与 wrapper 都绑了 click，点输入框触发两次 ——
//   先 input 的「打开」，冒泡到 wrapper 又「切换」一次，一开一合净效果为 0。
//   表现：filterable 下拉点了不展开、选项里什么都没有（非 filterable 正常）。
//
// 契约二：展开态可以由调用方从外部持有（bindOpen），
//   否则"每次渲染重建组件"的常规写法会让展开态随着重建被重置。
package cjxt.components

import cjxt.*
import std.collection.*
import std.io.ByteBuffer
import stdx.encoding.json.stream.JsonWriter
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class SelectClickTest {
    @TestCase
    public func filterableBindsClickOnlyOnce(): Unit {
        let sel = Select([
            SelectOption([text("甲")], "a"),
            SelectOption([text("乙")], "b"),
        ]).filterable()
        // 整棵子树里 "click" 这个 action 只能出现 1 次（wrapper 那一个）
        @Expect(countOf(renderJson(sel), "\"click\""), 1)
    }

    @TestCase
    public func plainSelectBindsClickOnlyOnce(): Unit {
        let sel = Select([SelectOption([text("甲")], "a")])
        @Expect(countOf(renderJson(sel), "\"click\""), 1)
    }

    @TestCase
    public func bindOpenRendersExpanded(): Unit {
        // 外部持有展开态：置 true 后渲染结果里应当直接有选项（不依赖组件实例）
        let open = Signal<Bool>(true)
        let value = Signal<String>("")
        let sel = Select([SelectOption([text("甲")], "a")])
            .bind(value)
            .bindOpen(open)
            .filterable()
        @Expect(countOf(renderJson(sel), "el-select-dropdown__item") > 0)
    }

    @TestCase
    public func closedByDefault(): Unit {
        // 默认关闭：渲染结果里不该有选项列表
        let open = Signal<Bool>(false)
        let value = Signal<String>("")
        let sel = Select([SelectOption([text("甲")], "a")])
            .bind(value)
            .bindOpen(open)
        @Expect(countOf(renderJson(sel), "el-select-dropdown__item"), 0)
    }
}

/** 渲染并序列化（序列化会带上 actions，便于断言绑定数量） */
func renderJson(c: IComponent): String {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    c.renderWithScope().toJson(w)
    w.flush()
    buf.flush()
    String.fromUtf8(buf.bytes())
}

/** needle 在 hay 里出现的次数 */
func countOf(hay: String, needle: String): Int64 {
    var n: Int64 = 0
    var i = 0
    while (true) {
        match (hay.indexOf(needle, i)) {
            case Some(at) =>
                n++
                i = at + needle.size
            case None => break
        }
    }
    n
}

/**
 * 回归：分组下拉的选中项在**后面的分组**里时，要能显示出它的 label。
 *
 * 曾经的 bug：findLabel 里 `case g: SelectOptionGroup => return labelInGroup(...)`
 * 在第一个分组就 return 了 —— 选中项属于后面的分组时永远找不到 label，
 * 输入框显示空白（实测：绑定了值、选项里确实有该项，但界面是空的）。
 */
@Test
public class SelectGroupLabelTest {
    @TestCase
    public func selectedItemInSecondGroupShowsLabel(): Unit {
        let two = Select([
            SelectOptionGroup([SelectOption([text("甲")], "a"),
                SelectOption([text("乙")], "b")], "第一组"),
            SelectOptionGroup([SelectOption([text("丙")], "c"),
                SelectOption([text("丁")], "d")], "第二组"),
        ]).bind(Signal<String>("d"))
        let j = renderJson(two)
        // 选中值是 d（在第二组）→ 选中文案应当是「丁」，且**不该**是 placeholder 态。
        // 用 placeholder 类名判断比"文本里出现丁"更可靠（丁 作为选项文本本来就在 JSON 里）。
        @Expect(!j.contains("el-select__placeholder"))
    }

    @TestCase
    public func selectedItemInFirstGroupStillWorks(): Unit {
        let two = Select([
            SelectOptionGroup([SelectOption([text("甲")], "a")], "第一组"),
            SelectOptionGroup([SelectOption([text("丙")], "c")], "第二组"),
        ]).bind(Signal<String>("a"))
        @Expect(!renderJson(two).contains("el-select__placeholder"))
    }
}
