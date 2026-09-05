package cjxt

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class SelectLogicTest {
    // ── selectMoveHighlight ──
    @TestCase
    public func testDownFromNone(): Unit {
        @Expect(selectMoveHighlight(-1, 5, 1), 0)
    }

    @TestCase
    public func testUpFromNone(): Unit {
        @Expect(selectMoveHighlight(-1, 5, -1), 4)
    }

    @TestCase
    public func testDownStepAndClamp(): Unit {
        @Expect(selectMoveHighlight(0, 5, 1), 1)
        @Expect(selectMoveHighlight(3, 5, 1), 4)
        @Expect(selectMoveHighlight(4, 5, 1), 4)
        @Expect(selectMoveHighlight(9, 5, 1), 4)
    }

    @TestCase
    public func testUpStepAndClamp(): Unit {
        @Expect(selectMoveHighlight(3, 5, -1), 2)
        @Expect(selectMoveHighlight(1, 5, -1), 0)
        @Expect(selectMoveHighlight(0, 5, -1), 0)
    }

    @TestCase
    public func testSingleOption(): Unit {
        @Expect(selectMoveHighlight(-1, 1, 1), 0)
        @Expect(selectMoveHighlight(0, 1, 1), 0)
        @Expect(selectMoveHighlight(0, 1, -1), 0)
    }

    @TestCase
    public func testEmptyOptions(): Unit {
        @Expect(selectMoveHighlight(-1, 0, 1), -1)
        @Expect(selectMoveHighlight(0, 0, 1), -1)
        @Expect(selectMoveHighlight(2, 0, -1), -1)
    }

    // ── selectHighlightValid ──
    @TestCase
    public func testHighlightValid(): Unit {
        @Expect(selectHighlightValid(-1, 5), false)
        @Expect(selectHighlightValid(0, 5), true)
        @Expect(selectHighlightValid(4, 5), true)
        @Expect(selectHighlightValid(5, 5), false)
        @Expect(selectHighlightValid(0, 0), false)
    }
}
