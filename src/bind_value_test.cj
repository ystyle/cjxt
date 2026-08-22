// bind 值解析回归测试：readBindValue 必须只取 value 字段的值本身
// （旧实现取到字符串末尾，值带引号/尾部字段，Int64 等强类型绑定
// 直接抛异常崩 WS 连接——Input 的 String 绑定靠 JSON 反序列化巧合剥掉
// 引号才没暴露问题）
package cjxt

import std.convert.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class BindValueTest {
    @TestCase
    public func testBindValuePlain(): Unit {
        // value 是最后一个字段
        let raw = "{\"type\":\"bind\",\"name\":\"b:abc:bind\",\"value\":\"3600\"}"
        @Expect(readBindValue(raw), "3600")
    }

    @TestCase
    public func testBindValueWithTrailingFields(): Unit {
        // value 后面还有字段（旧实现会把这部分一起带进值里）
        let raw = "{\"type\":\"bind\",\"name\":\"b:abc:bind\",\"value\":\"admin\",\"sessionId\":\"S1\"}"
        @Expect(readBindValue(raw), "admin")
    }

    @TestCase
    public func testBindValueChinese(): Unit {
        // 多字节 UTF-8 值（中文）
        let raw = "{\"type\":\"bind\",\"name\":\"b:abc:bind\",\"value\":\"仓颉\"}"
        @Expect(readBindValue(raw), "仓颉")
    }

    @TestCase
    public func testBindValueNumeric(): Unit {
        // Int64 绑定场景：值必须是纯数字（旧实现带引号会导致 Int64.parse 抛异常）
        let raw = "{\"type\":\"bind\",\"name\":\"b:abc:bind\",\"value\":\"86400\",\"sessionId\":\"S1\"}"
        @Expect(readBindValue(raw), "86400")
        let parsed = Int64.parse(readBindValue(raw), radix: 10)
        @Expect(parsed, 86400)
    }

    @TestCase
    public func testBindValueMissing(): Unit {
        @Expect(readBindValue("{\"type\":\"bind\",\"name\":\"x\"}"), "")
    }
}
