
import libtrackerboy/private/player as playerModule
import ../testing

testclass "player"

type
    PlayerState = (bool, int, int)

const haltRow = 5

converter toPlayerState(p: Player): PlayerState =
    (p.isPlaying, p.progress, p.progressMax)


func getSampleSong(): ref Song =
    result = Song.new()
    result.speed = unitSpeed
    result[].setTrackLen(1)
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


dtest "default(Player) doesn't play":
    var player = Player.default
    var e = Engine.init()
    var it = InstrumentTable.init()
    checkout:
        player.toPlayerState == (false, 0, 0)
        not player.step(e, it)
        player.toPlayerState == (false, 0, 0)

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
    dtest "loops-" & $loops:
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

dtest "halts":
    let song = getHaltingSong()
    var players = [
        Player.init(song.toImmutable, 3),
        Player.init(100)
    ]
    var engine = Engine.init()
    var itable = InstrumentTable.init()
    for player in players.mitems:
        engine.play(song.toImmutable)
        for i in 0..haltRow+1:
            discard player.step(engine, itable)
        check not player.isPlaying


dtest "frames":
    const testFrameCount = 10
    let song = getSampleSong()
    var player = Player.init(testFrameCount)  # olay 10 frames
    var engine = Engine.init()
    var itable = InstrumentTable.init()
    engine.play(song.toImmutable)

    checkout player.progressMax == testFrameCount
    for i in 0..<testFrameCount:
        checkout:
            player.isPlaying
            player.progress == i
        discard player.step(engine, itable)
    checkout:
        not player.isPlaying
        player.progress == player.progressMax
