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

# Runtime calculation =========================================================

type
  PatternHistory = object
    # a history of rows visited in each pattern
    startRows: seq[set[ByteIndex]]

  SongPather = object
    # Used for path calculation and runtime calculation
    mr: MusicRuntime
    itable: InstrumentTable
    current: SongPos
    history: PatternHistory

  SongPath* = object
    ## Defines the path a song will take during performance. A song's path is
    ## the order in which patterns are encountered, or visited. The path also
    ## has an optional loop index, that indicates whether the song will loop
    ## to a previous visit or halt at the last visit.
    ## * `visits`: This seq contains the patterns that were visited, in order
    ##             of occurance.
    ## * `loopsTo`: Specifies the index of the visit the song will loop to
    ##              after the last visit. If not provided, then the song will
    ##              halt after the last visit.
    ##
    visits*: seq[SongPos]
    loopsTo*: Option[int]

func init(T: typedesc[PatternHistory]; totalPatterns: Positive
          ): PatternHistory =
  # initialize a pattern history for a given number of patterns
  result.startRows.setLen(totalPatterns)

proc add(h: var PatternHistory; visit: SongPos): bool =
  # Adds the visit to the history, returns `true` if this visit was already
  # added.
  let pslot = h.startRows[visit.pattern].addr
  result = visit.row in pslot[]
  pslot[].incl(visit.row)


func init(T: typedesc[SongPather]; song: Song; startPos: SongPos; ): SongPather =
  # initialize a song pather for the given song and starting position.
  result = SongPather(
    mr: MusicRuntime.init(toImmutable(unsafeAddr(song)), startPos.pattern, startPos.row, false),
    itable: InstrumentTable.init(),
    current: startPos,
    history: PatternHistory.init(song.order.len)
  )

proc nextVisit(sp: var SongPather; steps: ptr int = nil): bool =
  # calculate the next pattern visit, which is stored into `p.current`
  # if `steps` is provided, then the pointer's value is incremented with the
  # number of ticks that have been performed.
  var count = 0
  while true:
    var 
      frame: EngineFrame
      op: ApuOperation
    inc count
    if sp.mr.step(sp.itable, frame, op):
      result = true
      break
    if frame.startedNewPattern:
      sp.current.pattern = frame.order
      sp.current.row = frame.row
      result = false
      break
  if steps != nil:
    steps[] += count

proc addCurrentToHistory(sp: var SongPather): bool =
  # adds sp's current visit to its history, returning `true` if it was already
  # added.
  result = sp.history.add(sp.current)

func runtime*(song: Song; loopFor = Positive(1); startPos = default(SongPos)
              ): int =
  ## Gets the runtime in frames when playing a song.
  ## * `loopFor` is the number of times to loop
  ## * `startPos` is the starting position, default is start of the song
  ##
  ## The minimum runtime of a song is 1 frame, since 1 frame is required to be
  ## stepped in order for a song to halt.
  ##
  ## A runtime of 0 will be returned if `pattern` is greater than or equal to
  ## the song's order count or if `row` is greater than or equal to the song's
  ## track length. This means that the song cannot be played with these
  ## arguments and therefore has a runtime of 0 frames.
  ##

  if not song.validPosition(startPos):
    return 0

  var 
    sp = SongPather.init(song, startPos)
    pathOpen = true
    loopVisit: SongPos
    loopCount = 0
  
  while true:
    if sp.addCurrentToHistory():
      # we have revisited a previous visit
      if pathOpen:
        # close the path, mark this visit as the loop point
        pathOpen = false
        loopVisit = sp.current
      if loopVisit == sp.current:
        # loop point encountered, a single loop has been made
        inc loopCount
        if loopCount == loopFor:
          dec result # remove the extra step added during call to nextVisit
          # done: target number of loops has been reached
          break
    if sp.nextVisit(addr(result)):
      # done: no next visit since the song halted
      break
    
func runtime*(duration: Duration; framerate: float): int =
  ## Gets the runtime in frames when playing a song for a given time duration.
  ## 
  int(float(inSeconds(duration)) * framerate)

func runtime*(duration: Duration): int =
  ## Gets the runtime in frames when playing a song for a given time duration.
  ## The default framerate (DMG, 59.7 Hz) is used.
  ##
  const rate = defaultTickrate.hertz
  runtime(duration, rate)

# pathing

func isValid*(p: SongPath): bool =
  ## Determines if a path is valid, or has one or more visits.
  ##
  result = p.visits.len > 0

func getPath*(song: Song; startPos = default(SongPos)): SongPath =
  ## Determines the path, or the order in which patterns are visited when
  ## performing a song. The calculated `SongPath` is returned for the given
  ## song, when starting at a specified pattern and row (default is the start
  ## of the song).
  ## 
  ## If `startRow` or `startPattern` are invalid positions for `song`, then an
  ## empty SongPath is returned.
  ##

  # invalid positions result in an empty path
  if song.validPosition(startPos):
    var sp = SongPather.init(song, startPos)

    while true:
      if sp.addCurrentToHistory():
        # end of path: song loops
        result.loopsTo = some(find(result.visits, sp.current))
        break
      result.visits.add(sp.current)

      # determine the next pattern that will be visited
      if sp.nextVisit():
        # end of path: song halted
        break 

{. pop .}
