
import libtrackerboy/private/player as playerModule
import unittest2

type
  PlayerState = (bool, int, int)

const haltRow = 5

converter toPlayerState(p: Player): PlayerState =
  (p.isPlaying, p.progress, p.progressMax)

func stepTest(p: var Player; e: var Engine; it: InstrumentTable): PlayerState =
  discard p.step(e, it)
  p.toPlayerState()

func getSampleSongNoJump(): ref Song =
  result = Song.new()
  result.speed = unitSpeed
  result.trackLen = 1
  result[].order.setLen(3)

func getSampleSong2(): ref Song =
  result = Song.new()
  result.speed = unitSpeed
  result.trackLen = 1
  # 0 0 0 0
  # 1 1 1 1
  # 2 2 2 2
  result[].order.setLen(3)
  result[].order[1] = [1u8, 1, 1, 1]
  result[].order[2] = [2u8, 2, 2, 2]
  result[].editTrack(ch3, 2, track):
    track.setEffect(0, 0, etPatternGoto, 1)


func getSampleSong(): ref Song =
  result = Song.new()
  result.speed = unitSpeed
  result.trackLen = 1
  # 0 0 0 0
  # 0 0 0 0
  # 0 0 0 0
  # 0 0 0 1
  result[].order.setLen(4)
  result[].order[3] = [0u8, 0, 0, 1]
  result[].editTrack(ch4, 1, track):
    track.setEffect(0, 0, etPatternGoto, 1)

func getHaltingSong(): ref Song =
  result = Song.new()
  result.speed = unitSpeed
  result[].editTrack(ch2, 0, track):
    track.setEffect(haltRow, 0, etPatternHalt, 0)

suite "Player":
  setup:
    var
      p = default(Player)
      e = Engine.init()
      it = InstrumentTable.init()
  
  test "looping with B01":
    let song = toImmutable(getSampleSong2())
    p = Player.init(song, 2)
    e.play(song)
    check:
      p.stepTest(e, it) == (true, 0, 2) # pattern 0, row 0 (loop 0)
      p.stepTest(e, it) == (true, 0, 2) # pattern 1, row 0 (loop 0)
      p.stepTest(e, it) == (true, 0, 2) # pattern 2, row 0 (loop 0)
      p.stepTest(e, it) == (true, 1, 2) # pattern 1, row 0 (loop 1)
      p.stepTest(e, it) == (true, 1, 2) # pattern 2, row 0 (loop 1)
      p.stepTest(e, it) == (false, 2, 2) # pattern 1, row 0 (loop 2)
      p.stepTest(e, it) == (false, 2, 2) # pattern 2, row 0 (loop 2)
  
  test "looping with no jumps":
    let song = toImmutable(getSampleSongNoJump())
    p = Player.init(song, 2)
    e.play(song)
    check:
      p.stepTest(e, it) == (true, 0, 2) # pattern 0, row 0 (loop 0)
      p.stepTest(e, it) == (true, 0, 2) # pattern 1, row 0 (loop 0)
      p.stepTest(e, it) == (true, 0, 2) # pattern 2, row 0 (loop 0)
      p.stepTest(e, it) == (true, 1, 2) # pattern 0, row 0 (loop 1)
      p.stepTest(e, it) == (true, 1, 2) # pattern 1, row 0 (loop 1)
      p.stepTest(e, it) == (true, 1, 2) # pattern 2, row 0 (loop 1)
      p.stepTest(e, it) == (false, 2, 2) # pattern 0, row 0 (loop 2)
      p.stepTest(e, it) == (false, 2, 2) # pattern 1, row 0 (loop 2)

  test "default(Player) doesn't play":
    check:
      p.toPlayerState == (false, 0, 0)
      p.stepTest(e, it) == (false, 0, 0)
  
  test "frames":
    const testFrameCount = 10
    let song = toImmutable(getSampleSong())
    p = Player.init(testFrameCount)
    e.play(song)
    for i in 1..<testFrameCount:
      check p.stepTest(e, it) == (true, i, testFrameCount)
    check p.stepTest(e, it) == (false, testFrameCount, testFrameCount)


proc loopTestImpl(loops, runs: Natural): seq[PlayerState] =
  let song = getSampleSong()
  var player = Player.init(song.toImmutable, loops)
  var engine = Engine.init()
  var itable = InstrumentTable.init()
  engine.play(song.toImmutable)
  for i in 0..<runs:
    discard player.step(engine, itable)
    result.add(player.toPlayerState)

template loopTest(loops: Natural, expected: openArray[PlayerState]): untyped {.dirty.} =
  test "loops-" & $loops:
    const expectedData = expected
    let results = loopTestImpl(loops, expectedData.len)
    check results == expectedData


loopTest(0, [
  (false, 0, 0),
  (false, 0, 0)
])

loopTest(1, [
  (true, 0, 1),
  (true, 0, 1),
  (true, 0, 1),
  (true, 0, 1),
  (false, 1, 1),
  (false, 1, 1)
])

loopTest(2, [
  (true, 0, 2), # first visit to #0
  (true, 0, 2), # first visit to #1
  (true, 0, 2), # first visit to #2
  (true, 0, 2), # first visit to #3
  (true, 1, 2), # second visit to #1
  (true, 1, 2), # second visit to #2
  (true, 1, 2), # second visit to #3
  (false, 2, 2), # this would've been the third visit to #1, but we are looping twice so we stop here
  (false, 2, 2)
])

test "halts":
  let song = toImmutable(getHaltingSong())
  var 
    players = [
      Player.init(song, 3),
      Player.init(100)
    ]
    e = Engine.init()
    it = InstrumentTable.init()
  for p in players.mitems:
    e.play(song)
    for i in 0..haltRow+1:
      discard p.step(e, it)
    check not p.isPlaying

