
import unittest2
import std/[math]

import libtrackerboy/[data, text]

suite "Speed":

  test "$":
    check:
      $Speed(0x60) == "$60"
      $unitSpeed == "$10"
  
  test "isValid":
    check:
      isValid(unitSpeed)
      isValid(defaultSpeed)
      isValid(Speed(0xF0))
      not isValid(Speed(0))
      not isValid(Speed(0xF1))

  test "toFloat":
    check:
      toFloat(unitSpeed) == 1.0
      toFloat(Speed(0x60)) == 6.0
      toFloat(Speed(0xA8)) == 10.5

  test "toSpeed":
    check:
      toSpeed(1.0) == unitSpeed
      toSpeed(0.25) == rangeSpeed.a # clamped
      toSpeed(345.0) == rangeSpeed.b # clamped
      toSpeed(3.5) == Speed(0x38)
      toSpeed(3.487) == Speed(0x38) # rounded up to 3.5
      toSpeed(3.460) == Speed(0x37) # rounded down to 3.4375

  test "tempo":
    check:
      almostEqual(tempo(2.5, 4, 59.7), 358.2)
      almostEqual(tempo(unitSpeed, 4, 60.0), 900.0)

suite "Sequence":

  test "isValid":
    check:
      isValid(default(Sequence))
      isValid(initSequence([0u8, 1, 2, 1, 3]))
    var s: Sequence
    s.data.setLen(300)
    check not isValid(s)

suite "Instrument":
  test "hash":
    var
      i1 = initInstrument()
      i2 = i1
      i3 = i1
    i3.sequences[skArp] = initSequence([255u8, 1, 254])

    let
      hc1 = hash(i1)
      hc2 = hash(i2)
      hc3 = hash(i3)

    check:
      hc1 == hc2
      i1 == i2
      hc1 != hc3 or i1 != i3

suite "Waveform":  
  
  test "hash":
    var
      w1 = initWaveform()
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


template tableTests(T: typedesc[InstrumentTable|WaveformTable]) =    
  suite $T:

    const testName {.used.} = "test name"

    setup:
      var tab {.inject.} = `init T`()
    
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
        tab.nextAvailableId() == 0
        tab.add() == 0
        tab.nextAvailableId() == 1
        tab.add() == 1
        tab.nextAvailableId() == 2
        tab.add() == 2
      
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
        tab[8].sequences[skTimbre] = initSequence([0u8, 1, 2])

      # uniqueIds should give us the set with 0 and 8 since id 1 is
      # equivalent to id 0. When there are duplicates, the lowest id of all
      # is used.
      check:
        uniqueIds(tab) == { 0.TableId, 8 }
        uniqueIds(`init T`()).card == 0


tableTests(InstrumentTable)
tableTests(WaveformTable)

suite "NoteColumn":

  test "noteColumn":
    check:
      noteColumn(0).value() == 0
      noteColumn(2, 3).value() == 14

  test "default has no value":
    check:
      not default(NoteColumn).has()

  test "toOption":
    check:
      noteNone.toOption() == none(uint8)
      noteColumn(0).toOption() == some(0u8)

  test "$":
    check:
      $noteNone == "note()"
      $noteColumn(3) == "note(3)"

suite "InstrumentColumn":

  test "instrumentColumn":
    check:
      instrumentColumn(0).value() == 0
      instrumentColumn(63).value() == 63

  test "default has no value":
    check not default(InstrumentColumn).has()

  test "toOption":
    check:
      instrumentNone.toOption() == none(uint8)
      instrumentColumn(2).toOption() == some(2u8)

  test "$":
    check:
      $instrumentNone == "instrument()"
      $instrumentColumn(3) == "instrument(3)"

suite "Effect":

  test "toEffectCmd":
    check:
      toEffectCmd(0) == ecNoEffect
      toEffectCmd(uint8(ecLock)) == ecLock
      toEffectCmd(0xFF) == ecNoEffect
  
  test "shortensPattern":
    check:
      shortensPattern(ecPatternGoto)
      shortensPattern(ecPatternHalt)
      shortensPattern(ecPatternSkip)
      not shortensPattern(ecNoEffect)
      not shortensPattern(ecArpeggio)

