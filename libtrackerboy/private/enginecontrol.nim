##[

.. include:: warning.rst

]##

import enginestate
import ../data, ../notes

import std/[bitops, options, with]

type
  Counter = distinct int

  FrequencyMod* = enum
    freqNone
    freqPortamento
    freqPitchUp
    freqPitchDown
    freqNoteUp
    freqNoteDown
    freqArpeggio

  FcMode* = enum
    fcmNone,
    fcmPortamento,
    fcmPitchSlide,
    fcmNoteSlide,
    fcmArpeggio

  Operation* = object
    ## An Operation is the processed form of a TrackRow, that is ready to
    ## be perfomed by the TrackControl
    patternCommand*: PatternCommand
    patternCommandParam*: uint8
    speed*: uint8
    volume*: Option[uint8]
    halt*: bool
    note*: Option[uint8]
    instrument*: Option[uint8]
    delay*: uint8
    duration*: Option[uint8]
    envelope*: Option[uint8]
    timbre*: Option[uint8]
    panning*: Option[uint8]
    sweep*: Option[uint8]
    freqMod*: FrequencyMod
    freqModParam*: uint8
    vibrato*: Option[uint8]
    vibratoDelay*: Option[uint8]
    tune*: Option[uint8]

  SequenceInput* = array[SequenceKind, Option[uint8]]
    ## Input data to pass to TrackControl and FrequencyControl from
    ## enumerated sequences

  InstrumentRuntime* = object
    ## Enumerates all sequences in an instrument
    instrument*: Immutable[ref Instrument]
    sequenceCounters*: array[SequenceKind, int]

  FrequencyLookupFunc* = proc(note: Natural): uint16 {.nimcall, noSideEffect.}

  FrequencyBounds* = object
    maxFrequency*: uint16
    maxNote*: uint8
    lookupFn*: FrequencyLookupFunc

  FrequencyControl* = object
    ## Handles frequency calculation for a channel
    bounds*: FrequencyBounds
    mode*: FcMode
    note*: uint8
    tune*: int8
    frequency*: uint16
    # pitch slide
    slideAmount*: uint8
    slideTarget*: uint16
    instrumentPitch*: int16
    # arpeggio
    chordOffset1*: uint8
    chordOffset2*: uint8
    chordIndex*: uint8
    chord*: array[0u8..2u8, uint16]
    # vibrato
    vibratoEnabled*: bool
    vibratoDelayCounter*: uint8
    vibratoCounter*: uint8
    vibratoValue*: int8
    vibratoDelay*: uint8
    vibratoParam*: uint8

  NoteAction* = enum
    naOff       ## not playing a note
    naSustain   ## keep playing the note
    naTrigger   ## trigger a new note
    naCut       ## cut the note

  TrackControl* = object
    ## Modifies a ChannelState and GlobalState for a given TrackRow
    op*: Operation
    ir*: InstrumentRuntime
    fc*: FrequencyControl
    delayCounter*: Counter #Option[int]
    cutCounter*: Counter #Option[int]
    playing*: bool
    envelope*: uint8
    panning*: uint8
    timbre*: uint8
    state*: ChannelState

  Timer* = object
    period*, counter*: int

  MusicRuntime* = object
    song*: Immutable[ref Song]
    halted*: bool
    orderCounter*: int
    rowCounter*: int
    patternRepeat*: bool
    timer*: Timer
    global*: GlobalState
    unlocked*: set[ChannelId]
    states*: array[ChannelId, ChannelState]
    trackControls*: array[ChannelId, TrackControl]

func noCounter(): Counter = discard
func counter(v: int): Counter = (v + 1).Counter

proc step(c: var Counter): bool =
  if c.int > 0:
    c = (c.int - 1).Counter
    result = c.int == 0

func identityLookup(note: Natural): uint16 = note.uint16

const
  toneFrequencyBounds = FrequencyBounds(
    maxFrequency: 2047,
    maxNote: high(ToneNote).uint8,
    lookupFn: lookupToneNote
  )
  noiseFrequencyBounds = FrequencyBounds(
    maxFrequency: high(NoiseNote).uint16,
    maxNote: high(NoiseNote).uint8,
    lookupFn: identityLookup
  )

proc setBit[T: SomeInteger](v: var T; bit: BitsRange[T]; val: bool) {.inline.} =
  if val:
    v.setBit(bit)
  else:
    v.clearBit(bit)

# === Timer ===================================================================

func init(T: typedesc[Timer], speed: Speed): Timer =
  result = Timer(
    period: speed.int,
    counter: 0
  )

