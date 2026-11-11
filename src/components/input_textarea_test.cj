// Input 的 textarea 分支：**bind 必须真的接上**。
//
// 曾经的 bug：`renderTextarea` 里
//
//     let inner = VNode("textarea", [], attrs: Some(attrs))
//     match (this._signal) {
//         case Some(s) => inner.bind(s)     // ← 返回值被丢掉
//         case None => inner
//     }
//     VNode("div", [inner], ...)            // ← 用的还是没绑过的那个
//
// `VNode` 是不可变的，`bind` 返回**新节点**。丢掉返回值的结果是 textarea
// 既没有初值、也没有 `data-bind-id`：界面上已有的提示词显示不出来，
// 改了也存不进去（根本没有 bind 消息发给服务端），而两侧都不报错。
//
// 这条用例钉住渲染出来的节点上确实带着这两样东西。
package cjxt.components

import cjxt.*
import std.collection.*
import std.io.ByteBuffer
import stdx.encoding.json.stream.JsonWriter
import std.unittest.*
import std.unittest.testmacro.*

func inputRenderJson(c: IComponent): String {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    c.renderWithScope().toJson(w)
    w.flush()
    buf.flush()
    String.fromUtf8(buf.bytes())
}

@Test
public class InputTextareaTest {
    @TestCase
    public func textareaBoundCarriesValueAndBindId(): Unit {
        let s = Signal<String>("旧提示词")
        let json = inputRenderJson(Input().bind(s).textarea())
        // ① 初值要下发：否则"已有的内容"永远显示不出来
        @Expect(json.contains("\"value\":\"旧提示词\""), true)
        // ② 绑定要挂上：否则输入不会回传，保存时用的还是旧值
        @Expect(json.contains("data-bind-id"), true)
    }

    @TestCase
    public func textareaWithoutBindHasNoBindId(): Unit {
        // 没调 bind 的时候不该凭空长出一个绑定
        let json = inputRenderJson(Input().textarea().placeholder("随便写点"))
        @Expect(json.contains("data-bind-id"), false)
        @Expect(json.contains("随便写点"), true)
    }
}
