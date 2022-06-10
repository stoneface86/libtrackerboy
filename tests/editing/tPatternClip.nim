discard """
"""

import ../../src/trackerboy/[data, editing, notes]
import utils
import ../unittest_wrapper

import std/with

const 
    patternSize = 8
    wholePattern = PatternSelection.init(
        a(0, ChannelId.low.ord, low(TrackSelect)),
        a(patternSize - 1, ChannelId.high.ord, high(TrackSelect))
    )

proc makeTestSong(): Song =
    result = Song.init
    # sample pattern data (patterns 0 and 1)
    #      ch1          ch2          ch3          ch4
    # 00 | G-5 00 ... | ... .. ... | ... .. ... | G-6 01 ... |
    # 01 | ... .. ... | ... .. ... | ... .. ... | ... .. ... |
    # 02 | ... .. ... | ... .. ... | ... .. ... | G-6 01 G03 |
    # 03 | ... .. ... | ... .. ... | ... .. ... | ... .. ... |
    # 04 | B-5 00 ... | ... .. ... | ... .. ... | G-6 02 ... |
    # 05 | ... .. ... | ... .. ... | ... .. ... | ... .. ... |
    # 06 | ... .. ... | ... .. ... | ... .. ... | G-6 01 G03 |
    # 07 | ... .. ... | ... .. ... | ... .. ... | ... .. ... |
    # pattern 2 is empty
    result.setTrackLen(patternSize)
    result.order.setLen(3)
    result.order[1] = [1u8, 1, 1, 1]
    result.order[2] = [2u8, 2, 2, 2]
    for i in 0..1:
        result.editPattern(i, pattern):
            with pattern(ch1):
                setNote(0, "G-5".note)
                setInstrument(0, 0)
                setNote(4, "B-5".note)
                setInstrument(4, 0)
            with pattern(ch4):
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
    result.editPattern(2, pattern):
        discard


unittests:
    suite "PatternClip":

        setup:
            var clip: PatternClip

        test "has no data on init":
            check not clip.hasData()

        test "save raises RangeDefect on invalid selection":
            proc mkInput(a1, a2: PatternAnchor, name: string): auto =
                (
                    data: PatternSelection.init(a1, a2),
                    name: name
                )
            const inputs = [
                mkInput(a(-1, 0, selNote), a(4, 0, selNote), "negative row index"),
                mkInput(a(1, 0, selNote), a(patternSize, 0, selNote), "row exceeds pattern"),
                mkInput(a(0, 2, selInstrument), a(4, -2, selNote), "negative track index"),
                mkInput(a(0, ChannelId.high.ord + 2, selEffect1), a(0, 0, selEffect2), "track exceeds pattern")
            ]
            var song = makeTestSong()
            for input in inputs:
                checkpoint input.name
                expect RangeDefect:
                    clip.save(song, 0, input.data)

        
        test "persistance":
            var song = makeTestSong()
            clip.save(song, 0, wholePattern)
            check clip.hasData()

            # restore the clip to a new pattern
            clip.restore(song, 2)
            song.viewPattern(0, p0):
                song.viewPattern(2, p1):
                    check:
                        p0(ch1) == p1(ch1)
                        p0(ch2) == p1(ch2)
                        p0(ch3) == p1(ch3)
                        p0(ch4) == p1(ch4)

        test "overwrite paste":
            # clip all of track1
            var song = makeTestSong()
            clip.save(
                song,
                0,
                PatternSelection.init(
                    a(0, 0, selNote), a(patternSize - 1, 0, selEffect3)
                )
            )
            check clip.hasData()

            # paste at Track 3 (CH4)
            clip.paste(song, 1, PatternCursor(row: 0, track: 3, column: colNote), false)

            song.viewPattern(0, p0):
                song.viewPattern(1, p1):
                    check:
                        p0(ch1) == p1(ch1)
                        p0(ch2) == p1(ch2)
                        p0(ch3) == p1(ch3)
                        p1(ch1) == p1(ch4)

        test "mix paste":
            var song = makeTestSong()
            # clip track 0
            clip.save(song, 0, PatternSelection.init(a(0, 0, selNote), a(patternSize - 1, 0, selEffect3)))
            check clip.hasData()

            # mix paste at track 3 in pattern 1
            # should be no change to the pattern
            clip.paste(song, 1, PatternCursor(row: 0, track: 3, column: colNote), true)

            song.viewPattern(0, p0):
                song.viewPattern(1, p1):
                    check:
                        p0(ch1) == p1(ch1)
                        p0(ch2) == p1(ch2)
                        p0(ch3) == p1(ch3)
                        p0(ch4) == p1(ch4)

            # now mix paste at row 1:
            # 00 ... | G-6 01 ... |     ... | G-6 01 ... |
            # 01 ... | ... .. ... |     ... | G-5 00 ... |
            # 02 ... | G-6 01 G03 |     ... | G-6 01 G03 |
            # 03 ... | ... .. ... |  => ... | ... .. ... |
            # 04 ... | G-6 02 ... |     ... | G-6 02 ... |
            # 05 ... | ... .. ... |     ... | B-5 00 ... |
            # 06 ... | G-6 01 G03 |     ... | G-6 01 G03 |
            # 07 ... | ... .. ... |     ... | ... .. ... |
            clip.paste(song, 1, PatternCursor(row: 1, track: 3, column: colNote), true)

            proc makeExpected(): Track =
                result = Track.init(patternSize)
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

            song.viewPattern(0, p0):
                song.viewPattern(1, p1):
                    check:
                        # these tracks should remain unchanged
                        p0(ch1) == p1(ch1)
                        p0(ch2) == p1(ch2)
                        p0(ch3) == p1(ch3)
                        # check that the mix works
                        p1(ch4) == makeExpected()
