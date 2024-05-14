##
## Intermediate Represention (ir) of pattern data to be compiled.
## 
## Using IR format allows us to easily convert between formats where the
## process for converting a given input to a given output follows:
##
## ```
## <input> -> IR -> <output>
## ```
## 
## Where input is typically a TBM, or another module format like FTM or MPT,
## and output can be ASM, GBS, TBM, etc.
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
    ##
    pcNone
      ## No pattern command, do not change pattern
      ##
    pcNext
      ## Skip to the next pattern in the order, starting at a given row.
      ##
    pcJump
      ## Jump to the given pattern in the order.
      ##

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
    ## Row intermediate representation. A `RowIr` is an intermediate representation
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
    ## Track intermediate representation. A `TrackIr` is an intermediate representation
    ## of a `Track`. It is simply a container of `RowIr` for each processed
    ## `TrackRow` in the `Track`.
    ## 
    ## TrackIr can be created manually, or via the `toIr` proc.
    ## 
    srcLen*: int
    data*: seq[RowIr]

{. push raises: [] .}

# === Operation ===============================================================

func toEffectCmd*(x: FrequencyMod): EffectCmd =
  ## Converts a FrequencyMod enum to an EffectType enum
  ## 
  case x
  of freqPortamento: ecAutoPortamento
  of freqPitchUp: ecPitchUp
  of freqPitchDown: ecPitchDown
  of freqNoteUp: ecNoteSlideUp
  of freqNoteDown: ecNoteSlideDown
  of freqArpeggio: ecArpeggio

func toEffectCmd*(x: PatternCommand): EffectCmd =
  ## Converts a PatternCommand enum to an EffectType enum
  ## 
  case x
  of pcNone: ecNoEffect
  of pcJump: ecPatternGoto
  of pcNext: ecPatternSkip

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
  if row.note.has():
    let note = row.note.value()
    if note == noteCut:
      # noteCut behaves exactly the same as effect S00
      result.setSetting(opsDuration, 0)
    else:
      result.setSetting(opsNote, note)

  # instrument column
  if row.instrument.has():
    result.setSetting(opsInstrument, row.instrument.value())
  
  # effects
  for effect in row.effects:
    case effect.cmd.toEffectCmd():
    of ecNoEffect:
      discard  # ignore any unknown effect
    of ecPatternGoto:
      result.setPatternCommand(pcJump, effect.param)
    of ecPatternHalt:
      result.flags.incl(opsHalt)
    of ecPatternSkip:
      result.setPatternCommand(pcNext, effect.param)
    of ecSetTempo:
      if isValid(Speed(effect.param)):
        result.setSetting(opsSpeed, effect.param)
    of ecSfx:
      discard  # TBD
    of ecSetEnvelope:
      result.setSetting(opsEnvelope, effect.param)
    of ecSetTimbre:
      result.setSetting(opsTimbre, clamp(effect.param, 0, 3))
    of ecSetPanning:
      result.setSetting(opsPanning, clamp(effect.param, 0, 3))
    of ecSetSweep:
      result.setSetting(opsSweep, effect.param)
    of ecDelayedCut:
      result.setSetting(opsDuration, effect.param)
    of ecDelayedNote:
      if effect.param > 0:  # G00, or a delay of 0 has no effect
        result.setSetting(opsDelay, effect.param)
    of ecLock:
      result.flags.incl(opsShouldLock)
    of ecArpeggio:
      result.setFrequencyMod(freqArpeggio, effect.param)
    of ecPitchUp:
      result.setFrequencyMod(freqPitchUp, effect.param)
    of ecPitchDown:
      result.setFrequencyMod(freqPitchDown, effect.param)
    of ecAutoPortamento:
      result.setFrequencyMod(freqPortamento, effect.param)
    of ecVibrato:
      result.setSetting(opsVibrato, effect.param)
    of ecVibratoDelay:
      result.setSetting(opsVibratoDelay, effect.param)
    of ecTuning:
      result.setSetting(opsTune, effect.param)
    of ecNoteSlideUp:
      result.setFrequencyMod(freqNoteUp, effect.param)
    of ecNoteSlideDown:
      result.setFrequencyMod(freqNoteDown, effect.param)
    of ecSetGlobalVolume:
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

func runtime*(op: Operation): int =
  ## Gets the runtime, in frames, of the operation, assuming it can be
  ## determined. A runtime can be determined from an operation alone if its
  ## duration setting was set (note cut or delayed note cut effect). The
  ## determined runtime is returned, or -1 if it cannot be determined which
  ## means the operation can run indefinitely.
  ##
  if opsDuration in op.flags:
    result = op.settings[opsDelay].int + op.settings[opsDuration].int
  else:
    result = -1

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