func active(t: Timer): bool =
  t.counter < unitSpeed

proc setPeriod(t: var Timer, speed: Speed) =
  t.period = clamp(speed, low(Speed), high(Speed)).int
  # if the counter exceeds the new period, clamp it to 1 unit less
  # this way, the timer will overflow on the next call to step
  t.counter = min(t.counter, t.period - unitSpeed)

proc step(t: var Timer): bool =
  t.counter += unitSpeed
  result = t.counter >= t.period
  if result:
    # timer overflow
    t.counter -= t.period

# === Operation ===============================================================

func toOperation(row: TrackRow): Operation =
  # note column
  result.note = row.queryNote()
  if result.note.isSome() and result.note.get() == noteCut:
    # noteCut behaves exactly the same as effect S00
    result.note = none[uint8]()
    result.duration = some(0u8)

  # instrument column
  result.instrument = row.queryInstrument()
  
  # effects
  for effect in row.effects:
    case effect.effectType:
    of etPatternGoto.uint8:
      result.patternCommand = pcJump
      result.patternCommandParam = effect.param
    of etPatternHalt.uint8:
      result.halt = true
    of etPatternSkip.uint8:
      result.patternCommand = pcNext
      result.patternCommandParam = effect.param
    of etSetTempo.uint8:
      if effect.param >= low(Speed) and effect.param <= high(Speed):
        result.speed = effect.param
    of etSfx.uint8:
      discard  # TBD
    of etSetEnvelope.uint8:
      result.envelope = some(effect.param)
    of etSetTimbre.uint8:
      result.timbre = some(clamp(effect.param, 0, 3))
    of etSetPanning.uint8:
      result.panning = some(clamp(effect.param, 0, 3))
    of etSetSweep.uint8:
      result.sweep = some(effect.param)
    of etDelayedCut.uint8:
      result.duration = some(effect.param)
    of etDelayedNote.uint8:
      result.delay = effect.param
    of etLock.uint8:
      discard  # TBD
    of etArpeggio.uint8:
      result.freqMod = freqArpeggio
      result.freqModParam = effect.param
    of etPitchUp.uint8:
      result.freqMod = freqPitchUp
      result.freqModParam = effect.param
    of etPitchDown.uint8:
      result.freqMod = freqPitchDown
      result.freqModParam = effect.param
    of etAutoPortamento.uint8:
      result.freqMod = freqPortamento
      result.freqModParam = effect.param
    of etVibrato.uint8:
      result.vibrato = some(effect.param)
    of etVibratoDelay.uint8:
      result.vibratoDelay = some(effect.param)
    of etTuning.uint8:
      result.tune = some(effect.param)
    of etNoteSlideUp.uint8:
      result.freqMod = freqNoteUp
      result.freqModParam = effect.param
    of etNoteSlideDown.uint8:
      result.freqMod = freqNoteDown
      result.freqModParam = effect.param
    of etSetGlobalVolume.uint8:
      if effect.param < 0x80:
        result.volume = some(effect.param and 0x77)
    else:
      discard  # ignore any unknown effect

# func toOperation(note: uint8): Operation =
#     if note == noteCut:
#         result.duration = some(1u8)
#     else:
#         result.note = some(note)

# === FrequencyControl ========================================================

func init(T: typedesc[FrequencyControl], bounds: FrequencyBounds): FrequencyControl =
  result.bounds = bounds

