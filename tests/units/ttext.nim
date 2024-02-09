
import unittest2
import libtrackerboy/[data, notes, text]

import std/[options]

func `==`(x: openArray[char]; y: string): bool =
  result = x == toOpenArray(y, 0, y.len - 1)

block: # NoteColumn
  test "noteText":
    check:
      noteText(noteNone) == "..."
      noteText(noteColumn(0, 2)) == "C-4"
      noteText(noteColumn(noteCut)) == "---"
      noteText(noteColumn(1)) == "C#2"
      noteText(noteColumn(1), true) == "Db2"
      noteText(noteColumn(11)) == "B-2"
  
  test "parseNote":
    check:
      parseNote("B-2") == some(noteColumn(11))
      parseNote("...") == some(noteNone)
      parseNote("---") == some(noteColumn(noteCut))
      parseNote("C#4") == some(noteColumn(1, 2))
      parseNote("Db4") == some(noteColumn(1, 2))
      parseNote("ssd").isNone()
      parseNote("").isNone()
      parseNote("C#").isNone()
      parseNote("C-1").isNone()
      parseNote("C-9").isNone()
      parseNote("C-0").isNone()

block: # InstrumentColumn
  test "instrumentText":
    check:
      instrumentText(instrumentNone) == ".."
      instrumentText(instrumentColumn(0x00)) == "00"
      instrumentText(instrumentColumn(0x09)) == "09"
      instrumentText(instrumentColumn(0x0A)) == "0A"
      instrumentText(instrumentColumn(0x1F)) == "1F"
  
  test "parseInstrument":
    check:
      parseInstrument("..") == some(instrumentNone)
      parseInstrument("00") == some(instrumentColumn(0))
      parseInstrument("3F") == some(instrumentColumn(0x3F))
      parseInstrument("40").isNone()
      parseInstrument("1z").isNone()
      parseInstrument("ssadsas").isNone()
      parseInstrument("").isNone()

block: # Effect
  const
    test1 = Effect.init(etArpeggio, 0x32)
    test1Str = "032"
    test2 = Effect.init(etTuning, 0x83)
    test2Str = "P83"
    test3 = Effect.init(etLock)
    test3Str = "L00"


  test "effectText":
    check:
      effectText(effectNone) == "..."
      effectText(test1) == test1Str
      effectText(test2) == test2Str
      effectText(test3) == test3Str
  test "parseEffect":
    check:
      parseEffect("...") == some(effectNone)
      parseEffect(test1Str) == some(test1)
      parseEffect(test2Str) == some(test2)
      parseEffect(test3Str) == some(test3)
      parseEffect("Z23").isNone()
      parseEffect("").isNone()
      parseEffect("sksksks").isNone()

block: # OrderRow

  const
    rowEmpty = default(OrderRow)
    rowEmptyStr = "00 00 00 00"
    row1: OrderRow = [1u8, 2, 3, 4]
    row1Str = "01 02 03 04"

  test "orderRowText":
    check:
      orderRowText(rowEmpty) == rowEmptyStr
      orderRowText(row1) == row1Str
  
  test "parseOrderRow":
    check:
      parseOrderRow(rowEmptyStr) == some(rowEmpty)
      parseOrderRow(row1Str) == some(row1)
      parseOrderRow("").isNone()
      parseOrderRow("zz 00 00 00").isNone()
      parseOrderRow("00 zz 00 00").isNone()
      parseOrderRow("00 00 zz 00").isNone()
      parseOrderRow("00 00 00 zz").isNone()
      parseOrderRow("00,00 00 00").isNone()
      parseOrderRow("00 00,00 00").isNone()
      parseOrderRow("00 00 00,00").isNone()
      parseOrderRow("00 00 00 00 00").isNone()
      
      

block: # TrackRow
  const
    rowEmpty = default(TrackRow)
    rowEmptyStr  = "... .. ... ... ..."
    
    row1 = TrackRow.init(noteColumn(37), e2 = Effect.init(etPitchUp, 2))
    row1Str      = "C#5 .. ... 102 ..."
    row1StrFlats = "Db5 .. ... 102 ..."
  
  test "trackRowText":
    check:
      trackRowText(rowEmpty) == rowEmptyStr
      trackRowText(row1) == row1Str
      trackRowText(row1, true) == row1StrFlats
  
  test "parseTrackRow":
    check:
      parseTrackRow(rowEmptyStr) == some(rowEmpty)
      parseTrackRow(row1Str) == some(row1)
      parseTrackRow(row1StrFlats) == some(row1)
      parseTrackRow("").isNone()
      parseTrackRow(" ksasdksa wkeqo osk oqo wo w").isNone()
      parseTrackRow("sas .. ... ... ...").isNone()
      parseTrackRow("... se ... ... ...").isNone()

block: # Sequence
  const
    data1 = [127u8]
    data2 = [1u8, 2, 3, 0xFF, 0x80]
    data2Clamped = [1u8, 2, 3, 0, 0]

    s0 = Sequence.init([])
    s1 = Sequence.init(data1)
    s2 = Sequence.init(data2)
    s3 = Sequence.init(data2, some(ByteIndex(1)))
    s4 = Sequence.init(data2, some(ByteIndex(200)))
    s5 = Sequence.init([], some(ByteIndex(3)))

    str0 = ""
    str1 = "127"
    str2 = "1 2 3 -1 -128"
    str3 = "1 | 2 3 -1 -128"
  
  test "sequenceText":
    check:
      sequenceText(s0) == str0
      sequenceText(s1) == str1
      sequenceText(s2) == str2
      sequenceText(s3) == str3
      sequenceText(s4) == str2
      sequenceText(s5) == str0
  
  test "parseSequence":
    check:
      parseSequence(str0) == some(s0)
      parseSequence(str1) == some(s1)
      parseSequence(str2) == some(s2)
      parseSequence(str3) == some(s3)
      parseSequence(str2, 0, 3) == some(Sequence.init(data2Clamped))

block: # WaveData
  const
    waveZero = default(WaveData)
    waveZeroStr = "00000000000000000000000000000000"
    waveTriangle: WaveData = [0x01u8, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
                              0xFE  , 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10]
    waveTriangleStr = "0123456789ABCDEFFEDCBA9876543210"

  test "waveText":
    check:
      waveText(waveZero) == waveZeroStr
      waveText(waveTriangle) == waveTriangleStr

  test "parseWave":
    check:
      parseWave(waveZeroStr) == some(waveZero)
      parseWave(waveTriangleStr) == some(waveTriangle)
      parseWave("").isNone()
      parseWave("kdkdkd").isNone()
      parseWave("00000000000z00000000000000000000").isNone()
      parseWave("000000000000000000000000000000002232").isNone()
