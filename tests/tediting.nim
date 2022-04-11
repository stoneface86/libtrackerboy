{.used.}

import std/unittest
import std/with

import trackerboy/[common, data, editing, notes]

template a(r: int, t: int, c: TrackSelect): PatternAnchor =
    PatternAnchor(row: r, track: t, column: c)

static:
    assert not isEffect(selNote)
    assert not isEffect(selInstrument)
    assert isEffect(selEffect1)
    assert isEffect(selEffect2)
    assert isEffect(selEffect3)

static:
    assert selNote.effectNumber == 0
    assert selInstrument.effectNumber == 0
    assert selEffect1.effectNumber == 0
    assert selEffect2.effectNumber == 1
    assert selEffect3.effectNumber == 2

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

suite "PatternClip":

    const patternSize = 8
    const wholePattern = initPatternSelection(
        a(0, low(ChannelId), low(TrackSelect)),
        a(patternSize - 1, high(ChannelId), high(TrackSelect))
    )

    proc getSamplePattern(): Pattern = 
        result = Pattern(
            tracks: [
                newTrack(patternSize),
                newTrack(patternSize),
                newTrack(patternSize),
                newTrack(patternSize)
            ]
        )

        # sample pattern data
        #      mCh1Track    mEmptyTrack  mEmptyTrack  mCh4Track
        # 00 | G-5 00 ... | ... .. ... | ... .. ... | G-6 01 ... |
        # 01 | ... .. ... | ... .. ... | ... .. ... | ... .. ... |
        # 02 | ... .. ... | ... .. ... | ... .. ... | G-6 01 G03 |
        # 03 | ... .. ... | ... .. ... | ... .. ... | ... .. ... |
        # 04 | B-5 00 ... | ... .. ... | ... .. ... | G-6 02 ... |
        # 05 | ... .. ... | ... .. ... | ... .. ... | ... .. ... |
        # 06 | ... .. ... | ... .. ... | ... .. ... | G-6 01 G03 |
        # 07 | ... .. ... | ... .. ... | ... .. ... | ... .. ... |

        proc setTrack0(track: var Track) =
            with track:
                setNote(0, "G-5".note)
                setInstrument(0, 0)
                setNote(4, "B-5".note)
                setInstrument(4, 0)
        setTrack0(result.tracks[0][])

        proc setTrack3(track: var Track) =
            with track:
                setNote(0, "G-6".note)
                setInstrument(0, 1)
                setNote(2, "G-6".note)
                setInstrument(2, 1)
                setEffect(2, 0, etDelayedNote, 3)
                setNote(4, "G-6".note)
                setInstrument(4, 2)
                setNote(6, "G-6".note)
                setInstrument(6, 1)
                setEffect(6, 0, etDelayedNote, 3)
        setTrack3(result.tracks[3][])

    setup:
        var clip: PatternClip

    test "has no data on init":
        check not clip.hasData()

    test "save raises RangeDefect on invalid selection":
        proc mkInput(a1, a2: PatternAnchor, name: string): auto =
            (
                data: initPatternSelection(a1, a2),
                name: name
            )
        const inputs = [
            mkInput(a(-1, 0, selNote), a(4, 0, selNote), "negative row index"),
            mkInput(a(1, 0, selNote), a(patternSize, 0, selNote), "row exceeds pattern"),
            mkInput(a(0, 2, selInstrument), a(4, -2, selNote), "negative track index"),
            mkInput(a(0, high(ChannelId) + 2, selEffect1), a(0, 0, selEffect2), "track exceeds pattern")
        ]
        let pattern = getSamplePattern().toCPattern
        for input in inputs:
            checkpoint input.name
            expect RangeDefect:
                clip.save(pattern, input.data)

    
    test "persistance":
        let pattern = getSamplePattern().toCPattern
        clip.save(pattern, wholePattern)
        check clip.hasData()

        var copy = Pattern(tracks: [
            newTrack(patternSize),
            newTrack(patternSize),
            newTrack(patternSize),
            newTrack(patternSize)
        ])
        clip.restore(copy)
        check pattern.tracks[0][] == copy.tracks[0][]
        check pattern.tracks[1][] == copy.tracks[1][]
        check pattern.tracks[2][] == copy.tracks[2][]
        check pattern.tracks[3][] == copy.tracks[3][]

    test "overwrite paste":
        # clip all of track1
        let pattern = getSamplePattern().toCPattern
        clip.save(
            pattern,
            initPatternSelection(
                a(0, 0, selNote), a(patternSize - 1, 0, selEffect3)
            )
        )
        check clip.hasData()

        # paste at Track 3 (CH4)
        let copyPattern = pattern.clone()
        clip.paste(copyPattern, PatternCursor(row: 0, track: 3, column: colNote), false)

        check copyPattern.tracks[0][] == pattern.tracks[0][]
        check copyPattern.tracks[1][] == pattern.tracks[1][]
        check copyPattern.tracks[2][] == pattern.tracks[2][]
        check copyPattern.tracks[3][] == pattern.tracks[0][]

    test "mix paste":
        let pattern = getSamplePattern().toCPattern
        let copyPattern = pattern.clone()
        # clip track 0
        clip.save(pattern, initPatternSelection(a(0, 0, selNote), a(patternSize - 1, 0, selEffect3)))
        check clip.hasData()

        # mix paste at track 3
        # should be no change to the pattern
        clip.paste(copyPattern, PatternCursor(row: 0, track: 3, column: colNote), true)

        check copyPattern.tracks[0][] == pattern.tracks[0][]
        check copyPattern.tracks[1][] == pattern.tracks[1][]
        check copyPattern.tracks[2][] == pattern.tracks[2][]
        check copyPattern.tracks[3][] == pattern.tracks[3][]

        # now mix paste at row 1:
        # 00 ... | G-6 01 ... |     ... | G-6 01 ... |
        # 01 ... | ... .. ... |     ... | G-5 00 ... |
        # 02 ... | G-6 01 G03 |     ... | G-6 01 G03 |
        # 03 ... | ... .. ... |  => ... | ... .. ... |
        # 04 ... | G-6 02 ... |     ... | G-6 02 ... |
        # 05 ... | ... .. ... |     ... | B-5 00 ... |
        # 06 ... | G-6 01 G03 |     ... | G-6 01 G03 |
        # 07 ... | ... .. ... |     ... | ... .. ... |
        clip.paste(copyPattern, PatternCursor(row: 1, track: 3, column: colNote), true)

        # these track should remain unchanged
        check copyPattern.tracks[0][] == pattern.tracks[0][]
        check copyPattern.tracks[1][] == pattern.tracks[1][]
        check copyPattern.tracks[2][] == pattern.tracks[2][]

        proc makeExpected(): Track =
            result = initTrack(patternSize)
            with result:
                setNote(0, "G-6".note)
                setInstrument(0, 1)
                setNote(1, "G-5".note)
                setInstrument(1, 0)
                setNote(2, "G-6".note)
                setInstrument(2, 1)
                setEffect(2, 0, etDelayedNote, 3)
                setNote(4, "G-6".note)
                setInstrument(4, 2)
                setNote(5, "B-5".note)
                setInstrument(5, 0)
                setNote(6, "G-6".note)
                setInstrument(6, 1)
                setEffect(6, 0, etDelayedNote, 3)
        check copyPattern.tracks[3][] == makeExpected()