proc apply(fc: var FrequencyControl, op: Operation) =
  var updateChord = false
  if op.note.isSome():
    if fc.mode == fcmNoteSlide:
      # setting a new note cancels a slide
      fc.mode = fcmNone
    fc.note = min(op.note.get(), fc.bounds.maxNote)

  case op.freqMod:
  of freqArpeggio:
    if op.freqModParam == 0:
      if fc.mode == fcmArpeggio:
        fc.frequency = fc.chord[0]
        fc.chordIndex = 0
      fc.mode = fcmNone
    else:
      fc.mode = fcmArpeggio
      fc.chordOffset1 = op.freqModParam shr 4
      fc.chordOffset2 = op.freqModParam and 0xF
      updateChord = true
  of freqPitchUp, freqPitchDown:
    if op.freqModParam == 0:
      fc.mode = fcmNone
    else:
      fc.mode = fcmPitchSlide
      if op.freqMod == freqPitchUp:
        fc.slideTarget = fc.bounds.maxFrequency
      else:
        fc.slideTarget = 0
      fc.slideAmount = op.freqModParam
  of freqNoteUp, freqNoteDown:
    fc.slideAmount = 1 + (2 * (op.freqModParam and 0xF))
    # upper 4 bits is the # of semitones to slide to
    let semitones = op.freqModParam shr 4
    let targetNote = block:
      if op.freqMod == freqNoteUp:
        min(fc.note + semitones, fc.bounds.maxNote)
      else:
        if fc.note < semitones:
          0u8
        else:
          fc.note - semitones
    fc.mode = fcmNoteSlide
    fc.slideTarget = fc.bounds.lookupFn(targetNote)
    fc.note = targetNote
  of freqPortamento:
    if op.freqModParam == 0:
      fc.mode = fcmNone
    else:
      if fc.mode != fcmPortamento:
        fc.slideTarget = fc.frequency
        fc.mode = fcmPortamento
      fc.slideAmount = op.freqModParam
  else:
    discard

  if op.vibrato.isSome():
    fc.vibratoParam = op.vibrato.get()
    let extent = (fc.vibratoParam and 0xF).int8
    if extent == 0:
      # extent is 0, disable vibrato
      fc.vibratoEnabled = false
      fc.vibratoValue = 0
    else:
      # extent is nonzero, set vibrato
      fc.vibratoEnabled = true
      if fc.vibratoValue < 0:
        fc.vibratoValue = -extent
      else:
        fc.vibratoValue = extent

  if op.vibratoDelay.isSome():
    fc.vibratoDelay = op.vibratoDelay.get()

  if op.tune.isSome():
    # tune values have a bias of 0x80, so 0x80 is 0, is in tune
    # 0x81 is +1, frequency is pitch adjusted by 1
    # 0x7F is -1, frequency is pitch adjusted by -1
    fc.tune = (op.tune.get() - 0x80).int8

  if op.note.isSome():
    let freq = fc.bounds.lookupFn(op.note.get())
    if fc.mode == fcmPortamento:
      # automatic portamento, slide to this note
      fc.slideTarget = freq
    else:
      # otherwise, set the current frequency
      if fc.mode == fcmArpeggio:
        updateChord = true
      fc.frequency = freq

    if fc.vibratoEnabled:
      fc.vibratoDelayCounter = fc.vibratoDelay
      fc.vibratoCounter = 0
      fc.vibratoValue = (fc.vibratoParam and 0xF).int8
    fc.instrumentPitch = 0

  if updateChord:
    # first note in the chord is always the current note
    fc.chord[0] = fc.bounds.lookupFn(fc.note);
    # second note is the upper nibble + the current (clamped to the last possible note)
    fc.chord[1] = fc.bounds.lookupFn(min(fc.note + fc.chordOffset1, fc.bounds.maxNote));
    # third note is the lower nibble + current (also clamped)
    fc.chord[2] = fc.bounds.lookupFn(min(fc.note + fc.chordOffset2, fc.bounds.maxNote));

proc finishSlide(fc: var FrequencyControl) =
  fc.frequency = fc.slideTarget
  if fc.mode == fcmNoteSlide:
    # stop sliding once target note is reached
    fc.mode = fcmNone

proc step(fc: var FrequencyControl, arpIn, pitchIn: Option[uint8]): uint16 =
  if fc.vibratoEnabled:
    if fc.vibratoDelayCounter > 0:
      dec fc.vibratoDelayCounter
    else:
      if fc.vibratoCounter == 0:
        fc.vibratoValue = -fc.vibratoValue
        fc.vibratoCounter = fc.vibratoParam shr 4
      else:
        dec fc.vibratoCounter

  if pitchIn.isSome():
    fc.instrumentPitch += pitchIn.get().int8

  if arpIn.isSome():
    fc.frequency = fc.bounds.lookupFn(clamp(fc.note.int + arpIn.get().int, 0, fc.bounds.maxNote.int).uint8)
  else:
    # frequency modulation
    case fc.mode:
    of fcmPortamento, fcmPitchSlide, fcmNoteSlide:

      if fc.frequency != fc.slideTarget:
        if fc.frequency < fc.slideTarget:
          # sliding up
          fc.frequency += fc.slideAmount
          if fc.frequency > fc.slideTarget:
            fc.finishSlide()
        else:
          # sliding down
          fc.frequency -= fc.slideAmount
          if fc.frequency < fc.slideTarget:
            fc.finishSlide()
    of fcmArpeggio:
      fc.frequency = fc.chord[fc.chordIndex]
      inc fc.chordIndex
      if fc.chordIndex > high(fc.chord):
        fc.chordIndex = 0
    else:
      discard

  var calcfreq = fc.frequency.int + fc.tune.int + fc.instrumentPitch.int
  if fc.vibratoEnabled and fc.vibratoDelayCounter == 0:
    calcfreq += fc.vibratoValue.int
  result = clamp(calcfreq, 0, fc.bounds.maxFrequency.int).uint16

