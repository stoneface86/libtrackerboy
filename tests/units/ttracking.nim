
import unittest2
import libtrackerboy/[data, ir, text, tracking]


test "filter":
  const row = litTrackRow("C-2 00 034 B02 G00")
  check:
    filter({}, row) == row
    filter({ etPitchUp, etPitchDown }, row) == row
    filter({ etDelayedNote }, row) == litTrackRow("C-2 00 034 B02 ...")
    filter({ etArpeggio }, row) == litTrackRow("C-2 00 ... B02 G00")
    filter({ etPatternGoto, etDelayedNote }, row) == litTrackRow("C-2 00 034 ... ...")

# func tickOut(songStats: set[SongStat] = {}; 
#              ts1: set[TrackStat] = {}; ts2: set[TrackStat] = {};
#              ts3: set[TrackStat] = {}; ts4: set[TrackStat] = {}
#             ): TickOut {.inline.} =
#   result = TickOut(songStats: songStats, trackStats: [ts1, ts2, ts3, ts4])

suite "Counter":

  test "default counter is disabled":
    var c: Counter
    check:
      not c.isEnabled()
      not c.tick()
      not c.tick()
      not c.isEnabled()

  test "instant counter":
    var c = initCounter(0)
    check:
      c.isEnabled()
      c.tick()
      not c.isEnabled()

  test "1 tick counter":
    var c = initCounter(1)
    check:
      c.isEnabled()
      not c.tick()
      c.tick()
      not c.isEnabled()

suite "Tracker":

  test "invalid position results in halt":
    const badPos = songPos(2, 123)
    let s = Song.init()
    var t = initTracker(s, badPos)
    check t.isHalted()
    t = initTracker(s)
    check t.isRunning()
    t.jump(s, badPos)
    check t.isHalted()

  test "Default tracker is halted":
    var t: Tracker
    check:
      t.isHalted()

  test "basic tracking":
    let song = block:
      var s = Song.init()
      s.speed = unitSpeed * 2
      s.trackLen = 2
      s
    var t = initTracker(song)
    check:
      t.isRunning()
      t.tick(song) == trackerResult(tsNewRow)
      t.pos() == songPos(0, 0)
      
      t.tick(song) == trackerResult(tsSteady)
      t.pos() == songPos(0, 0)
      
      t.tick(song) == trackerResult(tsNewRow)
      t.pos() == songPos(0, 1)

      t.tick(song) == trackerResult(tsSteady)
      t.pos() == songPos(0, 1)

      t.tick(song) == trackerResult(tsNewPattern)
      t.pos() == songPos(0, 0)

  test "effect filter":
    let song = block:
      var s = Song.init()
      s.speed = unitSpeed
      s.editTrack(ch1, 0, track):
        track[0] = litTrackRow("C-4 00 B01 V02 ...")
      s
    var t = initTracker(song, effectsFilter = { etPatternGoto })
    check:
      t.tick(song) == trackerResult(tsNewRow, false, {ch1}, {ch1})
      t.pos() == songPos(0, 0)
      not t.getOp(ch1).isNoop()

      t.tick(song) == trackerResult(tsNewRow)
      t.pos() == songPos(0, 1)
  
  test "Gxx effect":
    discard

  test "Bxx effect":
    discard

  test "C00 effect":
    discard

  test "Dxx effect":
    discard

  test "Fxx effect":
    discard

  test "forced halt":
    let s = Song.init()
    var t = initTracker(s)
    check:
      t.isRunning()
      t.pos() == songPos(0, 0)
      t.tick(s) == trackerResult(tsNewRow)
      t.isRunning()
    t.halt()
    check:
      t.isHalted()
      t.tick(s) == trackerResult()

  test "pattern repeat":
    let s = block:
      var s = Song.init()
      s.speed = unitSpeed
      s.trackLen = 2
      s.order.setLen(2)
      s
    var t = initTracker(s, patternRepeat = true)
    check:
      t.isRunning()
      t.tick(s) == trackerResult(tsNewRow)
      t.pos() == songPos(0, 0)
      t.tick(s) == trackerResult(tsNewRow)
      t.pos() == songPos(0, 1)
      t.tick(s) == trackerResult(tsNewRow)
      t.pos() == songPos(0, 0)
    t.patternRepeat = false
    check:
      t.tick(s) == trackerResult(tsNewRow)
      t.pos() == songPos(0, 1)
      t.tick(s) == trackerResult(tsNewPattern)
      t.pos() == songPos(1, 0)

