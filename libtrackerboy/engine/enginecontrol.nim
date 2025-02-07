##[

Engine control.

This module contains the core components of `Engine`, and is responsible
for music and sound effect playback of TrackerBoy modules.

A brief overview of these components:
* fc, `FrequencyControl` - handles frequency calculation and effects. Each
  track has its own fc.
* ir, `InstrumentRuntime` - for performing an instrument by stepping through
  its sequences. Each track has its own ir, as one instrument is played per
  track.
* tc, `TrackControl` - handles the state of a channel for a track. It serves as
  a container for an fc and ir, and ticks them when it is ticked. A tc also
  handles note triggers and cuts.
* mr, `MusicRuntime` - handles the performance of a `Song`. It is a container
  for a tracker and each channel's tc. It also manages the state of each
  channel.

This module is part of the inner workings of the engine module, and has an
**unstable API**.

]##

import
  ./enginestate,
  ./frequency,
  ../data,
  ../ir,
  ../tracking

export
  enginestate

type
  SequenceInput = array[SequenceKind, Option[uint8]]
    ## Input data to pass to TrackControl and FrequencyControl from
    ## enumerated sequences
    ##

  InstrumentRuntime = object
    ## Performs an instrument by enumerating all of its sequences.
    ##
    instrument: iref[Instrument]
      ## A reference to the Instrument to perform. Use `nil` for no instrument.
      ## 
    sequenceCounters: array[SequenceKind, int]
      ## Each sequence's position. The value at this index will be yielded for
      ## the next step.
      ##

  NoteAction = enum
    naOff       ## not playing a note
    naSustain   ## keep playing the note
    naTrigger   ## trigger a new note
    naCut       ## cut the note

  TrackControl = object
    ## Modifies a ChannelState and GlobalState for a given TrackRow
    ##
    ir: InstrumentRuntime
    fc: FrequencyControl
    cutCounter: Counter
    noteStatus: Tristate
    envelope: uint8
    panning: uint8
    timbre: uint8
    state: ChannelState

  MusicRuntime* = object
    tracker: Tracker
    status: TrackerStatus
    states: array[ChannelId, ChannelState]
    trackControls: array[ChannelId, TrackControl]

  MusicResult* = object
    ## Result object from ticking a [MusicRuntime].
    ## - `halted`: `true` if the runtime halted at this tick
    ## - `locked`: A set of channels that were explicitly locked by the `L00` effect.
    ##
    halted*: bool
    locked*: set[ChannelId]

# === InstrumentRuntime =======================================================

proc trigger(r: var InstrumentRuntime) =
  reset(r.sequenceCounters)

proc setInstrument(r: var InstrumentRuntime; i: sink iref[Instrument]) =
  r.instrument = i
  r.trigger()

func hasValueAt(s: Sequence; index: int): bool =
  result = index < s.data.len

func nextIndex(s: Sequence; index: int): int =
  result = index + 1
  let seqlen = s.data.len
  if result >= seqlen:
    if s.loop.enabled and int(s.loop.index) < seqlen:
      result = int(s.loop.index)

proc tick(r: var InstrumentRuntime): SequenceInput =
  if r.instrument != nil:
    for kind, sequence in r.instrument[].sequences.pairs:
      let counter = r.sequenceCounters[kind]
      if sequence.hasValueAt(counter):
        result[kind] = some(sequence[counter])
        r.sequenceCounters[kind] = sequence.nextIndex(counter)

# === TrackControl ============================================================

func initTrackControl(ch: ChannelId): TrackControl =
  if ch == ch4:
    result.fc = initNoiseFrequencyControl()
    result.timbre = 0
  else:
    result.fc = initToneFrequencyControl()
    result.timbre = 3
  result.panning = 3
  result.envelope = if ch == ch3: 0 else: 0xF0

proc setOperation(tc: var TrackControl; itable: InstrumentTable; op: Operation) =
  if opsInstrument in op:
    let instrument = itable[op[opsInstrument]]
    if instrument != nil:
      tc.ir.setInstrument(instrument)
  
  template updateSetting(field: untyped) =
    const flag = `ops field`
    if flag in op:
      let val = op[flag]
      tc.field = val
      tc.state.field = val
  updateSetting(envelope)
  updateSetting(panning)
  updateSetting(timbre)

  if opsNote in op:
    tc.ir.trigger()
    tc.noteStatus = triTrans
    tc.state.envelope = tc.envelope
    tc.state.panning = tc.panning
    tc.state.timbre = tc.timbre
  
  tc.fc.setOperation(op)
  tc.cutCounter = block:
    if opsDuration in op:
      initCounter(int(op[opsDuration]))
    else:
      noCounter