# === InstrumentRuntime =======================================================

proc reset(r: var InstrumentRuntime) =
  r.sequenceCounters = default(r.sequenceCounters.type)

proc setInstrument(r: var InstrumentRuntime, i: sink Immutable[ref Instrument]) =
  r.instrument = i
  r.reset()

proc step(r: var InstrumentRuntime): SequenceInput =
  proc next(s: Sequence, index: var int): Option[uint8] =
    let seqlen = s.data.len
    if index >= seqlen:
      if seqlen != 0 and s.loopIndex.isSome():
        # loop to the loop index
        index = s.loopIndex.get()
      else:
        # at end of sequence, return none
        return
    # get the value at the current index
    result = some(s.data[index])
    inc index

  if r.instrument != nil:
    for kind, sequence in r.instrument[].sequences.pairs:
      result[kind] = next(sequence, r.sequenceCounters[kind])

# === TrackControl ============================================================

func init(T: typedesc[TrackControl], ch: ChannelId): TrackControl =
  result = TrackControl(
    op: default(Operation),
    fc: FrequencyControl.init(if ch == ch4: noiseFrequencyBounds else: toneFrequencyBounds),
    envelope: if ch == ch3: 0 else: 0xF0,
    timbre: 3,
    panning: 3
  )

proc setRow(tc: var TrackControl, row: TrackRow) =
  if row.isEmpty():
    # empty row, do nothing
    return

  # convert the row to an operation
  tc.op = row.toOperation
  tc.delayCounter = counter(tc.op.delay.int)
  # note that the operation gets applied in step(), in case there was a Gxx
  # effect. If Gxx is not present or the parameter is 00, then the operation
  # is immediately applied on the next call to step()

proc step(tc: var TrackControl, itable: InstrumentTable, global: var GlobalState): NoteAction =
  result = naSustain

  if tc.delayCounter.step():
    # apply the operation

    # global effects
    if tc.op.patternCommand != pcNone:
      global.patternCommand = tc.op.patternCommand
      global.patternCommandParam = tc.op.patternCommandParam

    if tc.op.speed != 0:
      # update speed if Fxx was specified
      global.speed = tc.op.speed
    if tc.op.halt:
      global.halt = true
    global.volume = tc.op.volume

    # instrument column
    if tc.op.instrument.isSome():
      let instrument = itable[tc.op.instrument.get()]
      if instrument != nil:
        tc.ir.setInstrument(instrument)

    template updateSetting(setting: untyped): untyped =
      if tc.op.setting.isSome():
        tc.setting = tc.op.setting.get()

    updateSetting(envelope)
    updateSetting(panning)
    updateSetting(timbre)

    global.sweep = tc.op.sweep

    # note column
    if tc.op.note.isSome():
      tc.ir.reset()
      tc.playing = true
      if tc.ir.instrument != nil and tc.ir.instrument[].initEnvelope:
        tc.state.envelope = tc.ir.instrument[].envelope
      else:
        tc.state.envelope = tc.envelope
      result = naTrigger

    tc.fc.apply(tc.op)
    tc.delayCounter = noCounter()
    if tc.op.duration.isSome():
      tc.cutCounter = counter(tc.op.duration.get().int)
    else:
      tc.cutCounter = noCounter()
  
  if tc.playing:
    if tc.cutCounter.step():
      tc.playing = false
      return naCut
    
    let inputs = tc.ir.step()

    # Frequency calculation
    tc.state.frequency = tc.fc.step(inputs[skArp], inputs[skPitch])
    
    template readInput(dest: untyped, kind: SequenceKind): untyped =
      if inputs[kind].isSome():
        tc.state.dest = inputs[kind].get()
      else:
        tc.state.dest = tc.dest
      
    readInput(panning, skPanning)
    readInput(timbre, skTimbre)
  else:
    result = naOff

func init*(T: typedesc[MusicRuntime], song: sink Immutable[ref Song], orderNo, rowNo: int, patternRepeat: bool): MusicRuntime =
  result = MusicRuntime(
    song: song,
    halted: false,
    orderCounter: orderNo,
    rowCounter: rowNo,
    patternRepeat: patternRepeat,
    timer: Timer.init(song[].speed),
    global: GlobalState.init(),
    unlocked: {},
    states: [
      ChannelState.init,
      ChannelState.init,
      ChannelState.init,
      ChannelState.init
    ],
    trackControls: [
      TrackControl.init(ch1),
      TrackControl.init(ch2),
      TrackControl.init(ch3),
      TrackControl.init(ch4)
    ]
  )

