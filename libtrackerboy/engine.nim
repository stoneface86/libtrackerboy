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
  ## Determines if the current song being played has halted. If there is no
  ## song playing, `true` is returned.
  e.musicRuntime.isNone() or e.frame.halted

proc lock*(e: var Engine, chno: ChannelId) =
  ## Locks the given channel for music playback. Function does nothing if
  ## there is no music currently playing.
  withSome e.musicRuntime, lock(chno, e.apuOp)

proc unlock*(e: var Engine, chno: ChannelId) =
  ## Unlocks the given channel, music will no longer play on this channel.
  ## Use `lock` to restore music playback. Function does nothing if there is
  ## no music currently playing.
  withSome e.musicRuntime, unlock(chno, e.apuOp)

proc jump*(e: var Engine, pattern: Natural) =
  ## Jump to the given pattern in the currently playing song.
  withSome e.musicRuntime, jump(pattern)

proc halt*(e: var Engine) =
  ## Halts the engine, or forces the current song to halt. Function does
  ## nothing if there is no music currently playing.
  withSome e.musicRuntime, halt(e.apuOp)

proc reset*(e: var Engine) =
  ## Resets the engine to default state.
  e.musicRuntime = none(MusicRuntime)
  e.time = 0
  e.apuOp = ApuOperation.default

proc play*(e: var Engine, song: sink Immutable[ref Song], pattern, row: Natural = 0) =
  ## Sets the engine to begin playback of the given song. `song` must not be
  ## `nil`. By default, the engine will play the song from the start, or
  ## pattern 0, row 0. You can override this position via the `pattern` and
  ## `row` parameters. An IndexDefect will be raised if these parameters are
  ## out of bounds for the given `song`.
  ## 
  ## Afterwards, the song can be played by calling `step` periodically.
  ## 
  doAssert not song.isNil, "song must not be nil!"
  
  if pattern >= song[].order.len:
    raise newException(IndexDefect, "invalid pattern index")
  if row >= song[].trackLen:
    raise newException(IndexDefect, "invalid row index")

  e.musicRuntime = some(MusicRuntime.init(song, pattern, row, e.patternRepeat))
  e.frame = EngineFrame(startedNewPattern: true)
  e.time = 0

proc step*(e: var Engine, itable: InstrumentTable) =
  ## Steps for a single frame or "ticks" the engine.
  ## 
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
  ## Gets the current frame, or the current state, of the Engine
  result = e.frame

func currentSong*(e: Engine): Immutable[ref Song] =
  ## Gets the current song that is playing, `nil` is returned if there is
  ## no song playing.
  ## 
  if e.musicRuntime.isSome():
    result = e.musicRuntime.get().song

proc takeOperation*(e: var Engine): ApuOperation =
  ## Takes out the operation to be applied to an ApuIo. Should be called after
  ## `step` to apply register writes to an Apu.
  result = e.apuOp
  e.apuOp = ApuOperation.default

# diagnostic functions

template onSome[T](o: Option[T], body: untyped): untyped =
  if o.isSome():
    template it(): lent T = o.get()
    body

func currentState*(e: Engine, chno: ChannelId): ChannelState =
  ## Gets the current channel state of the given channel. An empty channel
  ## state is returned if no music is playing.
  ## 
  onSome(e.musicRuntime):
    result = it.states[chno]

func currentNote*(e: Engine, chno: ChannelId): int =
  ## Gets the current note, as a note index, being played for the given
  ## channel. `0` is returned if no music is playing.
  ## 
  onSome(e.musicRuntime):
    result = it.trackControls[chno].fc.note.int

template getTrackParameter(e: Engine, chno: ChannelId, param: untyped): untyped =
  onSome(e.musicRuntime):
    result = it.trackControls[chno].param

func getTrackTimbre*(e: Engine, chno: ChannelId): uint8 =
  ## Gets the track's current timbre setting, for the given channel. Timbre
  ## is a channel-specific setting that ranges in value from 0-3. `0u8` is
  ## returned if no music is playing.
  ## 
  getTrackParameter(e, chno, timbre)

func getTrackEnvelope*(e: Engine, chno: ChannelId): uint8 =
  ## Gets the track's current envelope setting, for the given channel. The
  ## envelope setting is either a volume envelope value or a waveform id.
  ## `0u8` is returned if no music is playing.
  ## 
  getTrackParameter(e, chno, envelope)

func getTrackPanning*(e: Engine, chno: ChannelId): uint8 =
  ## Gets the track's current panning setting, for the given channel. Panning
  ## ranges in value from 0-3. `0u8` is returned if no music is playing.
  ## 
  getTrackParameter(e, chno, panning)

# Apu stuff ===================================================================

proc setup*(apu: var ApuIo) =
  ## Performs the necessary APU writes to allow for music playback with the
  ## engine.
  apu.writeRegister(rNR52, 0x00)
  apu.writeRegister(rNR52, 0x80)
  apu.writeRegister(rNR50, 0x77)

proc apply*(apu: var ApuIo, op: ApuOperation, wt: WaveformTable) =
  ## Applys an ApuOperation to an ApuIo, by performing the register writes
  ## specified in `op`. `wt` is the waveform table to use for CH3 when
  ## setting waveforms.
  ## 
  mixin getWrites, items
  for reg, val in getWrites(op, wt, apu.readRegister(rNR51)).items:
    apu.writeRegister(reg, val)

proc stepAndApply*(e: var Engine, itable: InstrumentTable, wtable: WaveformTable, apu: var ApuIo) =
  ## Convenience proc that calls `e.step` and `apu.apply` in one go.
  e.step(itable)
  apu.apply(e.takeOperation(), wtable)
