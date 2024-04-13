
import unittest2
import libtrackerboy/[data, editing, text]

template a(r: int, t: int, c: TrackSelect): PatternAnchor =
  PatternAnchor(row: r, track: t, column: c)

block: # ========================================================== PatternClip
  const
    patternSize = 8
    wholePattern = PatternSelection.init(
      a(0, ChannelId.low.ord, low(TrackSelect)),
      a(patternSize - 1, ChannelId.high.ord, high(TrackSelect))
    )

  proc makeTestSong(): Song =
    result = initSong()
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
    result.trackLen = patternSize
    result.order = @[
      orow(0, 0, 0, 0),
      orow(1, 1, 1, 1),
      orow(2, 2, 2, 2)
    ]
    for i in 0..1:
      result.editPattern(i, pattern):
        ###### CH1 #########################################
        pattern[ch1][0] = litTrackRow("G-5 00 ... ... ...")
        # 01
        # 02
        # 03
        pattern[ch1][4] = litTrackRow("B-5 00 ... ... ...")
        # 05
        # 06
        # 07
        ###### CH4 #########################################
        pattern[ch4][0] = litTrackRow("G-6 01 ... ... ...")
        # 01
        pattern[ch4][2] = litTrackRow("G-6 01 G03 ... ...")
        # 03
        pattern[ch4][4] = litTrackRow("G-6 02 ... ... ...")
        # 05
        pattern[ch4][6] = litTrackRow("G-6 01 G03 ... ...")
        # 07        
    result.editPattern(2, pattern):
      discard


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
            p0[ch1] == p1[ch1]
            p0[ch2] == p1[ch2]
            p0[ch3] == p1[ch3]
            p0[ch4] == p1[ch4]

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
            p0[ch1] == p1[ch1]
            p0[ch2] == p1[ch2]
            p0[ch3] == p1[ch3]
            p1[ch1] == p1[ch4]

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
            p0[ch1] == p1[ch1]
            p0[ch2] == p1[ch2]
            p0[ch3] == p1[ch3]
            p0[ch4] == p1[ch4]

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
        result = initTrack(patternSize)
        result[0] = litTrackRow("G-6 01 ... ... ...")
        result[1] = litTrackRow("G-5 00 ... ... ...")
        result[2] = litTrackRow("G-6 01 G03 ... ...")
        result[4] = litTrackRow("G-6 02 ... ... ...")
        result[5] = litTrackRow("B-5 00 ... ... ...")
        result[6] = litTrackRow("G-6 01 G03 ... ...")

      song.viewPattern(0, p0):
        song.viewPattern(1, p1):
          check:
            # these tracks should remain unchanged
            p0[ch1] == p1[ch1]
            p0[ch2] == p1[ch2]
            p0[ch3] == p1[ch3]
            # check that the mix works
            p1[ch4] == initTrackView(makeExpected())

block: # ===================================================== PatternSelection
  suite "PatternSelection":
  
    test "clamp":
      const startingSelection = PatternSelection.init(a(0, 0, selNote), a(36, 1, selInstrument))
      var sel = startingSelection

      sel.clamp(64)
      check sel == startingSelection

      sel.clamp(32)
      check:
        sel != startingSelection
        sel == PatternSelection.init(a(0, 0, selNote), a(32, 1, selInstrument))

    test "translate":
      const sample = PatternSelection.init(a(0, 0, selNote), a(1, 0, selEffect3))
      var sel = sample
      sel.translate(1)
      check sel == PatternSelection.init(a(1, 0, selNote), a(2, 0, selEffect3))
      
      # check clamping when out of bounds
      sel = sample
      sel.translate(-100)
      check sel == PatternSelection.init(a(0, 0, selNote), a(0, 0, selEffect3))

      sel = sample
      sel.translate(300)
      check sel == PatternSelection.init(a(high(ByteIndex), 0, selNote), a(high(ByteIndex), 0, selEffect3))

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
          input: PatternSelection.init(a(1, 0, selNote), a(6, 0, selNote)),
          expectedRows: 1..6,
          expectedTracks: 0..0,
          expectedColumns: 1
        ),
        TestData(
          name: "multiple columns, single track",
          input: PatternSelection.init(a(10, 3, selInstrument), a(1, 3, selEffect3)),
          expectedRows: 1..10,
          expectedTracks: 3..3,
          expectedColumns: 4
        ),
        TestData(
          name: "single column, multiple tracks",
          input: PatternSelection.init(a(3, 1, selEffect2), a(3, 3, selEffect2)),
          expectedRows: 3..3,
          expectedTracks: 1..3,
          expectedColumns: 11
        ),
        TestData(
          name: "multiple columns, multiple tracks",
          input: PatternSelection.init(a(1, 3, selEffect3), a(10, 1, selInstrument)),
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
      let
        first = a(10, 1, selInstrument)
        last = a(32, 2, selEffect2)
        sel = PatternSelection.init(first, last)
      check:
        sel.contains(first)
        sel.contains(last)
        sel.contains(a(16, 1, selEffect1))
        not sel.contains(a(9, 1, selInstrument))
        not sel.contains(a(36, 1, selInstrument))
        not sel.contains(a(16, 1, selNote))
        not sel.contains(a(16, 2, selEffect3))

static:
  assert not isEffect(selNote)
  assert not isEffect(selInstrument)
  assert isEffect(selEffect1)
  assert isEffect(selEffect2)
  assert isEffect(selEffect3)

  assert selNote.effectNumber == 0
  assert selInstrument.effectNumber == 0
  assert selEffect1.effectNumber == 0
  assert selEffect2.effectNumber == 1
  assert selEffect3.effectNumber == 2