suite "TrackRow":

  test "default has no columns":
    let row = default(TrackRow)
    check:
      row.note == noteNone
      row.instrument == instrumentNone
      row.effects[0] == effectNone
      row.effects[1] == effectNone
      row.effects[2] == effectNone
  
  test "isEmpty":
    var row: TrackRow
    check row.isEmpty()
    row.instrument = instrumentColumn(2)
    check not row.isEmpty()

suite "Order":

  test "initOrder() has one row":
    let order = initOrder()
    check:
      order.len() == 1
      order.isValid()

  test "default is invalid":
    let order = default(Order)
    check not order.isValid()
  
  test "nextUnused":
    let order = @[
      orow(0, 9, 1, 0),
      orow(1, 0, 0, 0)
    ]
    check order.nextUnused() == [2u8, 1, 2, 1]

const testrow = initTrackRow(noteColumn(0), instrumentColumn(0))

suite "Track":

  test "default is invalid":
    let track = default(Track)
    check:
      not track.isValid()
      track.len() == 0

  test "initTrack":
    let track = initTrack(64)
    check:
      track.isValid()
      track.len() == 64
  
  test "access":
    var track = initTrack(64)
    check track[4].isEmpty()
    track[4] = testrow
    check track[4] == testrow
    check track[0].isEmpty()
  
  test "totalRows":
    var track = initTrack(8)
    check track.totalRows() == 0
    track[0] = testrow
    track[4] = testrow
    track[6] = testrow
    check track.totalRows() == 3
  
  test "invalid views return empty rows on access":
    let track = default(Track)
    check:
      track[0].isEmpty()
      track[255].isEmpty()

  test "toView":
    var view: TrackView
    block:
      var track = initTrack(8)
      track[2] = testrow
      view = track.toView()
      check view[2] == track[2]
      # track dies here
    check view[2] == testrow # but view is still valid

suite "Pattern":

  test "all":
    var p: Pattern = [
      initTrack(4),
      default(Track),
      initTrack(4),
      initTrack(4)
    ]
    p[ch3][0] = testrow
    p[ch4][0] = testrow
    check p.all(0) == [ initTrackRow(), initTrackRow(), testrow, testrow ]

suite "Song":

  test "default is invalid":
    let s = default(Song)
    check not s.isValid()
  
  test "initSong()":
    let s = initSong()
    check:
      s.isValid()
      s.order == [ [ 0u8, 0, 0, 0 ] ]
      s.totalTracks() == 0

  test "getTrackView returns invalid track when id does not exist":
    let 
      s = initSong()
      v = s.getTrackView(ch1, 0)
    check not v.isValid()
  
  test "getTrack adds a new track when id does not exist":
    var
      s = initSong()
      t = s.getTrack(ch1, 0)
    check:
      t.isValid()
      s.totalTracks() == 1
  
  test "can remove all tracks":
    var s = initSong()
    discard s.getTrack(ch1, 0)
    discard s.getTrack(ch2, 1)
    check s.totalTracks() == 2
    s.removeAllTracks()
    check s.totalTracks() == 0

  test "estimateSpeed":
    var s = initSong()
    check s.estimateSpeed(160.0, 60.0) == Speed(0x5A) # 5.625 frames/row
    s.rowsPerBeat = 8
    check s.estimateSpeed(160.0, 60.0) == Speed(0x2D) # 2.8125 frames/row

  test "tempo":
    var s = initSong()
    check almostEqual(s.tempo(60.0), 150.0)
    s.rowsPerBeat = 2
    check almostEqual(s.tempo(60.0), 300.0)
  
  test "effectiveTickrate":
    const 
      tickrate = Tickrate(system: systemCustom, customFramerate: 32.0)
      tickrateDmg = Tickrate(system: systemDmg)
    var s = initSong()
    check s.effectiveTickrate(tickrate) == tickrate
    s.tickrate = some(tickrateDmg)
    check s.effectiveTickrate(tickrate) == tickrateDmg

suite "SongList":

  test "default is invalid":
    let list = default(SongList)
    check not list.isValid()

  test "1 song on init":
    let list = initSongList()
    check list.len() == 1