proc haltAll(r: var MusicRuntime, op: var ApuOperation) =
  for ch in ChannelId:
    if ch notin r.unlocked:
      op.updates[ch] = ChannelUpdate(action: caShutdown)
      r.states[ch] = ChannelState.default

proc halt*(r: var MusicRuntime, op: var ApuOperation) =
  r.halted = true
  r.haltAll(op)

proc jump*(r: var MusicRuntime, pattern: Natural) =
  r.orderCounter = pattern
  r.rowCounter = 0

proc lock*(r: var MusicRuntime, chno: ChannelId, op: var ApuOperation) =
  if chno in r.unlocked:
    r.unlocked.excl(chno)
    op.updates[chno] = ChannelUpdate(
      action: caUpdate,
      flags: ufAll,
      state: r.states[chno]
    )

proc unlock*(r: var MusicRuntime, chno: ChannelId, op: var ApuOperation) =
  if chno notin r.unlocked:
    r.unlocked.incl(chno)
    op.updates[chno] = ChannelUpdate(action: caShutdown)

func difference(state, prev: ChannelState): UpdateFlags =
  template check(flag: UpdateFlag, param: untyped): untyped =
    if state.param != prev.param:
      result.incl(flag)
  check(ufEnvelope, envelope)
  check(ufTimbre, timbre)
  check(ufPanning, panning)
  check(ufFrequency, frequency)

proc step*(r: var MusicRuntime, itable: InstrumentTable, frame: var EngineFrame, op: var ApuOperation): bool =
  if r.halted:
    return true

  # we are starting a new row if the timer is active
  frame.startedNewRow = r.timer.active()
  # this gets set to true if:
  #  1. we have started a new row
  #  2. a pattern command was set (jump or next)
  frame.startedNewPattern = false
  if frame.startedNewRow:
    # change the current pattern if needed
    if r.global.patternCommand != pcNone and r.patternRepeat:
      r.global.patternCommand = pcNone
      r.rowCounter = 0
    else:
      case r.global.patternCommand:
      of pcNone:
        discard
      of pcNext:
        inc r.orderCounter
        if r.orderCounter >= r.song[].order.len:
          # loop back to the first pattern
          r.orderCounter = 0
        r.rowCounter = r.global.patternCommandParam.int
        r.global.patternCommand = pcNone
        frame.startedNewPattern = true
      of pcJump:
        r.rowCounter = 0
        # if the parameter goes past the last one, use the last one
        r.orderCounter = min(r.global.patternCommandParam.int, r.song[].order.len - 1)
        r.global.patternCommand = pcNone
        frame.startedNewPattern = true
    
    # set current track row to the track controls
    let order = r.song[].order[r.orderCounter]
    for chno in ChannelId:
      r.trackControls[chno].setRow(r.song[].getRow(chno, order[chno], r.rowCounter))
    
    if r.global.halt:
      r.halt(op)
      return true

    frame.row = r.rowCounter
    frame.order = r.orderCounter

  for chno in ChannelId:
  
    #var state = r.states[chno]
    #let prev = state
    
    # step the channel's track control
    let action = r.trackControls[chno].step(itable, r.global)

    if chno notin r.unlocked:
      op.updates[chno] = block:
        case action:
        of naOff:
          ChannelUpdate(action: caNone)
        of naTrigger, naSustain:
          let state = r.trackControls[chno].state
          let up = ChannelUpdate(
            action: caUpdate,
            flags: difference(state, r.states[chno]),
            state: state,
            trigger: action == naTrigger
          )
          r.states[chno] = state
          up
        of naCut:
          ChannelUpdate(action: caCut)


  if op.updates[ch1].action == caUpdate and r.global.sweep.isSome():
    op.updates[ch1].trigger = true
    op.sweep = r.global.sweep
  op.volume = r.global.volume
  r.global.sweep = none(uint8)
  r.global.volume = none(uint8)

  # change speed if the Fxx effect was used
  if r.global.speed > 0:
    r.timer.setPeriod(r.global.speed)
    r.global.speed = 0
  frame.speed = r.timer.period.Speed

  if r.timer.step():
    # timer overflow, advance row counter
    inc r.rowCounter
    if r.rowCounter >= r.song[].trackLen:
      # end of pattern
      if r.global.patternCommand == pcNone:
        # go to the next pattern in the order
        with r.global:
          patternCommand = pcNext
          patternCommandParam = 0
  result = false