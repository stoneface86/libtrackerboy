##[

.. include:: warning.rst

]##

import enginestate
import ../data, ../notes, ../ir

import std/[bitops, options, with]

type
  Counter = distinct int

  FcMode* = enum
    fcmNone,
    fcmPortamento,
    fcmPitchSlide,
    fcmNoteSlide,
    fcmArpeggio

  SequenceInput* = array[SequenceKind, Option[uint8]]
    ## Input data to pass to TrackControl and FrequencyControl from
    ## enumerated sequences

  InstrumentRuntime* = object
    ## Enumerates all sequences in an instrument
    instrument*: Immutable[ref Instrument]
    sequenceCounters*: array[SequenceKind, int]

  FrequencyLookupFunc* = proc(note: Natural): uint16 {.nimcall, gcSafe, raises: [], noSideEffect.}

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

# === FrequencyControl ========================================================

func init(T: typedesc[FrequencyControl], bounds: FrequencyBounds): FrequencyControl =
  result.bounds = bounds

proc apply(fc: var FrequencyControl, op: Operation) {.raises: [].} =
  var updateChord = false
  op.forFlagPresent(opsNote):
    if fc.mode == fcmNoteSlide:
      # setting a new note cancels a slide
      fc.mode = fcmNone
    fc.note = min(op[opsNote], fc.bounds.maxNote)

  op.forFlagPresent(opsFreqMod):
    let param = op[opsFreqMod]
    case op.freqMod:
    of freqArpeggio:
      if param == 0:
        if fc.mode == fcmArpeggio:
          fc.frequency = fc.chord[0]
          fc.chordIndex = 0
        fc.mode = fcmNone
      else:
        fc.mode = fcmArpeggio
        fc.chordOffset1 = param shr 4
        fc.chordOffset2 = param and 0xF
        updateChord = true
    of freqPitchUp, freqPitchDown:
      if param == 0:
        fc.mode = fcmNone
      else:
        fc.mode = fcmPitchSlide
        if op.freqMod == freqPitchUp:
          fc.slideTarget = fc.bounds.maxFrequency
        else:
          fc.slideTarget = 0
        fc.slideAmount = param
    of freqNoteUp, freqNoteDown:
      fc.slideAmount = 1 + (2 * (param and 0xF))
      # upper 4 bits is the # of semitones to slide to
      let semitones = param shr 4
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
      if param == 0:
        fc.mode = fcmNone
      else:
        if fc.mode != fcmPortamento:
          fc.slideTarget = fc.frequency
          fc.mode = fcmPortamento
        fc.slideAmount = param

  op.forFlagPresent(opsVibrato):
    fc.vibratoParam = op[opsVibrato]
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

  op.forFlagPresent(opsVibratoDelay):
    fc.vibratoDelay = op[opsVibratoDelay]

  op.forFlagPresent(opsTune):
    # tune values have a bias of 0x80, so 0x80 is 0, is in tune
    # 0x81 is +1, frequency is pitch adjusted by 1
    # 0x7F is -1, frequency is pitch adjusted by -1
    fc.tune = (op[opsTune] - 0x80).int8

  op.forFlagPresent(opsNote):
    let freq = fc.bounds.lookupFn(op[opsNote])
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
    # a simple cast should always work since 2s complement is a safe assumption
    # might need to refactor with a proc that guarantees this
    fc.instrumentPitch += cast[int8](pitchIn.get())

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
  tc.op = row.toOperation()
  tc.delayCounter = counter(tc.op[opsDelay].int)
  # note that the operation gets applied in step(), in case there was a Gxx
  # effect. If Gxx is not present or the parameter is 00, then the operation
  # is immediately applied on the next call to step()

proc step(tc: var TrackControl, itable: InstrumentTable, global: var GlobalState): (NoteAction, bool) {.raises: [].} =
  result[0] = naSustain

  if tc.delayCounter.step():
    # apply the operation

    result[1] = opsShouldLock in tc.op

    # global effects
    tc.op.forFlagPresent(opsPatternCommand):
      global.patternCommand = tc.op.patternCommand
      global.patternCommandParam = tc.op[opsPatternCommand]

    tc.op.forFlagPresent(opsSpeed):
      # update speed if Fxx was specified
      global.speed = tc.op[opsSpeed]
    if opsHalt in tc.op:
      global.halt = true
    tc.op.forFlagPresent(opsVolume):
      global.volume = some(tc.op[opsVolume])

    # instrument column
    tc.op.forFlagPresent(opsInstrument):
      let instrument = itable[tc.op[opsInstrument]]
      if instrument != nil:
        tc.ir.setInstrument(instrument)

    template updateSetting(setting: OperationSetting, field: untyped): untyped =
      tc.op.forFlagPresent(setting):
        let val = tc.op[setting]
        tc.field = val
        tc.state.field = val

    updateSetting(opsEnvelope, envelope)
    updateSetting(opsPanning, panning)
    updateSetting(opsTimbre, timbre)

    tc.op.forFlagPresent(opsSweep):
      global.sweep = some(tc.op[opsSweep])

    # note column
    if opsNote in tc.op:
      tc.ir.reset()
      tc.playing = true
      result[0] = naTrigger
      tc.state.envelope = tc.envelope
      tc.state.panning = tc.panning
      tc.state.timbre = tc.timbre

    tc.fc.apply(tc.op)
    tc.delayCounter = noCounter()
    tc.cutCounter = (
      if opsDuration in tc.op:
        counter(tc.op[opsDuration].int)
      else:
        noCounter()
    )
  
  if tc.playing:
    if tc.cutCounter.step():
      tc.playing = false
      result[0] = naCut
      return
    
    let inputs = tc.ir.step()

    # Frequency calculation
    tc.state.frequency = tc.fc.step(inputs[skArp], inputs[skPitch])

    template readInput(dest: untyped, validRange: static[Slice[uint8]], kind: SequenceKind): untyped =
      block:
        let input = inputs[kind]
        if input.isSome():
          template clampInput(): uint8 =
            when validRange == 0u8..255u8:
              input.unsafeGet()
            else:
              clamp(input.unsafeGet, validRange.a, validRange.b)
          tc.state.dest = clampInput()

    readInput(panning, 0u8..3u8, skPanning)
    readInput(timbre, 0u8..3u8, skTimbre)
    readInput(envelope, 0u8..255u8, skEnvelope)
  else:
    result[0] = naOff

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

proc step*(r: var MusicRuntime, itable: InstrumentTable, frame: var EngineFrame, op: var ApuOperation): bool {.raises: [].} =
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
    let (action, shouldLock) = r.trackControls[chno].step(itable, r.global)

    if chno notin r.unlocked or shouldLock:
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
      if shouldLock:
        r.unlocked.excl(chno)


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