discard """
"""

import ../../src/trackerboy/[data, editing, notes]
import utils
import ../unittest_wrapper

import std/with

unittests:
    suite "PatternClip":

        const patternSize = 8
        const wholePattern = PatternSelection.init(
            a(0, ChannelId.low.ord, low(TrackSelect)),
            a(patternSize - 1, ChannelId.high.ord, high(TrackSelect))
        )

        proc getSamplePattern(): Pattern = 
            result = Pattern(
                tracks: [
                    Track.new(patternSize),
                    Track.new(patternSize),
                    Track.new(patternSize),
                    Track.new(patternSize)
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
            setTrack0(result.tracks[ch1][])

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
            setTrack3(result.tracks[ch4][])

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
                Track.new(patternSize),
                Track.new(patternSize),
                Track.new(patternSize),
                Track.new(patternSize)
            ])
            clip.restore(copy)
            check pattern.tracks[ch1][] == copy.tracks[ch1][]
            check pattern.tracks[ch2][] == copy.tracks[ch2][]
            check pattern.tracks[ch3][] == copy.tracks[ch3][]
            check pattern.tracks[ch4][] == copy.tracks[ch4][]

        test "overwrite paste":
            # clip all of track1
            let pattern = getSamplePattern().toCPattern
            clip.save(
                pattern,
                PatternSelection.init(
                    a(0, 0, selNote), a(patternSize - 1, 0, selEffect3)
                )
            )
            check clip.hasData()

            # paste at Track 3 (CH4)
            let copyPattern = pattern.clone()
            clip.paste(copyPattern, PatternCursor(row: 0, track: 3, column: colNote), false)

            check copyPattern.tracks[ch1][] == pattern.tracks[ch1][]
            check copyPattern.tracks[ch2][] == pattern.tracks[ch2][]
            check copyPattern.tracks[ch3][] == pattern.tracks[ch3][]
            check copyPattern.tracks[ch4][] == pattern.tracks[ch1][]

        test "mix paste":
            let pattern = getSamplePattern().toCPattern
            let copyPattern = pattern.clone()
            # clip track 0
            clip.save(pattern, PatternSelection.init(a(0, 0, selNote), a(patternSize - 1, 0, selEffect3)))
            check clip.hasData()

            # mix paste at track 3
            # should be no change to the pattern
            clip.paste(copyPattern, PatternCursor(row: 0, track: 3, column: colNote), true)

            check copyPattern.tracks[ch1][] == pattern.tracks[ch1][]
            check copyPattern.tracks[ch2][] == pattern.tracks[ch2][]
            check copyPattern.tracks[ch3][] == pattern.tracks[ch3][]
            check copyPattern.tracks[ch4][] == pattern.tracks[ch4][]

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
            check copyPattern.tracks[ch1][] == pattern.tracks[ch1][]
            check copyPattern.tracks[ch2][] == pattern.tracks[ch2][]
            check copyPattern.tracks[ch3][] == pattern.tracks[ch3][]

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
            check copyPattern.tracks[ch4][] == makeExpected()
