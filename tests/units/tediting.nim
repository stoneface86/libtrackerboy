
import unittest2
import libtrackerboy/[data, editing, text]

template pa(row, track: int; select: TrackSelect): PatternAnchor =
  initPatternAnchor(row, track, select)

template ps(rows, tracks: Slice[int]; selects: Slice[TrackSelect]): PatternSelection =
  initPatternSelection(rows, tracks, selects)

test "toSelect":
  check:
    colNote.toSelect() == selNote
    colInstrumentHi.toSelect() == selInstrument
    colInstrumentLo.toSelect() == selInstrument
    colEffectType1.toSelect() == selEffect1
    colEffectParamHi1.toSelect() == selEffect1
    colEffectParamLo1.toSelect() == selEffect1
    colEffectType2.toSelect() == selEffect2
    colEffectParamHi2.toSelect() == selEffect2
    colEffectParamLo2.toSelect() == selEffect2
    colEffectType3.toSelect() == selEffect3
    colEffectParamHi3.toSelect() == selEffect3
    colEffectParamLo3.toSelect() == selEffect3

test "effectNumber":
  check:
    effectNumber(selNote) == 0
    effectNumber(selInstrument) == 0
    effectNumber(selEffect1) == 0
    effectNumber(selEffect2) == 1
    effectNumber(selEffect3) == 2

test "isEffect":
  check:
    not isEffect(selNote)
    not isEffect(selInstrument)
    isEffect(selEffect1)
    isEffect(selEffect2)
    isEffect(selEffect3)

suite "PatternSelection":
  const
    a1 = pa(10, 0, selNote)
    a2 = pa(20, 1, selInstrument)
  
  test "initPatternSelection: anchor order does not matter":
    check:
      initPatternSelection(a1, a2) == initPatternSelection(a2, a1)

  test "initPatternSelection correctness":
    check:
      initPatternSelection(a1, a2) == ps(10..20, 0..1, selNote..selInstrument)

  test "trackSelects":
    let
      oneTrack = ps(0..7, 1..1, selInstrument..selEffect1)
      multipleTracks = ps(0..7, 1..3, selInstrument..selEffect1)
    check:
      oneTrack.trackSelects(0) == selNote..selEffect3 # track is not in selection
      oneTrack.trackSelects(1) == selInstrument..selEffect1
      oneTrack.trackSelects(2) == selNote..selEffect3 # track is not in selection
      oneTrack.trackSelects(3) == selNote..selEffect3 # track is not in selection
      multipleTracks.trackSelects(0) == selNote..selEffect3 # track is not in selection
      multipleTracks.trackSelects(1) == selInstrument..selEffect3
      multipleTracks.trackSelects(2) == selNote..selEffect3
      multipleTracks.trackSelects(3) == selNote..selEffect1

  test "clamped":
    check:
      clamped(ps(-12..100, -2..0, selEffect1..selEffect1)) == ps(0..100, 0..0, selNote..selEffect1)
      clamped(ps(60..70, 1..2, selEffect1..selEffect3), 64) == ps(60..63, 1..2, selEffect1..selEffect3)
      clamped(noSelection) == noSelection
      clamped(ps(-12 .. -1, 0..0, selNote..selNote)) == noSelection
      clamped(ps(1..4, 5..6, selEffect1..selEffect3)) == noSelection

  test "contains":
    let
      s1 = ps(0..7, 2..2, selEffect1..selEffect3)
      s2 = ps(10..17, 0..1, selNote..selNote)
    check:
      pa(2, 2, selEffect2) in s1
      pa(8, 2, selEffect1) notin s1
      pa(2, 3, selEffect1) notin s1
      pa(4, 2, selNote) notin s1
      pa(11, 0, selEffect3) in s2
      pa(11, 1, selEffect3) notin s2

  test "moved":
    let
      s1 = ps(32..50, 2..3, selNote..selInstrument)
      s2 = ps(10..11, 1..1, selEffect1..selEffect1)
    check:
      s1.moved(pa(32, 2, selNote)) == s1
      s1.moved(pa(32, 2, selEffect3)) == s1
      s1.moved(pa(100, 3, selNote)) == ps(100..118, 3..4, selNote..selInstrument)
      s2.moved(pa(20, 0, selEffect3)) == ps(20..21, 0..0, selEffect3..selEffect3)

  test "gitFit":
    check:
      getFit(noSelection, 4) == nothing
      getFit(ps(0..3, 0..3, selNote..selEffect3), 4) == whole
      getFit(ps(0..5, 0..3, selNote..selEffect3), 4) == partial
      getFit(ps(-23..3, 0..3, selNote..selEffect3), 4) == partial
      getFit(ps(3..0, 0..3, selNote..selEffect3), 4) == nothing
      getFit(ps(0..0, 2..1, selNote..selNote), 4) == nothing
      getFit(ps(0..0, 1..1, selEffect1..selNote), 4) == nothing
      getFit(ps(0..0, -1..0, selNote..selNote), 4) == partial
      getFit(ps(1..1, 2..4, selInstrument..selEffect1), 4) == partial

