##[

Frequency effects and control.

This module handles all frequency effects and related procedures regarding
channel frequency.

This module is part of the inner workings of the engine module, and has an
**unstable API**.

]##

import
  std/[options],
  ../ir,
  ../notes

export
  options,
  ir

type
  NoteResolver* = object
    ## Resolves a note value to a frequency value
    ## - `isTone`: Determines if tone notes are expected
    ## - `maxFrequency`: Highest frequency value possible.
    ## - `maxNote`: Highest note value possible.
    ##
    kind: NoteType
    maxFrequency*: uint16
    maxNote*: uint8

  Vibrato* = object
    ## Square vibrato generator.
    ##
    ## Generates a frequency offset that can be added to an existing frequency
    ## to give it a vibrato effect. This effect oscillates periodically between
    ## a negative `extent` and a positive `extent` every `period` frames.
    ## 
    ## To use set the period and extent via [setParam], and
    ## optionally set the `delay`. Then to start generation, call [trigger]
    ## and then call [tick] to get the current offset.
    ##
    delay*: uint8    # 0-255, number of frames before vibrato starts
    period: uint8   # 0-15, number of frames until value flips
    extent: int8    # 1-15, value or strength of the vibrato
    enabled: bool
    delayCounter: uint8
    periodCounter: uint8
    value: int8

  Arpeggio* = object
    ## Arpeggio modulator.
    ## 
    ## Similates a chord by alternating between three notes each tick. Enable
    ## by calling [setParam] with a nonzero parameter, then
    ## set the chord buffer via [setChord]. The modulator can be stepped by
    ## calling [tick], which returns the frequency for that tick.
    ##
    note1: uint8 # 0-F, offset from base note for the 2nd note in the chord
    note2: uint8 # 0-F, offset from base note for the 3rd note in the chord
    pos: uint8 # current position in the chord buffer
    chord: array[0u8..2u8, uint16] # frequencies of each note in the chord

  Slide* = object
    ## Frequency slide modulator.
    ##
    ## Modulates a frequency by sliding `amount` units towards the `target`
    ## frequency. To use set the desired amount and target, then call
    ## [tick] which will modify the given frequency.
    ##
    amount: uint8
    target: uint16

  ModulatorMode = enum
    off
    arpeggio
    pitchSlide
    noteSlide
    portamento

  Modulator = object
    case mode: ModulatorMode
    of off:
      discard
    of arpeggio:
      arpeggio: Arpeggio
    of pitchSlide, noteSlide, portamento:
      slide: Slide

  FrequencyControl* = object
    ## Handles frequency calculation for a channel. For each tick, call [tick]
    ## on this control to get the frequency. If the channel has an operation,
    ## set it first via [setOperation].
    ##
    resolver: NoteResolver
    note: uint8
    tune: int8
    frequency: uint16
    instrumentPitch: int16
    modulator: Modulator
    vibrato: Vibrato

const
  toneResolver* = NoteResolver(
    kind: tone,
    maxFrequency: 2047,
    maxNote: uint8(high(ToneNote))
  )
    ## Default resolver for tone notes.
    ##
  noiseResolver* = NoteResolver(
    kind: noise,
    maxFrequency: uint16(high(NoiseNote)),
    maxNote: uint8(high(NoiseNote))
  )
    ## Default resolver for noise notes.
    ##


static: assert cast[int8](255u8) == -1
template asInt8(i: uint8): int8 =
  cast[int8](i)

func getFreq*(r: NoteResolver; note: uint8): uint16 =
  ## Resolves a note to its frequency value.
  ##
  if r.kind == tone:
    result = lookupToneNote(note)
  else:
    result = note

func clampFreq*(r: NoteResolver; freq: int): uint16 =
  ## Clamps the frequency value to the bounds of this resolver.
  ##
  result = uint16(clamp(freq, 0, int(r.maxFrequency)))

func clampNote*(r: NoteResolver; note: int): uint8 =
  ## Clamps the note value to the bounds of this resolver.
  ##
  result = uint8(clamp(note, 0, int(r.maxNote)))

func tuneValue*(param: uint8): int8 =
  ## Calculate a tuning offset from the given effect parameter. The parameter
  ## has a bias of `0x80` so this function removes that bias in the return
  ## value.
  ## - `0x80` is `0`, resulting frequency is kept as is.
  ## - `0x81` is `1`, resulting frequency is added by 1 unit.
  ## - `0x7F` is `-1`, resulting frequency is subtracted by 1 unit.
  ##
  result = int8(param.int - 0x80)

