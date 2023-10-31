##
## Intermediate Represention (ir) of pattern data to be compiled.
## 
## Using IR format allows us to easily convert between formats where the process
## for converting a given input to a given output follows:
##
##    <input> -> IR -> <output>
## 
## Where input is typically a TBM, or another module format like FTM or MPT, and
## output can be ASM, GBS, TBM, etc.
## 
## Example uses:
## 
## =======  =======  ====================================================
## Input    Output   Description
## =======  =======  ====================================================
## `*.ftm`  `*.tbm`  FamiTracker module converter
## `*.tbm`  `*.asm`  Pattern compiler, export module to Game Boy assembly
## `*.tbm`  `*.gbs`  GBS exporter
## =======  =======  ====================================================
## 
## Creating IR can be done by using the getIr procs, or created manually.
##

import
  ./data,
  ./notes

import std/[options]

type
  PatternCommand* = enum
    ## Enum for commands that change the current pattern.
    pcNone
      ## No pattern command, do not change pattern
    pcNext
      ## Skip to the next pattern in the order, starting at a given row.
    pcJump
      ## Jump to the given pattern in the order.

  PatternVisit* = object
    ## A visit to a pattern contains its pattern index and the number of
    ## rows encountered before reaching the end or a pattern command occurred.
    pattern*: int
      ## The index in the song's order of the pattern being visited
    rows*: int
      ## The number of rows that were visited.
    startRow*: int
      ## The starting row of the visit, 0 in most cases. When a visit's starting
      ## row is nonzero, this means that the Dxx effect (pattern skip) with a
      ## nonzero parameter was encountered in the previous pattern visit.

  SongPath* = object
    ## A path of patterns in the order that they will be played out for a song,
    ## with an optional loop index. If `loopIndex.isNone()` then the song will
    ## halt at the last pattern visited.
    visits*: seq[PatternVisit]
    loopIndex*: Option[int]

  FrequencyMod* = enum
    ## Enum for a frequency modulation effect. 
    freqPortamento
    freqPitchUp
    freqPitchDown
    freqNoteUp
    freqNoteDown
    freqArpeggio

  OperationFlag* = enum
    ## Enum of flags that specify what the operation does. Each flag is either
    ## a column of the TrackRow (note, instrument) or an effect instance.
    opsPatternCommand
      ## Effects Bxx, Dxx
    opsSpeed
      ## Effect Fxx
    opsVolume
      ## Effect Jxy
    opsNote
      ## Note column
    opsInstrument
      ## Instrument column
    opsDelay
      ## Effect Gxx
    opsDuration
      ## Effect Sxx or note cut (duration = 0)
    opsEnvelope
      ## Effect Exx
    opsTimbre
      ## Effect V0x
    opsPanning
      ## Effect I0x
    opsSweep
      ## Effect Hxx
    opsFreqMod
      ## Effects 0xy, 1xx, 2xx, 3xx, Qxy, Rxy
    opsVibrato
      ## Effect 4xy
    opsVibratoDelay
      ## Effect 5xx
    opsTune
      ## Effect Pxx

    # these don't have a uint8 setting
    opsHalt
      ## Effect C00
    opsShouldLock
      ## Effect L00

  OperationSetting* = range[opsPatternCommand..opsTune]
    ## Subrange of OperationFlag that have a uint8 setting. Flags in this
    ## range have an additional uint8 value to be processed, ie, an effect
    ## parameter or a note.

  Operation* = object
    ## An Operation is the processed form of a TrackRow, that can be performed
    ## by a playback engine, or exported to an output format.
    ## 
    ## You can convert a `TrackRow` to an `Operation` via the `toOperation`
    ## proc.
    ##   
    flags*: set[OperationFlag]
      ## The set of flags that are active on this operation.
    settings*: array[OperationSetting, uint8]
      ## Array of settings for each flag that has one. A setting value can be
      ## ignored if its flag is not set.
    patternCommand*: PatternCommand
      ## The pattern command to perform if flag `opsPatternCommand` is set. 
    freqMod*: FrequencyMod
      ## The type of frequency modulation to perform. This field should only
      ## be accessed when `opsFreqMod` is set.

  RowIrKind* = enum
    ## Enum for the two different kinds of RowIr, rests and operations.
    rikRest
      ## This kind of IR is a rest, or a duration of time where the track is
      ## not playing anything. This is represented by a group of empty rows
      ## in a Track.
    rikOp
      ## This kind of IR is an operation, or a non-empty row that performs
      ## some kind of action.

  RowIr* = object
    ## Row intermediate representation. A `RowIR` is an intermediate representation
    ## of a single non-empty `TrackRow` (operation), or 1 or more empty `TrackRows`
    ## (rest).
    case kind*: RowIrKind
    of rikRest:
      restDuration*: int
        ## The number of rows to rest for. Must be positive!
    of rikOp:
      op*: Operation
        ## The operation to perform

  TrackIr* = object
    ## Track intermediate representation. A `TrackIR` is an intermediate representation
    ## of a `Track`. It is simply a container of `RowIR` for each processed
    ## `TrackRow` in the `Track`.
    ## 
    ## TrackIr can be created manually, or via the `toIr` proc.
    ## 
    srcLen*: int
    data*: seq[RowIr]

