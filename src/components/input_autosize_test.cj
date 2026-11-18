package cjxt.components

import std.collection.*
import std.io.ByteBuffer
import stdx.encoding.json.stream.JsonWriter
import cjxt.*

// 自适应高度的文本域：**平时一行，长到三行封顶**。
//
// 固定 rows 的两个极端都不好用：给 1 行长文本看不见自己在写什么，
// 给 5 行则平时空一大块。聊天输入框尤其明显。

func autosizeJson(c: IComponent): String {
    let buf = ByteBuffer()
    let w = JsonWriter(buf)
    c.toJson(w)
    w.flush()
    String.fromUtf8(buf.bytes())
}

@Test
func autosize_rendersTextareaWithSpec() {
    let json = autosizeJson(Input().autosize(minRows: 1, maxRows: 3).render())
    @Expect(json.contains("el-textarea__inner"), true)
    // 前端按 "min,max" 读这对值算高度
    @Expect(json.contains("data-autosize"), true)
    @Expect(json.contains("1,3"), true)
}

@Test
func autosize_clampsMaxBelowMin() {
    // max < min 是调用方的笔误；不该渲染出 "3,1" 让前端算出比一行还矮的框
    let json = autosizeJson(Input().autosize(minRows: 3, maxRows: 1).render())
    @Expect(json.contains("3,3"), true)
}

@Test
func autosize_impliesTextarea() {
    // 不显式写 .textarea() 也要渲染成文本域：autosize 对单行输入框没有意义
    let json = autosizeJson(Input().autosize(minRows: 2, maxRows: 5).render())
    @Expect(json.contains("el-input__inner"), false)
}
