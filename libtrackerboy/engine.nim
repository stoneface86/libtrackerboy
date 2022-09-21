##[

The engine module is responsible for playing a song from a module. Similar
to a sound driver, the engine is stepped every frame and the APU's registers
are updated in order to play music.

]##

## common abbrievations
## fc - frequency control
## tc - track control
## mr - music runtime
## chno - channel number

import apuio, common, data
export common

# enginecontrol and apucontrol are technically part of this module
# they are split into two modules for unit testing
import private/[apucontrol, enginecontrol, enginestate, hardware]

import std/[options, with]

export Module, Song, ApuIo, EngineFrame

template withSome[T](opt: var Option[T], body: untyped): untyped =
    if opt.isSome():
        with opt.get():
            body

type
    Engine* = object
        ## Music/Sfx engine. Plays a Song, creating an ApuOperation that can
        ## be applied to an ApuIo object. The Engine does not interface with
        ## an ApuIo object directly, in order to reduce coupling and code
        ## duplication.
        musicRuntime: Option[MusicRuntime]
        #sfxRuntime...
        time: int
        patternRepeat: bool
        frame: EngineFrame
        apuOp: ApuOperation

func init*(_: typedesc[Engine]): Engine =
    discard  # default init is sufficient

func isHalted*(e: Engine): bool =
    e.musicRuntime.isNone() or e.frame.halted

proc lock*(e: var Engine, chno: ChannelId) =
    withSome e.musicRuntime, lock(chno, e.apuOp)

proc unlock*(e: var Engine, chno: ChannelId) =
    withSome e.musicRuntime, unlock(chno, e.apuOp)

proc jump*(e: var Engine, pattern: Natural) =
    withSome e.musicRuntime, jump(pattern)

proc halt*(e: var Engine) =
    withSome e.musicRuntime, halt(e.apuOp)

proc reset*(e: var Engine) =
    e.musicRuntime = none(MusicRuntime)
    e.time = 0
    e.apuOp = ApuOperation.default

proc play*(e: var Engine, song: sink Immutable[ref Song], pattern, row: Natural = 0) =
    
    doAssert not song.isNil, "song must not be nil!"
    
    if pattern >= song[].order.len:
        raise newException(IndexDefect, "invalid pattern index")
    if row >= song[].trackLen:
        raise newException(IndexDefect, "invalid row index")

    e.musicRuntime = some(MusicRuntime.init(song, pattern, row, e.patternRepeat))
    e.frame = EngineFrame(startedNewPattern: true)
    e.time = 0

proc step*(e: var Engine, itable: InstrumentTable) =
    if e.musicRuntime.isSome():
        e.frame.time = e.time
        e.frame.halted = e.musicRuntime.get().step(
            itable,
            e.frame,
            e.apuOp
        )

        if not e.frame.halted:
            inc e.time
    else:
        e.frame.halted = true

func currentFrame*(e: Engine): EngineFrame =
    result = e.frame

func currentSong*(e: Engine): Immutable[ref Song] =
    if e.musicRuntime.isSome():
        result = e.musicRuntime.get().song

proc takeOperation*(e: var Engine): ApuOperation =
    result = e.apuOp
    e.apuOp = ApuOperation.default

# diagnostic functions

template onSome[T](o: Option[T], body: untyped): untyped =
    if o.isSome():
        template it(): lent T = o.get()
        body

func currentState*(e: Engine, chno: ChannelId): ChannelState =
    onSome(e.musicRuntime):
        result = it.states[chno]

func currentNote*(e: Engine, chno: ChannelId): int =
    onSome(e.musicRuntime):
        result = it.trackControls[chno].fc.note.int

template getTrackParameter(e: Engine, chno: ChannelId, param: untyped): untyped =
    onSome(e.musicRuntime):
        result = it.trackControls[chno].param

func getTrackTimbre*(e: Engine, chno: ChannelId): uint8 =
    getTrackParameter(e, chno, timbre)

func getTrackEnvelope*(e: Engine, chno: ChannelId): uint8 =
    getTrackParameter(e, chno, envelope)

func getTrackPanning*(e: Engine, chno: ChannelId): uint8 =
    getTrackParameter(e, chno, panning)

# Apu stuff ===================================================================

proc setup*(apu: var ApuIo) =
    apu.writeRegister(rNR52, 0x00)
    apu.writeRegister(rNR52, 0x80)
    apu.writeRegister(rNR50, 0x77)

proc apply*(apu: var ApuIo, op: ApuOperation, wt: WaveformTable) =
    mixin getWrites, items
    for reg, val in getWrites(op, wt, apu.readRegister(rNR51)).items:
        apu.writeRegister(reg, val)

proc stepAndApply*(e: var Engine, itable: InstrumentTable, wtable: WaveformTable, apu: var ApuIo) =
    e.step(itable)
    apu.apply(e.takeOperation(), wtable)