{. push raises: [] .}

# === Operation ===============================================================

func toEffectType*(x: FrequencyMod): EffectType =
  ## Converts a FrequencyMod enum to an EffectType enum
  ## 
  case x
  of freqPortamento: etAutoPortamento
  of freqPitchUp: etPitchUp
  of freqPitchDown: etPitchDown
  of freqNoteUp: etNoteSlideUp
  of freqNoteDown: etNoteSlideDown
  of freqArpeggio: etArpeggio

func toEffectType*(x: PatternCommand): EffectType =
  ## Converts a PatternCommand enum to an EffectType enum
  ## 
  case x
  of pcNone: etNoEffect
  of pcJump: etPatternGoto
  of pcNext: etPatternSkip

proc setSetting(op: var Operation; flag: OperationFlag; val: uint8) =
  op.flags.incl(flag)
  op.settings[flag] = val

proc setPatternCommand(op: var Operation; cmd: range[pcNext..pcJump];
                       val: uint8) =
  op.setSetting(opsPatternCommand, val)
  op.patternCommand = cmd

proc setFrequencyMod(op: var Operation; fm: FrequencyMod; val: uint8) =
  op.setSetting(opsFreqMod, val)
  op.freqMod = fm

func toOperation*(row: TrackRow): Operation =
  ## Converts a TrackRow to an Operation. An Operation is a simplified version
  ## of a TrackRow, which removes any redundant effects. Some information in
  ## `row` may be lost when converting the operation back to a TrackRow.
  ##
  
  # note column
  let note = row.queryNote()
  if note.isSome():
    if note.get() == noteCut:
      # noteCut behaves exactly the same as effect S00
      result.setSetting(opsDuration, 0)
    else:
      result.setSetting(opsNote, note.get())

  # instrument column
  let inst = row.queryInstrument()
  if inst.isSome():
    result.setSetting(opsInstrument, inst.get())
  
  # effects
  for effect in row.effects:
    case effect.effectType.toEffectType():
    of etNoEffect:
      discard  # ignore any unknown effect
    of etPatternGoto:
      result.setPatternCommand(pcJump, effect.param)
    of etPatternHalt:
      result.flags.incl(opsHalt)
    of etPatternSkip:
      result.setPatternCommand(pcNext, effect.param)
    of etSetTempo:
      if effect.param >= low(Speed) and effect.param <= high(Speed):
        result.setSetting(opsSpeed, effect.param)
    of etSfx:
      discard  # TBD
    of etSetEnvelope:
      result.setSetting(opsEnvelope, effect.param)
    of etSetTimbre:
      result.setSetting(opsTimbre, clamp(effect.param, 0, 3))
    of etSetPanning:
      result.setSetting(opsPanning, clamp(effect.param, 0, 3))
    of etSetSweep:
      result.setSetting(opsSweep, effect.param)
    of etDelayedCut:
      result.setSetting(opsDuration, effect.param)
    of etDelayedNote:
      if effect.param > 0:  # G00, or a delay of 0 has no effect
        result.setSetting(opsDelay, effect.param)
    of etLock:
      result.flags.incl(opsShouldLock)
    of etArpeggio:
      result.setFrequencyMod(freqArpeggio, effect.param)
    of etPitchUp:
      result.setFrequencyMod(freqPitchUp, effect.param)
    of etPitchDown:
      result.setFrequencyMod(freqPitchDown, effect.param)
    of etAutoPortamento:
      result.setFrequencyMod(freqPortamento, effect.param)
    of etVibrato:
      result.setSetting(opsVibrato, effect.param)
    of etVibratoDelay:
      result.setSetting(opsVibratoDelay, effect.param)
    of etTuning:
      result.setSetting(opsTune, effect.param)
    of etNoteSlideUp:
      result.setFrequencyMod(freqNoteUp, effect.param)
    of etNoteSlideDown:
      result.setFrequencyMod(freqNoteDown, effect.param)
    of etSetGlobalVolume:
      if (effect.param and 0x88) == 0:
        result.setSetting(opsVolume, effect.param)

template contains*(op: Operation; flag: OperationFlag): bool =
  ## Shortcut for `flag in op.flags`
  flag in op.flags

