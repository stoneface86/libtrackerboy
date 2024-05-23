##[

.. importdoc:: apuio.nim
.. importdoc:: data.nim
.. importdoc:: engine/enginestate.nim

The engine module is responsible for playing a song from a module. Similar
to a sound driver, the engine is "ticked" or iterated for a single frame and
the APU's registers are updated in order to play music.

There are two parts to this module: the engine itself and interfacing with an
ApuIo.

## Engine

This module provides an [Engine object] type that handles the performance of a
[Song] (and sound effects, in the future).

To create an engine, initialize one with [initEngine]. Then give
it a song to play via the [play] proc. Reference semantics are used so you
will need a `ref Song` when playing it. Afterwards, you can call [step] to
perform a single tick of the engine.

There are also other procs for controlling playback, as well as informational
ones for diagnostics.

## ApuIo interface

The engine creates an [ApuOperation] every tick. This object can be converted
into register writes and then sent to an [ApuIo].

]##

import
  std/[setutils],

  ./apuio,
  ./common,
  ./data,
  ./engine/apucontrol,
  ./engine/enginestate,
  ./engine/enginecontrol,
  ./private/hardware,
  ./private/utils

export
  apuio,
  common,
  data,
  enginestate

type
  Engine* = object
    ## Music/Sfx engine. Plays a Song, creating an ApuOperation that can
    ## be applied to an ApuIo object. The Engine does not interface with
    ## an ApuIo object directly, in order to reduce coupling and code
    ## duplication.
    ## 
    song: iref[Song]
    musicRuntime: MusicRuntime
    #sfxRuntime...
    unlocked: set[ChannelId]
    time: int
    patternRepeat: bool
    apuOp: ApuOperation

{. push raises: [] .}

func initEngine*(): Engine =
  ## Constructs a new Engine.
  ##
  defaultInit(result)

func isPlaying*(e: Engine): bool = 
  ## Determine if the engine is playing music, or if it contains a [Song].
  ##
  result = e.song != nil

func isHalted*(e: Engine): bool =
  ## Determines if the current song being played has halted. If there is no
  ## song playing, `true` is returned.
  ##
  result = e.song.isNil() or e.musicRuntime.status() == tsHalted

func isLocked*(e: Engine; chno: ChannelId): bool =
  ## Check if a channel is locked for music playback by the engine. `true` is
  ## returned if `chno` is locked, `false` when unlocked.
  ##
  result = chno notin e.unlocked

func locked*(e: Engine): set[ChannelId] =
  ## Gets a set of the engine's locked channels. This is just the complement
  ## of `e.getUnlocked()`.
  ##
  result = complement(e.unlocked)

func unlocked*(e: Engine): set[ChannelId] {.inline.} =
  ## Gets a set of the engine's unlocked channels.
  ##
  result = e.unlocked

proc lock*(e: var Engine; chno: ChannelId) =
  ## Locks the given channel for music playback. Function does nothing if
  ## there is no music currently playing.
  ##
  if chno in e.unlocked:
    e.unlocked.excl(chno)
    if e.isPlaying():
      e.apuOp.updates[chno] = ChannelUpdate(
        action: caUpdate,
        flags: updateAll,
        state: e.musicRuntime.trackState(chno)
      )

proc unlock*(e: var Engine; chno: ChannelId) =
  ## Unlocks the given channel, music will no longer play on this channel.
  ## Use `lock` to restore music playback. Function does nothing if there is
  ## no music currently playing.
  ##
  if chno notin e.unlocked:
    e.unlocked.incl(chno)
    e.apuOp.updates[chno] = ChannelUpdate(action: caShutdown)
    
proc jump*(e: var Engine; pattern: Natural) =
  ## Jump to the given pattern in the currently playing song.
  ##
  if e.isPlaying():
    e.musicRuntime.jump(e.song[], pattern)

proc halt*(e: var Engine) =
  ## Halts the engine, or forces the current song to halt. Function does
  ## nothing if there is no music currently playing.
  ##
  if e.isPlaying():
    e.musicRuntime.halt()
    for ch in e.locked():
      e.apuOp.updates[ch] = ChannelUpdate(action: caShutdown)

