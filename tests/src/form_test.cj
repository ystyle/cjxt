package cjxt_tests

import cjxt.*
import cjxt.components.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class FormBindValueTest {
    @TestCase
    public func testFormItemBindValueRequired(): Unit {
        let s = Signal<String>("")
        let item = FormItem([])
            .label("用户名")
            .bindValue({ => s.get() })
            .rule(FormRule(required: true))
        @Expect(item.validate(), false)
        s.set("admin")
        @Expect(item.validate(), true)
    }

    @TestCase
    public func testFormItemBindValuePattern(): Unit {
        let s = Signal<String>("abc")
        let item = FormItem([])
            .bindValue({ => s.get() })
            .rule(FormRule(pattern: "^[a-z]+$"))
        @Expect(item.validate(), true)
        s.set("ABC")
        @Expect(item.validate(), false)
    }

    @TestCase
    public func testFormItemBindValueWithIntGetter(): Unit {
        let n = Signal<Int64>(7)
        // Int64 信号经 getter 转字符串接入校验；getter 每次 validate 动态取值
        let item = FormItem([])
            .bindValue({ => if (n.get() > 0) { n.get().toString() } else { "" } })
            .rule(FormRule(required: true))
        @Expect(item.validate(), true)
        n.set(0)
        @Expect(item.validate(), false)
    }
}
