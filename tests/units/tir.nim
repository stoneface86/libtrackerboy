
import libtrackerboy/[data, ir, notes]

import unittest2

import std/sequtils

when NimMajor >= 2:
  {.warning[ImplicitDefaultValue]:off.}

template rowOp(note = noteNone; instrument = instrumentNone;
               e1 = effectNone; e2 = effectNone; e3 = effectNone): Operation =
  toOperation(TrackRow.init(note, instrument, e1, e2, e3))

const
  CUT = noteColumn(noteCut)
  G00 = Effect.init(etDelayedNote)
  S00 = Effect.init(etDelayedCut)
  S03 = Effect.init(etDelayedCut, 3)

suite "ir.Operation":

  test "empty row is noop":
    let op = toOperation(default(TrackRow))
    check op.isNoop()

  test "unknown effect is noop":
    let
      row = TrackRow.init(e1 = Effect(effectType: EffectType.high.uint8 + 1))
      op = toOperation(row)
    check op.isNoop()

  test "G00 is noop":
    let op = toOperation(TrackRow.init(e1 = G00))
    check op.isNoop()

  test "invalid speed is noop":
    let 
      op1 = rowOp(e1 = Effect.init(etSetTempo, 0x0F))
      op2 = rowOp(e2 = Effect.init(etSetTempo, 0xF2))
    check:
      op1.isNoop()
      op2.isNoop()

  test "frequency effect conflict":
    let
      op = rowOp(e1 = Effect.init(etArpeggio),
                 e2 = Effect.init(etPitchUp),
                 e3 = Effect.init(etAutoPortamento))
    # all effect columns conflict with each other, the last effect is always
    # used.
    check:
      op.flags == { opsFreqMod }
      op.freqMod == freqPortamento
  
  test "pattern command conflict":
    let
      op = rowOp(e1 = Effect.init(etPatternSkip),
                 e2 = Effect.init(etPatternGoto),
                 e3 = Effect.init(etPatternHalt))
    check:
      op.flags == { opsHalt, opsPatternCommand }
      op.patternCommand == pcJump
  
  test "note cut equivalency":
    # case 1: note cut
    # case 2: Delayed cut at 0 frames
    # case 3: note cut with note delay of 0 frames
    
    #[
    Cuts at frame 0:

    CUT .. ... ... op1
    ... .. ... S00 op2
    CUT .. G00 ... op3
    ... .. G00 S00 op4
    CUT .. G00 S00 op5

    Cuts at frame XX (NNN = any note value):

    CUT .. GXX ... op6
    NNN .. ... SXX op7
    NNN .. G00 SXX op8

    Cuts at frame XX + YY:

    NNN .. GXX SYY op9
    
    SXX has priority over note cuts! A row with a note cut and SXX effect will
    always cut at XX frames!

    ]#

    # for test case 2, use XX = 3 and NNN = noteCut
    # for test case 3, use XX = 4, YY = 2, and NNN = noteCut

    

    let
      # case 1 (runtime of 0 == immediate cut)
      op1 = rowOp(note = CUT)
      op2 = rowOp(e1 = S00)
      op3 = rowOp(note = CUT, e1 = G00)
      op4 = rowOp(e1 = G00, e2 = S00)
      op5 = rowOp(note = CUT, e1 = G00, e2 = S00)
      # case 2 (runtime of 3: cuts in 3 frames)
      op6 = rowOp(note = CUT, e1 = Effect.init(etDelayedNote, 3))
      op7 = rowOp(note = CUT, e2 = S03)
      op8 = rowOp(note = CUT, e1 = G00, e2 = S03)
      # case 3 (runtime of 6: delays note by 4, then delayed cut in 2 frames)
      op9 = rowOp(note = CUT, e1 = Effect.init(etDelayedNote, 4),
                              e2 = Effect.init(etDelayedCut, 2))

    check:
      runtime(op1) == 0
      runtime(op2) == 0
      runtime(op3) == 0
      runtime(op4) == 0
      runtime(op5) == 0
      runtime(op6) == 3
      runtime(op7) == 3
      runtime(op8) == 3
      runtime(op9) == 6

suite "ir.TrackIr":
  const testLen = 8

  func countKinds(ir: TrackIr): tuple[rests, ops: int;] =
    for i in ir.data:
      case i.kind
      of rikRest: inc result.rests
      of rikOp: inc result.ops

  test "empty track":
    let 
      track = Track.init(testLen)
      ir = toIr(track)
    check:
      ir.srcLen == testLen
      ir.data == [ restRowIr(testLen) ]
      toSeq(ir.ops).len == 0

  test "2 ops":
    var track = Track.init(testLen)
    # ... .. ...
    # C-3 00 V02
    # ... .. ...
    # --- .. ...
    # ... .. ...
    track.setNote(1, "C-3".note)
    track.setInstrument(1, 0)
    track.setEffect(1, 0, etSetTimbre, 2)
    track.setNote(3, noteCut)
    let ir = toIr(track)
    check:
      ir.srcLen == testLen
      countKinds(ir) == (rests: 3, ops: 2)
  