proc reset*(e: var Engine) =
  ## Resets the engine to default state.
  ##
  e.song.reset()
  reset(e.musicRuntime)
  e.time = 0
  reset(e.apuOp)

proc play*(e: var Engine; song: sink iref[Song]; startAt = default(SongPos)) =
  ## Sets the engine to begin playback of the given song. `song` must not be
  ## `nil`, otherwise an `AssertDefect` will be raised. By default, the engine
  ## will play the song from the start, or pattern 0, row 0. You can override
  ## this position via the `startAt` parameter. If `startAt` is an invalid
  ## position then the engine will be halted.
  ## 
  ## Afterwards, the song can be played by calling `tick` periodically.
  ## 
  doAssert not song.isNil, "song must not be nil!"

  e.song = song
  e.musicRuntime = initMusicRuntime(song[], startAt, e.patternRepeat)
  e.time = 0

proc tick*(e: var Engine; itable: InstrumentTable) =
  ## Steps the engine for a single frame or 1 tick.
  ##
  if e.isPlaying():
    let mresult = e.musicRuntime.tick(e.song[], itable, e.unlocked, e.apuOp)
    for ch in mresult.locked:
      e.lock(ch)
    if not mresult.halted:
      inc e.time

func frame*(e: Engine): EngineFrame =
  ## Gets the current frame, or the current state, of the Engine
  ##
  if e.isPlaying():
    result.status = e.musicRuntime.status()
    result.speed = e.musicRuntime.speed()
    result.time = e.time - 1
    result.pos = e.musicRuntime.pos()

func song*(e: Engine): iref[Song] =
  ## Gets the current song that is playing, `nil` is returned if there is
  ## no song playing.
  ## 
  result = e.song

proc takeOperation*(e: var Engine): ApuOperation =
  ## Takes out the operation to be applied to an ApuIo. Should be called after
  ## `tick` to apply register writes to an Apu.
  ##
  result = e.apuOp
  reset(e.apuOp)

# diagnostic functions

func note*(e: Engine; chno: ChannelId): int =
  ## Gets the current note, as a note index, being played for the given
  ## channel. `0` is returned if no music is playing.
  ## 
  if e.isPlaying():
    result = int(e.musicRuntime.note(chno))

template trackParameter(e: Engine; chno: ChannelId; param: untyped
                           ): untyped =
  if e.isPlaying():
    result = `track param`(e.musicRuntime, chno)

func trackState*(e: Engine; chno: ChannelId): ChannelState =
  ## Gets the current channel state of the given channel. An empty channel
  ## state is returned if no music is playing.
  ##
  if e.isPlaying():
    result = e.musicRuntime.trackState(chno)

func trackTimbre*(e: Engine; chno: ChannelId): uint8 =
  ## Gets the track's current timbre setting, for the given channel. Timbre
  ## is a channel-specific setting that ranges in value from 0-3. `0u8` is
  ## returned if no music is playing.
  ## 
  trackParameter(e, chno, timbre)

func trackEnvelope*(e: Engine; chno: ChannelId): uint8 =
  ## Gets the track's current envelope setting, for the given channel. The
  ## envelope setting is either a volume envelope value or a waveform id.
  ## `0u8` is returned if no music is playing.
  ## 
  trackParameter(e, chno, envelope)

func trackPanning*(e: Engine; chno: ChannelId): uint8 =
  ## Gets the track's current panning setting, for the given channel. Panning
  ## ranges in value from 0-3. `0u8` is returned if no music is playing.
  ## 
  trackParameter(e, chno, panning)

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
  for reg, val in items(getWrites(op, wt, apu.readRegister(rNR51))):
    apu.writeRegister(reg, val)

proc tickAndApply*(e: var Engine; itable: InstrumentTable;
                   wtable: WaveformTable; apu: var ApuIo
                   ) =
  ## Convenience proc that calls `e.tick` and `apu.apply` in one go.
  ##
  e.tick(itable)
  apu.apply(e.takeOperation(), wtable)

{. pop .}