template forflagPresent*(op: Operation; flag: OperationFlag; body: untyped
                        ): untyped =
  ## Template that executes body if `flag` is present in `op`
  if flag in op:
    body

template getSetting*(op: Operation; flag: OperationSetting): uint8 =
  ## Gets the `uint8` setting associated with the given `flag`. If `flag` is
  ## not present in `op`, `0` is returned.
  op.settings[flag]

template `[]`*(op: Operation; flag: OperationSetting): uint8 =
  ## Shortcut for `op.getSetting(flag)`
  op.getSetting(flag)

func isNoop*(op: Operation): bool =
  ## Determines if the operation has no effect, or is a no-op. Operations with
  ## this property can be safely excluded from the compilation process.
  result = op.flags.card == 0

func len*(ir: TrackIr): int =
  for rowIr in ir.data:
    case rowIr.kind
    of rikRest:
      result += rowIr.restDuration
    of rikOp:
      inc result

iterator ops*(ir: TrackIr): tuple[rowno: int; op: Operation] =
  ## Iterate all Operations for the given TrackIr. The row number the operation
  ## occurs, along with the operation is yielded per iteration.
  var i = 0
  for rowIr in ir.data:
    case rowIr.kind
    of rikRest:
      i += rowIr.restDuration
    of rikOp:
      yield (i, rowIr.op)
      inc i

func restRowIr(restRows: Positive): RowIr =
  ## Creates a RowIr that "rests" or does nothing for a given amount of rows.
  ## Equivalent to consecutive empty rows in a track.
  result = RowIr(kind: rikRest, restDuration: restRows)

func opRowIr(op: Operation): RowIr =
  ## Creates a RowIr that performs an Operation.
  result = RowIr(kind: rikOp, op: op)

func toIr*(t: TrackView): TrackIr =
  ## Gets the immediate representation, ir, of a given track.
  if t.isValid():
    result.srcLen = t.len
    var rest = 0
    for row in t:
      let op = row.toOperation()
      if op.isNoop():
        inc rest
      else:
        if rest > 0:
          result.data.add(restRowIr(rest))
          rest = 0
        result.data.add(opRowIr(op))

type
  EffectStack = object
    len: int
    data: array[3, tuple[et: EffectType, ep: uint8]]

proc push(e: var EffectStack; et: EffectType; ep = 0u8) =
  if e.len < e.data.len:
    e.data[e.len] = (et, ep)
    inc e.len

proc pushIfSet(e: var EffectStack; op: Operation; setting: OperationSetting;
               et: EffectType) =
  if setting in op:
    e.push(et, op[setting])

proc apply(e: EffectStack; track: var Track; rowNo: ByteIndex) =
  for i in 0..<e.len:
    track.setEffect(rowNo, i, e.data[i].et, e.data[i].ep)

proc setFromIr*(track: var Track; ir: TrackIr) =
  ## Sets the given track's row data using the given ir data. This proc does
  ## not clear the track beforehand for optimization purposes, ensure that
  ## `track` is an empty one first before calling this function.
  if not track.isValid:
    track = Track.init(ir.srcLen)
  else:
    track.len = ir.srcLen

  for rowNo, rowOp in ir.ops:
    var es: EffectStack
    
    # note
    if opsNote in rowOp:
      track.setNote(rowNo, rowOp[opsNote])
    elif opsDuration in rowOp:
      let duration = rowOp[opsDuration]
      if duration == 0:
        track.setNote(rowNo, noteCut)
      else:
        es.push(etDelayedCut, duration)
    
    # instrument
    if opsInstrument in rowOp:
      track.setInstrument(rowNo, rowOp[opsInstrument])
    
    # effects
    if opsPatternCommand in rowOp:
      es.push(rowOp.patternCommand.toEffectType(), rowOp[opsPatternCommand])
    
    for (setting, et) in [
      (opsSpeed, etSetTempo),
      (opsVolume, etSetGlobalVolume),
      (opsDelay, etDelayedNote),
      (opsEnvelope, etSetEnvelope),
      (opsTimbre, etSetTimbre),
      (opsPanning, etSetPanning),
      (opsSweep, etSetSweep),
      (opsVibrato, etVibrato),
      (opsVibratoDelay, etVibratoDelay),
      (opsTune, etTuning)
    ]:
      es.pushIfSet(rowOp, setting, et)

    if opsFreqMod in rowOp:
      es.push(rowOp.freqMod.toEffectType(), rowOp[opsFreqMod])

    if opsHalt in rowOp:
      es.push(etPatternHalt)
    if opsShouldLock in rowOp:
      es.push(etLock)

    es.apply(track, rowNo)

func fromIr*(ir: TrackIr): Track =
  ## Converts a TrackIr into a Track.
  result = Track.init(ir.srcLen)
  result.setFromIr(ir)

{. pop .}
