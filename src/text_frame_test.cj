package cjxt

import std.collection.*


// 长文本消息的分片拼接。
//
// 实测踩到：桌面里贴一整份 markdown（约 4.7KB）发给助手，**只有第一段到了**，
// 截断处正好在那一片的末尾，看起来像"模型只收到这些"。
//
// 原因：浏览器/代理会把长消息拆成 TextWebFrame(fin=false) + 若干 Continuation + 末片(fin=true)，
// 而收帧循环只读了第一片。这条用例把拼接逻辑钉住。

class FakeFrameSource <: FrameSource {
    private let frames: ArrayList<Frame>
    private var i: Int64 = 0
    var pongs: Int64 = 0
    var closed: Bool = false

    init(frames: ArrayList<Frame>) {
        this.frames = frames
    }

    public func read(): Frame {
        let f = this.frames[this.i]
        this.i++
        f
    }

    public func pong(payload: Array<UInt8>): Unit { this.pongs++ }
    public func close(): Unit { this.closed = true }
}

func textFrame(text: String, fin: Bool): Frame {
    Frame(FrameKind.Text, text.toArray(), fin)
}

func contFrame(text: String, fin: Bool): Frame {
    Frame(FrameKind.Continuation, text.toArray(), fin)
}

@Test
func textFrame_singleFrameUnchanged() {
    let src = FakeFrameSource(ArrayList<Frame>())
    let got = App.collectText(src, textFrame("你好", true))
    @Expect(got.isSome(), true)
    @Expect(got ?? "", "你好")
}

@Test
func textFrame_fragmentsAreConcatenated() {
    // fin=false 的开头 → 中间若干片 → 末片 fin=true
    let frames = ArrayList<Frame>()
    frames.add(contFrame("中间段", false))
    frames.add(contFrame("末尾段", true))
    let src = FakeFrameSource(frames)
    let got = App.collectText(src, textFrame("开头段", false))
    @Expect(got ?? "", "开头段中间段末尾段")
}

@Test
func textFrame_pingBetweenFragmentsIsAnswered() {
    // 帧间穿插 Ping 时必须回 Pong，否则对端判定连接已死
    let frames = ArrayList<Frame>()
    frames.add(Frame(FrameKind.Ping, Array<UInt8>(), false))
    frames.add(contFrame("尾巴", true))
    let src = FakeFrameSource(frames)
    let got = App.collectText(src, textFrame("头", false))
    @Expect(got ?? "", "头尾巴")
    @Expect(src.pongs, 1)
}

@Test
func textFrame_closeMidStreamAborts() {
    // 收到 Close（对端断了）：不该把半截消息当成完整消息派发出去
    let frames = ArrayList<Frame>()
    frames.add(Frame(FrameKind.Close, Array<UInt8>(), true))
    let src = FakeFrameSource(frames)
    let got = App.collectText(src, textFrame("半截", false))
    @Expect(got.isNone(), true)
    @Expect(src.closed, true)
}

@Test
func textFrame_binaryMidStreamIsRejected() {
    // 分片序列里冒出二进制帧 = 协议错乱，宁可放弃这条消息
    let frames = ArrayList<Frame>()
    frames.add(Frame(FrameKind.Binary, Array<UInt8>(), true))
    let src = FakeFrameSource(frames)
    @Expect(App.collectText(src, textFrame("x", false)).isNone(), true)
}