import std/times
const minute = initDuration(minutes = 1)

suite "tracker.runtime":

  test "1 minute, default tickrate":
    check runtime(minute) == 3582
  
  test "1 minute, 60 Hz":
    check runtime(minute, 60.0) == 3600

  test "song 1":
    var song = Song.init()
    song.speed = unitSpeed
    song.trackLen = 1
    song.order.setLen(3)

    check:
      runtime(song, 1) == 3
      runtime(song, 2) == 6
      runtime(song, 3) == 9
  
  test "song 2":
    let song = Song.init()
    # 6.0 FPR * 64 rows per pattern = 384 frames per pattern
    check:
      runtime(song, 1) == 384
      runtime(song, 2) == 768
      runtime(song, 3) == 1152
  
  test "song 3":
    var song = Song.init()
    # 0 -> 1 -> 2 -> 3
    #      ^         |
    #      \---------/
    song.speed = unitSpeed
    song.trackLen = 4
    song.order.setLen(4)
    song.order[3] = [0u8, 0, 0, 1]
    song.editTrack(ch4, 3, track):
      track[3].effects[0] = litEffect("B01") #Effect.init(etPatternGoto, 1)
    
    check:
      runtime(song) == 16     # 4 + 4 + 4 + 4
      runtime(song, 2) == 28  # 16 + 4 + 4 + 4
      runtime(song, 3) == 40  # 28 + 4 + 4 + 4

  test "no runtime for pattern >= song order len":
    let song = Song.init()
    check:
      runtime(song, 1, songPos(1)) == 0
      runtime(song, 1, songPos(32)) == 0

  test "no runtime for row >= song.trackLen":
    var song = Song.init()
    song.trackLen = 10
    check:
      runtime(song, startPos = songPos(row = 10)) == 0
      runtime(song, startPos = songPos(row = 63)) == 0

suite "getPath":

  template pv(ppattern: int; prows: Slice[int]): SongSpan =
    songSpan(ppattern, prows.a, prows.b)

  test "default SongPath is invalid":
    let path = default(SongPath)
    check not path.isValid()

  test "default song has path of 1 visit and loops":
    let 
      song = Song.init()
      path = song.getPath()
    check:
      path.visits == [ pv(0, 0..63) ]
      path.loopsTo == some(0)

  test "simple song that loops":
    var song = Song.init()
    song.order.setLen(3)
    let path = song.getPath()
    check:
      path.visits == [ pv(0, 0..63), pv(1, 0..63), pv(2, 0..63) ]
      path.loopsTo == some(0)

  test "song that halts":
    var song = Song.init()
    song.order.setLen(2)
    song.order[1] = [ 0u8, 0u8, 0u8, 1u8]
    song.editTrack(ch4, 1, track):
      track.setEffect(23, 0, etPatternHalt)
    let path = song.getPath()
    check:
      path.visits == [ pv(0, 0..63), pv(1, 0..22) ]
      path.loopsTo == none(int)

  test "song loops via Bxx":
    var song = Song.init()
    song.order.setLen(3)
    song.order[2] = [ 0u8, 1, 0, 0 ]
    song.editTrack(ch2, 2, track):
      track.setEffect(63, 1, etPatternGoto, 1)
    let path = song.getPath()
    check:
      path.visits == [ pv(0, 0..63), pv(1, 0..63), pv(2, 0..63) ]
      path.loopsTo == some(1)

  test "song with Dxx":
    var song = Song.init()
    song.order.setLen(5)
    song.order[1] = [1u8, 0, 0, 0]
    song.order[2] = [2u8, 0, 0, 0]
    song.order[4] = [3u8, 0, 0, 0]
    song.editTrack(ch1, 1, track):
      track.setEffect(63, 0, etPatternSkip, 32)
    song.editTrack(ch1, 2, track):
      track.setEffect(63, 0, etPatternGoto, 4)
      # if we start this pattern from rows 0-31, we will go to pattern 3 next
      track.setEffect(31, 0, etPatternGoto, 3)
    song.editTrack(ch1, 4, track):
      track.setEffect(63, 0, etPatternGoto, 2)
    let path = song.getPath()
    check:
      path.visits == [ 
        pv(0, 0..63),
        pv(1, 0..63),
        pv(2, 32..63),
        pv(4, 0..63),
        pv(2, 0..31),
        pv(3, 0..63) 
      ]
      path.loopsTo == some(3)
