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
