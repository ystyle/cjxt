package cjxt

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class UploadLogicTest {
    @TestCase
    public func testAppendDedup(): Unit {
        let files = ArrayList<UploadFile>()
        let f1 = UploadFile("a.txt", "/u/a.txt", 10)
        let f2 = UploadFile("b.txt", "/u/b.txt", 20)
        let l1 = uploadAppend(files, f1)
        @Expect(l1.size, 1)
        let l2 = uploadAppend(l1, f2)
        @Expect(l2.size, 2)
        // 重复 url 去重
        let l3 = uploadAppend(l2, UploadFile("a.txt", "/u/a.txt", 99))
        @Expect(l3.size, 2)
        @Expect(l3[0].size, 10) // 原文件保留
    }

    @TestCase
    public func testRemove(): Unit {
        let files = ArrayList<UploadFile>([
            UploadFile("a.txt", "/u/a.txt", 10),
            UploadFile("b.txt", "/u/b.txt", 20),
        ])
        let l1 = uploadRemove(files, "/u/a.txt")
        @Expect(l1.size, 1)
        @Expect(l1[0].name, "b.txt")
        // 删不存在的 → 不变
        let l2 = uploadRemove(files, "/u/x.txt")
        @Expect(l2.size, 2)
    }
}

// ============ WS 二进制帧协议（upload.cj 纯逻辑） ============

@Test
public class UploadProtocolTest {
    @TestCase
    public func testParseBegin(): Unit {
        let raw = "{\"type\":\"upload_begin\",\"id\":\"u1\",\"name\":\"a.txt\",\"size\":10,\"action\":\"h:1:uploaded\"}"
        match (parseUploadBegin(raw)) {
            case Some(b) =>
                @Expect(b.id, "u1")
                @Expect(b.name, "a.txt")
                @Expect(b.size, 10)
                @Expect(b.action, "h:1:uploaded")
            case None => @Expect(false, true)
        }
    }

    @TestCase
    public func testParseBeginStringSize(): Unit {
        // 兼容字符串形式的 size
        let raw = "{\"id\":\"u2\",\"name\":\"b.txt\",\"size\":\"2048\",\"action\":\"h:2:uploaded\"}"
        match (parseUploadBegin(raw)) {
            case Some(b) => @Expect(b.size, 2048)
            case None => @Expect(false, true)
        }
    }

    @TestCase
    public func testParseBeginNumericId(): Unit {
        // 兼容数字形式的 id（JS 未转字符串时 `"id":1`）——线上回归用例
        let raw = "{\"type\":\"upload_begin\",\"id\":1,\"name\":\"z.txt\",\"size\":4,\"action\":\"h:1:uploaded\"}"
        match (parseUploadBegin(raw)) {
            case Some(b) =>
                @Expect(b.id, "1")
                @Expect(b.name, "z.txt")
                @Expect(b.size, 4)
            case None => @Expect(false, true)
        }
    }

    @TestCase
    public func testParseBeginInvalid(): Unit {
        // 缺 id / name / action → None
        @Expect(match (parseUploadBegin("{\"name\":\"a\",\"size\":1,\"action\":\"h\"}")) { case Some(_) => true case None => false }, false)
        @Expect(match (parseUploadBegin("{\"id\":\"u\",\"size\":1,\"action\":\"h\"}")) { case Some(_) => true case None => false }, false)
        @Expect(match (parseUploadBegin("{\"id\":\"u\",\"name\":\"a\",\"size\":1}")) { case Some(_) => true case None => false }, false)
        // size 缺失 / 非数字 → None
        @Expect(match (parseUploadBegin("{\"id\":\"u\",\"name\":\"a\",\"action\":\"h\"}")) { case Some(_) => true case None => false }, false)
        @Expect(match (parseUploadBegin("{\"id\":\"u\",\"name\":\"a\",\"size\":\"x\",\"action\":\"h\"}")) { case Some(_) => true case None => false }, false)
    }

    @TestCase
    public func testFeedCompletes(): Unit {
        let st = UploadState("u", "a.txt", 10, "h", "s")
        @Expect(uploadFeed(st, 4), false)
        @Expect(st.received, 4)
        @Expect(uploadFeed(st, 6), true)
        @Expect(st.received, 10)
    }

    @TestCase
    public func testFeedOverflow(): Unit {
        let st = UploadState("u", "a.txt", 10, "h", "s")
        @Expect(uploadWouldOverflow(st, 11), true)
        @Expect(uploadWouldOverflow(st, 10), false)
        let _ = uploadFeed(st, 5)
        @Expect(uploadWouldOverflow(st, 6), true)
        @Expect(uploadWouldOverflow(st, 5), false)
    }
}
