##[

Module provides a Player object for stepping an engine for a given number of
frames, seconds, or loops through the song.

]##

runnableExamples:

    type SomeApu = object

    proc writeRegister(a: var SomeApu, reg, val: uint8) = discard
    func readRegister(a: SomeApu, reg: uint8): uint8 = discard

    var apu: SomeApu
    var engine: Engine.init()
    var module = Module.new()
    engine.module = module.toCRef
    engine.play()
    var p = Player.init(engine, 2.loops)
    while p.isPlaying:
        p.step(engine, apu)
        

import engine as engineModule

type

    DurationUnit* = enum
        duSeconds
        duFrames
        duLoops

    Duration* = object
        unit: DurationUnit
        amount: Natural

    PlayerContextKind = enum
        pckFrames,
        pckLoops

    PlayerContext = object
        case kind: PlayerContextKind
        of pckFrames:
            frameCounter: int
            framesToPlay: int
        of pckLoops:
            currentPattern: int
            visits: seq[int]
            loopAmount: int

    Player* = object
        lastFrame: EngineFrame
        playing: bool
        context: PlayerContext

func seconds*(amount: Natural): Duration =
    Duration(unit: duSeconds, amount: amount)

template minutes*(amount: Natural): Duration =
    seconds(amount * 60)

func frames*(amount: Natural): Duration =
    Duration(unit: duFrames, amount: amount)

func loops*(amount: Natural): Duration =
    Duration(unit: duLoops, amount: amount)

func init*(T: typedesc[Player], engine: Engine, d: Duration): Player =
    case d.kind:
    of duSeconds:
        # determine the number of frames to play
        if d.amount > 0:
            let module = engine.module
            if module != nil:
                result.context = PlayerContext(
                    kind: pckFrames,
                    framesToPlay: (d.amount * module.framerate()).int
                )
                result.playing = result.context.framesToPlay > 0
    of duFrames:
        result.context = PlayerContext(
            kind: pckFrames,
            frameCounter: 0,
            framesToPlay: d.amount
        )
        result.playing = d.amount > 0
    of duLoops:
        if d.amount > 0:
            let song = engine.currentSong()
            if song != nil:
                result.context = PlayerContext(
                    kind: pckLoops,
                    visits: newSeq[int](song[].order.len),
                    loopAmount: d.amount
                )
                result.visits[0] = 1 # visit the first pattern
                result.playing = true

func isPlaying*(p: Player): bool =
    p.playing

func progress*(p: Player): int =
    case p.context.kind:
    of pckFrames:
        p.context.frameCounter
    of pckLoops:
        p.context.visits[p.context.currentPattern]

func progressMax*(p: Player): int =
    case p.context.kind:
    of pckFrames:
        p.context.framesToPlay
    of pckLoops:
        p.context.loopAmount

proc stepImpl(p: var Player, frame: EngineFrame) =
    case p.context.kind:
    of pckFrames:
        inc p.context.frameCounter
        if p.context.frameCounter >= p.context.framesToPlay:
            p.playing = false
    of pckLoops:
        if frame.startedNewPattern:
            let pos = p.context.visits[frame.order].addr
            if pos[] == p.context.loopAmount:
                p.playing = false
            else:
                inc pos[] # update visit count for this pattern
            p.context.currentPattern = frame.order
    p.lastFrame = frame

proc step*(p: var Player, engine: var Engine, apu: var ApuIo) =
    if p.playing:
        engine.step(apu)
        p.stepImpl(engine.currentFrame())