# === FrequencyControl ========================================================

# Vibrato

proc setParam*(v: var Vibrato; effectParam: uint8) =
  ## Set the parameters of the vibrato. The upper nibble of the parameter
  ## is the period, or the number of ticks per oscillation. The lower nibble
  ## is the extent, or magnitude of the offset amount. An extent of 0 will
  ## disable the vibrato.
  ##
  v.extent = int8(effectParam and 0xF)
  if v.extent == 0:
    # disable vibrato
    v.enabled = false
    v.value = 0
    v.period = 0
  else:
    # enable vibrato
    v.enabled = true
    v.period = effectParam shr 4
    # keep the sign of the current value
    if v.value < 0:
      v.value = -v.extent
    else:
      v.value = v.extent

proc trigger*(v: var Vibrato) =
  ## Triggers or restarts the vibrato generator for a new note starting.
  ##
  if v.enabled:
    v.delayCounter = v.delay
    v.periodCounter = v.period
    v.value = -v.extent

proc tick*(v: var Vibrato): int =
  ## Calculates the next offset value for the current tick. `0` is returned if
  ## the vibrato is disabled.
  ##
  if v.enabled:
    if v.delayCounter > 0:
      dec v.delayCounter
    else:
      if v.periodCounter == 0:
        v.value = -v.value
        v.periodCounter = v.period
        result = v.value
      else:
        dec v.periodCounter

# Arpeggio

proc setParam*(a: var Arpeggio; effectParam: uint8) =
  ## Set the parameters of the arpeggio. The upper nibble of the parameter
  ## contains the semitone offset from the base note for the second note in the
  ## chord. The lower nibble contains the offset for the third note. If both
  ## offsets are 0 (`effectParam` = 0), then the arpeggio is disabled.
  ##
  if effectParam == 0:
    a.pos = 0
  else:
    a.note1 = effectParam shr 4
    a.note2 = effectParam and 0xF

proc setChord*(a: var Arpeggio; resolver: NoteResolver; baseNote: uint8) =
  ## Sets the chord buffer for the arpeggio for the given base note.
  ##
  a.chord[0] = resolver.getFreq(baseNote)
  a.chord[1] = resolver.getFreq(baseNote + a.note1)
  a.chord[2] = resolver.getFreq(baseNote + a.note2)

proc tick*(a: var Arpeggio): uint16 =
  ## Ticks the arpeggio 1 frame, the next frequency in the chord is returned.
  ##
  result = a.chord[a.pos]
  inc a.pos
  if a.pos > high(a.chord):
    a.pos = low(a.chord)

# Slide

proc tick*(s: Slide; freq: var uint16): bool =
  ## Ticks the slide 1 frame, by moving `freq` towards the slide's target.
  ## `freq` is left unchanged if it is already at the target.
  ## 
  ## `true` is returned if `freq` is at the target.
  ##
  result = freq == s.target
  if not result:
    if freq > s.target:
      # sliding down
      if freq > s.amount:
        freq -= s.amount
      else:
        freq = s.target
        result = true
    else:
      # sliding up
      freq += s.amount
      if freq >= s.target:
        freq = s.target
        result = true

proc setMode(m: var Modulator; mode: ModulatorMode) =
  if m.mode != mode:
    m = Modulator(mode: mode)

func initFrequencyControl*(resolver: NoteResolver): FrequencyControl =
  ## Creates a [FrequencyControl] with the given resolver.
  ##
  result.resolver = resolver

func initToneFrequencyControl*(): FrequencyControl =
  ## Creates a [FrequencyControl] with the default tone resolver,
  ## [toneResolver].
  ##
  result = initFrequencyControl(toneResolver)

func initNoiseFrequencyControl*(): FrequencyControl =
  ## Creates a [FrequencyControl] with the default noise resolver,
  ## [noiseResolver].
  ##
  result = initFrequencyControl(noiseResolver)

