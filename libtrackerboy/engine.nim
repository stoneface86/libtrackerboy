##[

.. importdoc:: apuio.nim

The engine module is responsible for playing a song from a module. Similar
to a sound driver, the engine is stepped every frame and the APU's registers
are updated in order to play music.

There are three parts to this module: the engine itself, interfacing with an
ApuIo, and some utility calculation procs.

## Engine

This module provides an [Engine] type that handles the performance of a `Song`
(and sound effects, in the future).

To create an engine, initialize one with [init(typedesc[Engine])]. Then give
it a song to play via the [play] proc. Reference semantics are used so you
will need a `ref Song` when playing it. Afterwards, you can call [step] to
perform a single tick of the engine.

There are also other procs for controlling playback, as well as informational
ones for diagnostics.

## ApuIo interface

The engine creates an [ApuOperation] every step. This object can be converted
into register writes and then sent to an [ApuIo].

## Runtime calculation and pathing

There are also some utility procs for determining the runtime, in ticks, of
a song, as well as the order of patterns it will go through (the path).

Use any overload of the `runtime` procs to get a song's runtime. Use [getPath]
to get a [SongPath] for a `Song`.

]##

# common abbrievations
# fc - frequency control
# tc - track control
# mr - music runtime
# chno - channel number

import
  ./apuio,
  ./common,
  ./data,

  ./engine/apucontrol,
  ./engine/enginestate,
  ./engine/enginecontrol,

  ./private/hardware,
  ./private/optionutils

import std/[options, times]

export common, times
export Module, Song, SongPos    # data
export ApuIo                    # apuio
export EngineFrame              # enginestate

type
  Engine* = object
    ## Music/Sfx engine. Plays a Song, creating an ApuOperation that can
    ## be applied to an ApuIo object. The Engine does not interface with
    ## an ApuIo object directly, in order to reduce coupling and code
    ## duplication.
    ## 
    song: Immutable[ref Song]
    musicRuntime: Option[MusicRuntime]
    #sfxRuntime...
    time: int
    patternRepeat: bool
    frame: EngineFrame
    apuOp: ApuOperation

{. push raises: [] .}

func init*(T: typedesc[Engine]): Engine =
  ## Constructs a new Engine.
  ##
  discard  # default init is sufficient

func isHalted*(e: Engine): bool =
  ## Determines if the current song being played has halted. If there is no
  ## song playing, `true` is returned.
  ##
  e.musicRuntime.isNone() or e.frame.halted

proc lock*(e: var Engine; chno: ChannelId) =
  ## Locks the given channel for music playback. Function does nothing if
  ## there is no music currently playing.
  ##
  withSome e.musicRuntime, lock(chno, e.apuOp)

proc unlock*(e: var Engine; chno: ChannelId) =
  ## Unlocks the given channel, music will no longer play on this channel.
  ## Use `lock` to restore music playback. Function does nothing if there is
  ## no music currently playing.
  ##
  withSome e.musicRuntime, unlock(chno, e.apuOp)

proc jump*(e: var Engine; pattern: Natural) =
  ## Jump to the given pattern in the currently playing song.
  ##
  withSome e.musicRuntime, jump(pattern)

proc halt*(e: var Engine) =
  ## Halts the engine, or forces the current song to halt. Function does
  ## nothing if there is no music currently playing.
  ##
  withSome e.musicRuntime, halt(e.apuOp)

proc reset*(e: var Engine) =
  ## Resets the engine to default state.
  ##
  e.song.reset()
  e.musicRuntime = none(MusicRuntime)
  e.time = 0
  e.apuOp = ApuOperation.default

proc play*(e: var Engine; song: sink Immutable[ref Song];
           startAt = default(SongPos)) =
  ## Sets the engine to begin playback of the given song. `song` must not be
  ## `nil`. By default, the engine will play the song from the start, or
  ## pattern 0, row 0. You can override this position via the `pattern` and
  ## `row` parameters. An IndexDefect will be raised if these parameters are
  ## out of bounds for the given `song`.
  ## 
  ## Afterwards, the song can be played by calling `step` periodically.
  ## 
  doAssert not song.isNil, "song must not be nil!"
  
  if startAt.pattern >= song[].order.len:
    raise newException(IndexDefect, "invalid pattern index")
  if startAt.row >= song[].trackLen:
    raise newException(IndexDefect, "invalid row index")

  e.song = song
  e.musicRuntime = some(
    MusicRuntime.init(
      cast[Immutable[ptr Song]](song),
      startAt.pattern,
      startAt.row,
      e.patternRepeat
    )
  )
  e.frame = EngineFrame(startedNewPattern: true)
  e.time = 0