block:

  const
    row1 = litTrackRow("D-4 01 V02 EF1 P82")
    row2 = litTrackRow("C-2 .. ... G04 ...")

  test "overwrite paste":
    var row = row1
    row.paste(selNote..selEffect1, default(TrackRow), overwrite)
    check row == litTrackRow("... .. ... EF1 P82")
    row = row1
    row.paste(selEffect3..selEffect3, default(TrackRow), overwrite)
    check row == litTrackRow("D-4 01 V02 EF1 ...")

  test "mix paste":
    var row = row1
    row.paste(selNote..selEffect3, default(TrackRow), mix)
    check row == row1
    row = row2
    row.paste(selNote..selEffect3, row1, mix)
    check row == litTrackRow("C-2 01 V02 G04 P82")

import std/macros

func buildImpl(track, body: NimNode;): NimNode {.compileTime.} =
  expectKind(body, nnkStmtList)
  let builder = newStmtList()
  for node in body:
    expectKind(node, nnkCall)
    expectLen(node, 2)
    let
      rowno = node[0]
      rowdata = node[1]
    expectKind(rowno, nnkIntLit)
    expectKind(rowdata, nnkStmtList)
    expectLen(rowdata, 1)
    let rowstr = rowdata[0]
    expectKind(rowstr, nnkStrLit)
    builder.add quote do:
      t[`rowno`] = litTrackRow(`rowstr`)
  result = quote do:
    block:
      var t {.inject.} = `track`
      `builder`

macro build(track: var Track; body) =
  result = buildImpl(track, body)

template buildTrack(trackLen: TrackLen; body): Track =
  block:
    var res = initTrack(trackLen)
    build(res, body)
    res

template checkPatternsEqual(p1, p2: SomePattern;): bool =
  let areEqual = p1 == p2
  check areEqual

const 
  testPatternLen = 4
  testRowCh1 = litTrackRow("A-4 00 000 001 023")
  testRowCh2 = litTrackRow("B-4 01 101 100 102")
  testRowCh3 = litTrackRow("C-4 02 20A 206 310")
  testRowCh4 = litTrackRow("D-4 03 312 300 320")

func blankPattern(): Pattern =
  for t in mitems(result):
    t = initTrack(testPatternLen)

func emptyClip(trackLen: TrackLen; region: PatternSelection): PatternClip =
  result.save(default(PatternView), trackLen, region)

suite "PatternClip":

  let 
    testPattern = block:
      var res = blankPattern()
      for i in 0..<testPatternLen:
        res[ch1][i] = testRowCh1
        res[ch2][i] = testRowCh2
        res[ch3][i] = testRowCh3
        res[ch4][i] = testRowCh4
      toView(res)
    

  setup:
    var clip: PatternClip

  test "default has no data":
    check not clip.hasData()

  test "save invalid region has no data":
    clip.save(default(PatternView), 8, ps(-23..0, 1..100, selNote..selNote))
    check not clip.hasData()
  
  test "save":
    clip.save(testPattern, testPatternLen, ps(0..3, 0..0, selNote..selEffect3))
    check clip.data().len() == 4 # 1 track, 4 rows
    clip.save(testPattern, testPatternLen, ps(0..2, 0..1, selNote..selNote))
    check clip.data().len() == 6 # 2 tracks, 3 rows

  test "paste - whole":
    clip = emptyClip(testPatternLen, ps(0..3, 0..0, selNote..selEffect3))
    var pattern = initPattern(testPattern)
    clip.paste(pattern, testPatternLen, pa(0, 0, selNote))
    check:
      pattern[ch1].totalRows() == 0
      pattern[ch2].toView() == testPattern[ch2]
      pattern[ch3].toView() == testPattern[ch3]
      pattern[ch4].toView() == testPattern[ch4]
      
    # clip.paste(pattern, testPatternLen, pa(2, 0, selNote), mix)
    # check:
    #   pattern[ch1][0] == pattern[ch2][0]
    #   pattern[ch1][1].isEmpty()
    #   pattern[ch2][2] == pattern[ch2][0]
    #   pattern[ch1][3].isEmpty()
    #   pattern[ch1][0] == pattern[ch2][0]
    #   pattern[ch1][1].isEmpty()
    #   pattern[ch2][2] == pattern[ch2][0]
    #   pattern[ch1][3].isEmpty()

  test "paste partial 1":
    # +-------+
    # | paste |
    # |   +---|-------------
    # +---|---+
    #     |  pattern
    clip = emptyClip(testPatternLen, ps(0..3, 2..3, selNote..selEffect3))
    var pattern = initPattern(testPattern)
    clip.paste(pattern, testPatternLen, pa(-2, -1, selNote))
    check:
      pattern[ch1].totalRows() == 2
      pattern[ch2].toView() == testPattern[ch2]
      pattern[ch3].toView() == testPattern[ch3]
      pattern[ch4].toView() == testPattern[ch4]

  test "paste partial 2":
    #          |
    #  pattern |
    #     +----|-----+
    # ----|----+     |
    #     |    paste |
    #     +----------+
    # paste should only modify where "pattern" and "paste" intersect
    clip = emptyClip(testPatternLen, ps(0..1, 0..1, selNote..selNote))
    var pattern = initPattern(testPattern)
    clip.paste(pattern, testPatternLen, pa(2, 3, selNote))
    check:
      pattern[ch1].toView() == testPattern[ch1]
      pattern[ch2].toView() == testPattern[ch2]
      pattern[ch3].toView() == testPattern[ch3]
      pattern[ch4].totalRows() == 2