proc tick(tc: var TrackControl): NoteAction =
  case tc.noteStatus
  of triOff: 
    return naOff
  of triTrans:
    result = naTrigger
    tc.noteStatus = triOn
  of triOn:
    result = naSustain
  
  if tc.cutCounter.tick():
    tc.noteStatus = triOff
    result = naCut
  else:
    let inputs = tc.ir.tick()
    tc.state.frequency = tc.fc.tick(inputs[skArp], inputs[skPitch])
    template passInput(field: untyped; maxVal = 255u8) =
      const kind = `sk field`
      if inputs[kind].isSome():
        when maxVal != 255:
          tc.state.field = min(inputs[kind].unsafeGet(), maxVal)
        else:
          tc.state.field = inputs[kind].unsafeGet()
    passInput(panning, 3)
    passInput(timbre, 3)
    passInput(envelope, 255)


func initMusicRuntime*(song: Song; startAt: SongPos; patternRepeat: bool
                       ): MusicRuntime =
  const state = initChannelState()
  result = MusicRuntime(
    tracker: initTracker(song, startAt, {}, patternRepeat),
    states: [state, state, state, state],
    trackControls: [
      initTrackControl(ch1),
      initTrackControl(ch2),
      initTrackControl(ch3),
      initTrackControl(ch4)
    ]
  )
  if result.tracker.isRunning():
    result.status = tsSteady

proc jump*(r: var MusicRuntime; song: Song; pattern: Natural) =
  r.tracker.jump(song, songPos(pattern, 0))

proc halt*(r: var MusicRuntime) =
  r.tracker.halt()
  r.status = tsHalted

func difference(state, prev: ChannelState;): UpdateFlags =
  template check(field: untyped) =
    if state.field != prev.field:
      result.incl(`uf field`)
  check(timbre)
  check(envelope)
  check(panning)
  check(frequency)

proc tick*(r: var MusicRuntime; song: Song; itable: InstrumentTable;
           unlocked: set[ChannelId]; apuOp: var ApuOperation
           ): MusicResult =
  ## Steps the runtime for 1 frame or tick. Returns `true` if the runtime
  ## halted or is currently halted. Afterwards, the `frame` variable will be
  ## updated with the details of the tick that was just stepped. Also, `op`
  ## will be updated with the necessary changes to the Apu as a result of this
  ## tick.
  ##
  let tresult = r.tracker.tick(song)
  r.status = tresult.status
  result.halted = tresult.status == tsHalted
  if not result.halted:
    # pass any tracked operations to their channel's track control
    for ch in tresult.ops:
      # set operation on the channel's track control
      let op = r.tracker.getOp(ch)
      r.trackControls[ch].setOperation(itable, op)
      if opsShouldLock in op and ch in unlocked:
        # L00 effect: force lock channel
        result.locked.incl(ch)
      
      # global effects (tracker handles C00 and Fxx)
      if opsVolume in op:
        apuOp.volume = some(op[opsVolume])
      if opsSweep in op:
        apuOp.sweep = some(op[opsSweep])
    
    # tick each track control, updating apuOp for each locked channel
    for ch in ChannelId:
      let action = r.trackControls[ch].tick()
      if ch notin unlocked:
        apuOp.updates[ch] = case action:
          of naOff:
            ChannelUpdate(action: caNone)
          of naSustain, naTrigger:
            let
              nextState = r.trackControls[ch].state
              currState = r.states[ch]
            r.states[ch] = nextState
            ChannelUpdate(
              action: caUpdate,
              flags: difference(nextState, currState),
              state: nextState,
              trigger: action == naTrigger
            )
          of naCut:
            ChannelUpdate(action: caCut)
    # sweep requires a retrigger
    if apuOp.sweep.isSome() and apuOp.updates[ch1].action == caUpdate:
      apuOp.updates[ch1].flags.incl(ufFrequency)
      apuOp.updates[ch1].trigger = true

# diagnostics

func status*(r: MusicRuntime): TrackerStatus {.inline.} =
  result = r.status

func speed*(r: MusicRuntime): Speed {.inline.} =
  result = r.tracker.speed()

func pos*(r: MusicRuntime): SongPos {.inline.} =
  result = r.tracker.pos()

func note*(r: MusicRuntime; ch: ChannelId): uint8 =
  result = r.trackControls[ch].fc.note

func trackState*(r: MusicRuntime; ch: ChannelId): ChannelState =
  result = r.states[ch]

func trackTimbre*(r: MusicRuntime; ch: ChannelId): uint8 =
  result = r.trackControls[ch].timbre

func trackPanning*(r: MusicRuntime; ch: ChannelId): uint8 =
  result = r.trackControls[ch].panning

func trackEnvelope*(r: MusicRuntime; ch: ChannelId): uint8 =
  result = r.trackControls[ch].envelope