func restRowIr*(restRows: Positive): RowIr =
  ## Creates a RowIr that "rests" or does nothing for a given amount of rows.
  ## Equivalent to consecutive empty rows in a track.
  result = RowIr(kind: rikRest, restDuration: restRows)

func opRowIr*(op: Operation): RowIr =
  ## Creates a RowIr that performs an Operation.
  result = RowIr(kind: rikOp, op: op)

func `==`*(a, b: RowIr;): bool =
  if a.kind == b.kind:
    case a.kind
    of rikRest:
      result = a.restDuration == b.restDuration
    of rikOp:
      result = a.op == b.op

func toIr*(t: TrackView; rows: Slice[ByteIndex]): TrackIr =
  ## Gets immediate representation, ir, of a given track, for only the given
  ## range of rows.
  ##
  proc addRest(restCount: var int; ir: var TrackIr) =
    if restCount > 0:
      ir.data.add(restRowIr(restCount))
      restCount = 0

  if t.isValid():
    result.srcLen = t.len
    var rest = 0
    for i in rows:
      let op = t[i].toOperation()
      if op.isNoop():
        inc rest
      else:
        addRest(rest, result)
        result.data.add(opRowIr(op))
    addRest(rest, result)

func toIr*(t: TrackView): TrackIr =
  ## Gets the immediate representation, ir, of a given track.
  ##
  result = toIr(t, ByteIndex(0)..ByteIndex(t.len-1))

func toTrackRow*(op: Operation): tuple[row: TrackRow; effectsOverflowed: bool] =
  ## Converts an Operation back into a TrackRow. The converted row is set in
  ## the `row` field. If the operation had too many effects set that could be
  ## contained in `row` the `effectsOverflowed` is set to `true`, and the
  ## conversion done was a partial one.
  ##
  proc addEffect(row: var TrackRow; index: var int; ec: EffectCmd; ep = 0u8) =
    if index <= row.effects.high:
      row.effects[index] = initEffect(ec, ep)
    inc index

  var effectCounter = 0

  # note
  if opsNote in op:
    result.row.note = noteColumn(op[opsNote])
  elif opsDuration in op:
    let duration = op[opsDuration]
    if duration == 0:
      result.row.note = noteColumn(noteCut)
    else:
      addEffect(result.row, effectCounter, ecDelayedCut, duration)
  
  # instrument
  if opsInstrument in op:
    result.row.instrument = instrumentColumn(op[opsInstrument])

  # effects
  if opsPatternCommand in op:
    addEffect(result.row, effectCounter, op.patternCommand.toEffectCmd(),
              op[opsPatternCommand])
  
  for (setting, cmd) in [
      (opsSpeed, ecSetTempo),
      (opsVolume, ecSetGlobalVolume),
      (opsDelay, ecDelayedNote),
      (opsEnvelope, ecSetEnvelope),
      (opsTimbre, ecSetTimbre),
      (opsPanning, ecSetPanning),
      (opsSweep, ecSetSweep),
      (opsVibrato, ecVibrato),
      (opsVibratoDelay, ecVibratoDelay),
      (opsTune, ecTuning)
    ]:
      if setting in op:
        addEffect(result.row, effectCounter, cmd, op[setting])
  if opsFreqMod in op:
    addEffect(result.row, effectCounter, op.freqMod.toEffectCmd(), op[opsFreqMod])
  
  if opsHalt in op:
    addEffect(result.row, effectCounter, ecPatternHalt)
  if opsShouldLock in op:
    addEffect(result.row, effectCounter, ecLock)
  
  result.effectsOverflowed = effectCounter > result.row.effects.high

proc setFromIr*(track: var Track; ir: TrackIr): bool =
  ## Sets the given track's row data using the given ir data. This proc does
  ## not clear the track beforehand for optimization purposes, ensure that
  ## `track` is an empty one first before calling this function.
  if track.len != ir.srcLen:
    track = initTrack(ir.srcLen)

  for rowNo, rowOp in ir.ops:
    let conv = toTrackRow(rowOp)
    track[rowNo] = conv.row
    if conv.effectsOverflowed:
      result = true

func fromIr*(ir: TrackIr): tuple[track: Track; effectsOverflowed: bool] =
  ## Converts a TrackIr into a Track.
  ##
  result.effectsOverflowed = setFromIr(result.track, ir)

{. pop .}
