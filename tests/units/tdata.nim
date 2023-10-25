
import unittest2
import std/sequtils

import libtrackerboy/data

block: # ================================================================ Order
  const
    testrow1: OrderRow = [1u8, 1, 1, 1]
    testrow2: OrderRow = [2u8, 2, 2, 2]
  
  suite "Order":
    setup():
      var order = Order.init

    test "must have 1 row on init":
      check:
        order.len == 1
        order[0] == default(OrderRow)

    test "get/set":
      order[0] = testrow1
      check order[0] == testrow1

    test "insert":
      order.insert(testrow1, 1)
      check:
        order[0] == default(OrderRow)
        order[1] == testrow1

      order.insert(testrow2, 0)
      check:
        order[0] == testrow2
        order[1] == default(OrderRow)
        order[2] == testrow1

    test "auto-row":
      for i in 1u8..5u8:
        order.insert(order.nextUnused(), order.len)
        check order[i.ByteIndex] == [i, i, i, i]

    test "resizing":
      order.setLen(5)
      check:
        order.len == 5
        order.data.all(proc (o: OrderRow): bool = o == default(OrderRow))

      order[0] = testrow1
      order[1] = testrow2
      order.setLen(2)
      check:
        order.len == 2
        order[0] == testrow1
        order[1] == testrow2

block: # ============================================================ Sequence

  func sequence(data = default(seq[uint8]); loop = none(ByteIndex)): Sequence =
    # TODO: move this to the library API
    result.data = data
    result.loopIndex = loop

  suite "Sequence":
    test "$":
      const
        data1 = @[127u8]
        data2 = @[1u8, 2, 3, 0xFF, 0x80]
      check:
        $sequence() == ""
        $sequence(data1) == "127"
        $sequence(data2) == "1 2 3 -1 -128"
        $sequence(data2, some(ByteIndex(1))) == "1 | 2 3 -1 -128"
        $sequence(data2, some(ByteIndex(200))) == "1 2 3 -1 -128"
        $sequence(loop = some(ByteIndex(3))) == ""

    test "parseSequence":
      check:
        parseSequence("") == default(Sequence)
        parseSequence("  1 2   \t3  4\t") == sequence(@[1u8, 2, 3 ,4])
        parseSequence("2 | 3 4") == sequence(@[2u8, 3, 4], some(ByteIndex(1)))
        parseSequence("23sasd32sasd3@@$@21||23|2") == sequence(@[23u8, 32, 3, 21, 23, 2], some(ByteIndex(5)))

block: # ============================================================= SongList

  suite "SongList":

    setup:
      var songlist = SongList.init

    test "1 song on init":
      check:
        songlist.len == 1
        songlist[0] != nil

    test "get/set":
      var song = Song.new
      check songlist[0] != nil
      songlist[0] = song
      check songlist[0] == song

    test "add":
      songlist.add()
      check songlist.len == 2
      songlist.add()
      check songlist.len == 3
      songlist.add()
      check songlist.len == 4

    test "duplicate":
      songlist[0].rowsPerBeat = 8
      songlist.duplicate(0)
      check:
        songlist.len == 2
        songlist[0][] == songlist[1][]

    test "remove":
      songlist.add()
      songlist.add()
      songlist.remove(0)
      check songlist.len == 2
      songlist.remove(1)
      check songlist.len == 1

    test "removing when len=1 raises AssertionDefect":
      expect AssertionDefect:
        songlist.remove(0)

    test "adding/duplicating when len=256 raises AssertionDefect":
      for i in 0..254:
        songlist.add()
      expect AssertionDefect:
        songlist.add()
      expect AssertionDefect:
        songlist.duplicate(2)

block: # ============================================================== Table
  const testName {.used.} = "test name"

  template tableTests(T: typedesc[InstrumentTable|WaveformTable]) =    
    suite $T:
      setup:
        var tab = init(T)
      
      test "can name items":
        var item = tab[tab.add()]
        check item.name == ""
        item.name = testName
        check item.name == testName

      test "empty on init":
        check tab.len == 0
        for id in TableId.low..TableId.high:
          check tab[id] == nil
      
      test "duplicate":
        let srcId = tab.add()
        var src = tab[srcId]
        
        check src != nil
        src[].name = testName

        when src[] is Instrument:
          src.sequences[skEnvelope].data = @[3u8]
          src.sequences[skPanning].data = @[1u8, 1, 2, 2, 3]
        else:
          src.data = "0123456789ABCDEFFEDCBA9876543210".parseWave

        let dupId = tab.duplicate(srcId)
        var duped = tab[dupId]
        check:
          duped != nil
          src[] == duped[]

      test "keeps track of the next available id":
        check:
          tab.nextAvailableId == 0
          tab.nextAvailableId == tab.add()
          tab.nextAvailableId == 1
          tab.nextAvailableId == tab.add()
          tab.nextAvailableId == 2
          tab.nextAvailableId == tab.add()
        
        tab.remove(0)
        check tab.nextAvailableId == 0
        tab.remove(1)
        check tab.nextAvailableId == 0

        check:
          tab.nextAvailableId == tab.add()
          tab.nextAvailableId == 1
          tab.nextAvailableId == tab.add()
          tab.nextAvailableId == 3
  
  tableTests(InstrumentTable)
  tableTests(WaveformTable)


static: # ============================================================ TrackRow
  assert sizeof(TrackRow) == 8
  let row = default(TrackRow)
  assert row.queryNote().isNone()
  assert row.queryInstrument().isNone()
  for effect in row.effects:
    assert effect.effectType == uint8(etNoEffect)
    assert effect.param == 0

block: # ============================================================= WaveData

  const
    zero = default(WaveData)
    zeroStr = "00000000000000000000000000000000"
    triangle: WaveData = [0x01u8, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
                0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10]
    triangleStr = "0123456789ABCDEFFEDCBA9876543210"

  suite "WaveData":
    test "$WaveData":
      check:
        $zero == zeroStr
        $triangle == triangleStr

    test "parseWave":
      check:
        zeroStr.parseWave == zero
        triangleStr.parseWave == triangle
        # partial waveform
        "11223344".parseWave == [0x11u8, 0x22, 0x33, 0x44, 0, 0, 0, 0, 
                      0, 0, 0, 0, 0, 0, 0, 0]
        # invalid string
        "11@3sfji2maks;w".parseWave == [0x11u8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
