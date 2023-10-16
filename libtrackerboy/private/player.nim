##[

.. include:: warning.rst

]##

import ../engine
import ../data

export engine, data

type

  PlayerContextKind = enum
    pckFrames,
    pckLoops

  PlayerContext = object
    case kind: PlayerContextKind
    of pckFrames:
      frameCounter: int
      framesToPlay: int
    of pckLoops:
      visits: seq[int]
      loopAmount: int
      progress: int
  Player* = object
    playing: bool
    context: PlayerContext

func init*(_: typedesc[Player], song: Immutable[ref Song], loops: Natural): Player =
  ## Creates a player to loop the given song a given number of times.
  ## If `song` is `nil` or `loops` is `0`, the resulting player will not play.
  if loops > 0 and song != nil:
    result.context = PlayerContext(
      kind: pckLoops,
      visits: newSeq[int](song[].order.len),
      loopAmount: loops
    )
    result.playing = true

func init*(_: typedesc[Player], frames: Natural): Player =
  ## Creates a new player that will play for a given number of frames.
  result.context = PlayerContext(
    kind: pckFrames,
    frameCounter: 0,
    framesToPlay: frames
  )
  result.playing = frames > 0

func init*(_: typedesc[Player], framerate: float, seconds: Natural): Player =
  ## Creates a new player that will play for a given number of seconds. The
  ## number of frames that are played is determined by the given framerate in
  ## units of frames per second (Hz).
  Player.init((seconds.float * framerate).Natural)

func isPlaying*(p: Player): bool =
  ## The player's playing status. The player is finished playing when the
  ## status is `false`.
  p.playing

func progress*(p: Player): int =
  ## Current progress until the player finishes. A number from 0 to `progressMax`
  ## will be returned. This value can be used to indicate progress to the
  ## user. The unit of this value depends on how the Player was initialized.
  case p.context.kind:
  of pckFrames:
    p.context.frameCounter
  of pckLoops:
    p.context.progress
    #p.context.visits[p.context.currentPattern]

func progressMax*(p: Player): int =
  ## Maximum value of the player's progress.
  case p.context.kind:
  of pckFrames:
    p.context.framesToPlay
  of pckLoops:
    p.context.loopAmount

proc step*(p: var Player, engine: var Engine, instruments: InstrumentTable): bool {.raises: [].} =
  ## Steps the engine if the player is currently playing.
  if p.playing:
    engine.step(instruments)
    let postframe = engine.currentFrame()

    case p.context.kind:
    of pckFrames:
      inc p.context.frameCounter
      if p.context.frameCounter >= p.context.framesToPlay:
        p.playing = false
    of pckLoops:
      if postframe.startedNewPattern:
        let pos = p.context.visits[postframe.order].addr
        p.context.progress = pos[]
        if pos[] == p.context.loopAmount:
          p.playing = false
        else:
          inc pos[] # update visit count for this pattern
    if postframe.halted:
      p.playing = false
  result = p.playing

template play*(p: var Player, engine: var Engine, instruments: InstrumentTable, body: untyped): untyped =
  ## Calls `p.step` until the player finishes playing, executing `body` for
  ## each step.
  while p.step(engine, instruments):
    body


# runnableExamples:

#     var e = Engine.init()
#     let song = Song.new()
#     let instruments = InstrumentTable.init()
#     e.play(song.toImmutable)
#     # loop the song twice
#     var p = Player.init(song.toImmutable, 2)
#     p.play(e, instruments):
#         # this block here is called on every frame that is stepped
#         discard