proc step*(e: var Engine; itable: InstrumentTable) =
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
  ##
  result = e.frame

func currentSong*(e: Engine): Immutable[ref Song] =
  ## Gets the current song that is playing, `nil` is returned if there is
  ## no song playing.
  ## 
  e.song

proc takeOperation*(e: var Engine): ApuOperation =
  ## Takes out the operation to be applied to an ApuIo. Should be called after
  ## `step` to apply register writes to an Apu.
  ##
  result = e.apuOp
  e.apuOp = ApuOperation.default

# diagnostic functions

func currentState*(e: Engine; chno: ChannelId): ChannelState =
  ## Gets the current channel state of the given channel. An empty channel
  ## state is returned if no music is playing.
  ## 
  onSome(e.musicRuntime):
    result = it.currentState(chno)

func currentNote*(e: Engine; chno: ChannelId): int =
  ## Gets the current note, as a note index, being played for the given
  ## channel. `0` is returned if no music is playing.
  ## 
  onSome(e.musicRuntime):
    result = it.currentNote(chno)

template getTrackParameter(e: Engine; chno: ChannelId; param: untyped
                          ): untyped =
  onSome(e.musicRuntime):
    result = `track param`(it, chno)

func getTrackTimbre*(e: Engine; chno: ChannelId): uint8 =
  ## Gets the track's current timbre setting, for the given channel. Timbre
  ## is a channel-specific setting that ranges in value from 0-3. `0u8` is
  ## returned if no music is playing.
  ## 
  getTrackParameter(e, chno, timbre)

func getTrackEnvelope*(e: Engine; chno: ChannelId): uint8 =
  ## Gets the track's current envelope setting, for the given channel. The
  ## envelope setting is either a volume envelope value or a waveform id.
  ## `0u8` is returned if no music is playing.
  ## 
  getTrackParameter(e, chno, envelope)

func getTrackPanning*(e: Engine; chno: ChannelId): uint8 =
  ## Gets the track's current panning setting, for the given channel. Panning
  ## ranges in value from 0-3. `0u8` is returned if no music is playing.
  ## 
  getTrackParameter(e, chno, panning)

func isLocked*(e: Engine; chno: ChannelId): bool =
  ## Check if a channel is locked for music playback by the engine. `true` is
  ## returned if `chno` is locked, `false` when unlocked.
  ##
  onSome(e.musicRuntime):
    result = it.isLocked(chno)

func getLocked*(e: Engine): set[ChannelId] =
  ## Gets a set of the engine's locked channels.
  ##
  onSome(e.musicRuntime):
    result = it.getLocked()

# Apu stuff ===================================================================

proc setup*(apu: var ApuIo) =
  ## Performs the necessary APU writes to allow for music playback with the
  ## engine. This proc should only need to be called once on an Apu.
  ##
  apu.writeRegister(rNR52, 0x00)
  apu.writeRegister(rNR52, 0x80)
  apu.writeRegister(rNR50, 0x77)

proc apply*(apu: var ApuIo; op: ApuOperation; wt: WaveformTable) =
  ## Applys an ApuOperation to an ApuIo, by performing the register writes
  ## specified in `op`. `wt` is the waveform table to use for CH3 when
  ## setting waveforms.
  ## 
  mixin getWrites, items
  for reg, val in getWrites(op, wt, apu.readRegister(rNR51)).items:
    apu.writeRegister(reg, val)

proc stepAndApply*(e: var Engine; itable: InstrumentTable;
                   wtable: WaveformTable; apu: var ApuIo) =
  ## Convenience proc that calls `e.step` and `apu.apply` in one go.
  ##
  e.step(itable)
  apu.apply(e.takeOperation(), wtable)

{. pop .}