proc setOperation*(fc: var FrequencyControl; op: Operation) {.raises: [].} =
  ## Sets an operation on this control, which will update the current note, 
  ## frequency modulator, vibrato and others as needed.
  ## 
  ## Call this before `tick` for changes to effect that tick.
  ##
  let noteTriggered = opsNote in op
  var setArpChord = false

  if noteTriggered:
    if fc.modulator.mode == noteSlide:
      fc.modulator.setMode(off)
    fc.note = min(op[opsNote], fc.resolver.maxNote)

  # freq mod
  if opsFreqMod in op:
    let param = op[opsFreqMod]
    case op.freqMod:
    of freqArpeggio:
      if param == 0:
        if fc.modulator.mode == arpeggio:
          # NOTE: when disabling arpeggio, the frequency should return to the base note
          fc.frequency = fc.modulator.arpeggio.chord[0]
        fc.modulator.setMode(off)
      else:
        fc.modulator.setMode(arpeggio)
        fc.modulator.arpeggio.setParam(param)
        setArpChord = true
    of freqPitchUp, freqPitchDown:
      if param == 0:
        fc.modulator.setMode(off)
      else:
        fc.modulator.setMode(pitchSlide)
        fc.modulator.slide.amount = param
        if op.freqMod == freqPitchUp:
          # slide up to the highest
          fc.modulator.slide.target = fc.resolver.maxFrequency
        else:
          # slide down to the lowest
          fc.modulator.slide.target = 0
    of freqNoteUp, freqNoteDown:
      fc.modulator.setMode(noteSlide)
      fc.modulator.slide.amount = 1 + (2 * (param and 0xF))
      let 
        semitones = int(param shr 4)
        targetNote = block:
          if op.freqMod == freqNoteUp:
            uint8(min(int(fc.note) + semitones, int(fc.resolver.maxNote)))
          else:
            uint8(max(int(fc.note) - semitones, 0))
      fc.modulator.slide.target = fc.resolver.getFreq(targetNote)
      fc.note = targetNote
    of freqPortamento:
      if param == 0:
        fc.modulator.setMode(off)
      else:
        if fc.modulator.mode != portamento:
          fc.modulator.setMode(portamento)
          fc.modulator.slide.target = fc.frequency
        fc.modulator.slide.amount = param         

  if opsVibrato in op:
    fc.vibrato.setParam(op[opsVibrato])

  if opsVibratoDelay in op:
    fc.vibrato.delay = op[opsVibratoDelay]
  
  if opsTune in op:
    fc.tune = tuneValue(op[opsTune])
  
  if noteTriggered:
    if fc.modulator.mode == arpeggio:
      setArpChord = true
    else:
      let freq = fc.resolver.getFreq(fc.note)
      if fc.modulator.mode == portamento:
        fc.modulator.slide.target = freq
      else:
        fc.frequency = freq
    fc.vibrato.trigger()
    fc.instrumentPitch = 0

  if setArpChord:
    fc.modulator.arpeggio.setChord(fc.resolver, fc.note)

proc tick*(fc: var FrequencyControl; arpIn, pitchIn: Option[uint8];): uint16 =
  ## Step the control for 1 tick, with the given arpeggio and pitch sequence
  ## inputs. The calculated frequency for this tick is returned.
  ## 
  ## `arpIn` and `pitchIn` should be the current values of an instrument's
  ## arpeggio and pitch sequences, if present. The control's modulator will be
  ## ignored if `arpIn` is provided, as that frequency will be used instead.
  ##
  let vibrato = fc.vibrato.tick()

  if pitchIn.isSome():
    fc.instrumentPitch += asInt8(pitchIn.get())
  if arpIn.isSome():
    let noteRelative = int(fc.note) + asInt8(arpIn.get())
    fc.frequency = fc.resolver.getFreq(fc.resolver.clampNote(noteRelative))
  else:
    # tick the modulator
    case fc.modulator.mode:
    of off: discard
    of arpeggio:
      fc.frequency = fc.modulator.arpeggio.tick()
    of pitchSlide, noteSlide, portamento:
      if fc.modulator.slide.tick(fc.frequency) and fc.modulator.mode == noteSlide:
        fc.modulator.setMode(off)
  let freq = fc.frequency.int + fc.tune + fc.instrumentPitch + vibrato
  result = fc.resolver.clampFreq(freq)

func note*(fc: FrequencyControl): uint8 {.inline.} =
  ## Gets the current note of the control.
  ##
  result = fc.note

func tune*(fc: FrequencyControl): int8 {.inline.} =
  ## Gets the current tune offset of the control.
  ##
  result = fc.tune

func frequency*(fc: FrequencyControl): uint16 {.inline.} =
  ## Gets the current frequency of the control. Note that this is not always
  ## the return value of the last call to `tick`.
  ##
  result = fc.frequency
