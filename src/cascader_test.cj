package cjxt

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CascaderLogicTest {
    func region(): ArrayList<CascaderNode> {
        let zhejiang = CascaderNode("浙江", "zj", ArrayList<CascaderNode>([
            CascaderNode("杭州", "hz", ArrayList<CascaderNode>([
                CascaderNode("西湖区", "xh"),
                CascaderNode("滨江区", "bj"),
            ])),
            CascaderNode("宁波", "nb"),
        ]))
        let jiangsu = CascaderNode("江苏", "js")
        ArrayList<CascaderNode>([zhejiang, jiangsu])
    }

    @TestCase
    public func testColumns(): Unit {
        let opts = region()
        // 空路径 → 只有根列
        let c0 = cascaderColumns(opts, ArrayList<String>())
        @Expect(c0.size, 1)
        @Expect(c0[0].size, 2)
        // activePath=[浙江] → 两列（根 + 浙江的子）
        let p1 = ArrayList<String>()
        p1.add("zj")
        let c1 = cascaderColumns(opts, p1)
        @Expect(c1.size, 2)
        @Expect(c1[1].size, 2) // 杭州/宁波
        // activePath=[浙江,杭州] → 三列
        let p2 = cascaderAppend(p1, "hz")
        let c2 = cascaderColumns(opts, p2)
        @Expect(c2.size, 3)
        @Expect(c2[2].size, 2) // 西湖区/滨江区
    }

    @TestCase
    public func testPathLabels(): Unit {
        let opts = region()
        let sel = ArrayList<String>()
        sel.add("zj")
        sel.add("hz")
        sel.add("xh")
        let labels = cascaderPathLabels(opts, sel)
        @Expect(labels.size, 3)
        @Expect(labels[0], "浙江")
        @Expect(labels[1], "杭州")
        @Expect(labels[2], "西湖区")
    }

    @TestCase
    public func testAppend(): Unit {
        let p = ArrayList<String>()
        let p1 = cascaderAppend(p, "a")
        @Expect(p1.size, 1)
        @Expect(p1[0], "a")
        let p2 = cascaderAppend(p1, "b")
        @Expect(p2.size, 2)
        @Expect(p2[1], "b")
        // 原 path 不变
        @Expect(p.size, 0)
    }

    @TestCase
    public func testIsLeaf(): Unit {
        let opts = region()
        @Expect(opts[0].isLeaf(), false)  // 浙江有子
        @Expect(opts[1].isLeaf(), true)   // 江苏叶子
    }
}

// ============ 展示文本（separator 连接 / showAllLevels 末级） ============

@Test
public class CascaderDisplayTest {
    @TestCase
    public func testDefaultSeparator(): Unit {
        let labels = ArrayList<String>(["浙江", "杭州", "西湖区"])
        @Expect(cascaderDisplay(labels, " / ", true), "浙江 / 杭州 / 西湖区")
    }

    @TestCase
    public func testCustomSeparator(): Unit {
        let labels = ArrayList<String>(["浙江", "杭州"])
        @Expect(cascaderDisplay(labels, " > ", true), "浙江 > 杭州")
    }

    @TestCase
    public func testLastLevelOnly(): Unit {
        let labels = ArrayList<String>(["浙江", "杭州", "西湖区"])
        @Expect(cascaderDisplay(labels, " / ", false), "西湖区")
    }

    @TestCase
    public func testSingleAndEmpty(): Unit {
        let one = ArrayList<String>(["江苏"])
        @Expect(cascaderDisplay(one, " / ", true), "江苏")
        @Expect(cascaderDisplay(ArrayList<String>(), " / ", true), "")
    }
}
