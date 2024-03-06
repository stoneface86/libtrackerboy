
import unittest2
import std/sequtils

import libtrackerboy/[data, text]

suite "Order":
  const
    testrow1: OrderRow = [1u8, 1, 1, 1]
    testrow2: OrderRow = [2u8, 2, 2, 2]
  
  setup():
    var order = initOrder()

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

template tableTests(T: typedesc[InstrumentTable|WaveformTable]) =    
  suite $T:

    const testName {.used.} = "test name"

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
        src.data = litWave("0123456789ABCDEFFEDCBA9876543210")

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

    test "uniqueIds":
      # ids 0 and 1 are the same
      discard tab.add()
      discard tab.add()
      # id 8 will be unique
      tab.add(8)
      when T is WaveformTable:
        tab[8].data[0] = 0xFF
      else:
        tab[8].sequences[skTimbre] = Sequence.init([0u8, 1, 2]) #parseSequence("0 1 2")

      # uniqueIds should give us the set with 0 and 8 since id 1 is
      # equivalent to id 0. When there are duplicates, the lowest id of all
      # is used.
      check:
        uniqueIds(tab) == { 0.TableId, 8 }
        uniqueIds(init(T)).card == 0


tableTests(InstrumentTable)
tableTests(WaveformTable)


static: # ============================================================ TrackRow
  assert sizeof(TrackRow) == 8
  let row = default(TrackRow)
  assert row.note == noteNone
  assert row.instrument == instrumentNone
  for effect in row.effects:
    assert effect.effectType == uint8(etNoEffect)
    assert effect.param == 0

suite "Waveform":  
  
  test "hash":
    var
      w1 = Waveform.init()
      w2 = w1
      w3 = w1
    w3.data[0] = 0xFF

    let
      hc1 = hash(w1)
      hc2 = hash(w2)
      hc3 = hash(w3)
    
    check:
      hc1 == hc2
      w1 == w2
      hc1 != hc3 or w1 != w3

suite "Instrument":
  test "hash":
    var
      i1 = Instrument.init()
      i2 = i1
      i3 = i1
    i3.sequences[skArp] = Sequence.init([255u8, 1, 254])

    let
      hc1 = hash(i1)
      hc2 = hash(i2)
      hc3 = hash(i3)

    check:
      hc1 == hc2
      i1 == i2
      hc1 != hc3 or i1 != i3
