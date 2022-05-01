discard """
"""

import ../../src/trackerboy/editing
import utils
import ../unittest_wrapper

unittests:
    suite "PatternSelection":

        test "clamp":
            const startingSelection = initPatternSelection(a(0, 0, selNote), a(36, 1, selInstrument))
            var sel = startingSelection

            sel.clamp(64)
            check sel == startingSelection

            sel.clamp(32)
            check sel != startingSelection
            check sel == initPatternSelection(a(0, 0, selNote), a(32, 1, selInstrument))

        test "translate":
            const sample = initPatternSelection(a(0, 0, selNote), a(1, 0, selEffect3))
            var sel = sample
            sel.translate(1)
            check sel == initPatternSelection(a(1, 0, selNote), a(2, 0, selEffect3))
            
            # check clamping when out of bounds
            sel = sample
            sel.translate(-100)
            check sel == initPatternSelection(a(0, 0, selNote), a(0, 0, selEffect3))

            sel = sample
            sel.translate(300)
            check sel == initPatternSelection(a(high(ByteIndex), 0, selNote), a(high(ByteIndex), 0, selEffect3))

        test "iter":

            type TestData = object
                name: string
                input: PatternSelection
                expectedRows: Slice[int]
                expectedTracks: Slice[int]
                expectedColumns: int

            const tests = [
                TestData(
                    name: "empty",
                    input: default(PatternSelection),
                    expectedRows: 0..0,
                    expectedTracks: 0..0,
                    expectedColumns: 1
                ),
                TestData(
                    name: "single column",
                    input: initPatternSelection(a(1, 0, selNote), a(6, 0, selNote)),
                    expectedRows: 1..6,
                    expectedTracks: 0..0,
                    expectedColumns: 1
                ),
                TestData(
                    name: "multiple columns, single track",
                    input: initPatternSelection(a(10, 3, selInstrument), a(1, 3, selEffect3)),
                    expectedRows: 1..10,
                    expectedTracks: 3..3,
                    expectedColumns: 4
                ),
                TestData(
                    name: "single column, multiple tracks",
                    input: initPatternSelection(a(3, 1, selEffect2), a(3, 3, selEffect2)),
                    expectedRows: 3..3,
                    expectedTracks: 1..3,
                    expectedColumns: 11
                ),
                TestData(
                    name: "multiple columns, multiple tracks",
                    input: initPatternSelection(a(1, 3, selEffect3), a(10, 1, selInstrument)),
                    expectedRows: 1..10,
                    expectedTracks: 1..3,
                    expectedColumns: 14
                )
            ]
            
            for testcase in tests:
                checkpoint testcase.name
                var iter = testcase.input.iter()
                check iter.rows() == testcase.expectedRows
                check iter.tracks() == testcase.expectedTracks
                var columnCount = 0
                for track in iter.tracks():
                    let columnIter = iter.columnIter(track)
                    for column in TrackSelect:
                        if columnIter.hasColumn(column):
                            inc columnCount

                check columnCount == testcase.expectedColumns

        test "contains":
            let first = a(10, 1, selInstrument)
            let last = a(32, 2, selEffect2)
            let sel = initPatternSelection(first, last)
            check sel.contains(first)
            check sel.contains(last)
            check sel.contains(a(16, 1, selEffect1))
            check not sel.contains(a(9, 1, selInstrument))
            check not sel.contains(a(36, 1, selInstrument))
            check not sel.contains(a(16, 1, selNote))
            check not sel.contains(a(16, 2, selEffect3))