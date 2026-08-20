package cjxt

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class ToastLogicTest {
    @TestCase
    public func testNextToastIdMonotonic(): Unit {
        let a = nextToastId()
        let b = nextToastId()
        @Expect(b > a, true)
        let c = nextToastId()
        @Expect(c > b, true)
    }

    @TestCase
    public func testToastPushAppend(): Unit {
        let list = ArrayList<Int64>()
        list.add(1)
        let out = toastPush(list, 2)
        @Expect(out.size, 2)
        @Expect(out[0], 1)
        @Expect(out[1], 2)
        // 原列表不变
        @Expect(list.size, 1)
    }

    @TestCase
    public func testToastPushEmpty(): Unit {
        let out = toastPush(ArrayList<Int64>(), 42)
        @Expect(out.size, 1)
        @Expect(out[0], 42)
    }

    @TestCase
    public func testToastRemoveAtValid(): Unit {
        let list = ArrayList<Int64>()
        list.add(1)
        list.add(2)
        list.add(3)
        let out = toastRemoveAt(list, 1)
        @Expect(out.size, 2)
        @Expect(out[0], 1)
        @Expect(out[1], 3)
        @Expect(list.size, 3) // 原列表不变
    }

    @TestCase
    public func testToastRemoveAtOutOfRange(): Unit {
        let list = ArrayList<Int64>()
        list.add(1)
        let out = toastRemoveAt(list, 5)
        @Expect(out.size, 1)
        @Expect(out[0], 1)
        let neg = toastRemoveAt(list, -1)
        @Expect(neg.size, 1)
    }
}
