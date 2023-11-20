
import libtrackerboy/[data, ir, notes]

import unittest2

import std/sequtils

when NimMajor >= 2:
  {.warning[ImplicitDefaultValue]:off.}

func mkRow(note, inst, et1, ep1, et2, ep2, et3, ep3 = 0u8;): TrackRow =
  result.note = note
  result.instrument = inst
  result.effects[0].effectType = et1
  result.effects[0].param = ep1
  result.effects[1].effectType = et2
  result.effects[1].param = ep2
  result.effects[2].effectType = et3
  result.effects[2].param = ep3

func rowOp(note, inst, et1, ep1, et2, ep2, et3, ep3 = 0u8;): Operation =
  toOperation mkRow(note, inst, et1, ep1, et2, ep2, et3, ep3)

const
  CUT = noteCut + 1
  e0XY = etArpeggio.uint8
  e1XX = etPitchUp.uint8
  e3XX = etAutoPortamento.uint8
  FXX = etSetTempo.uint8
  GXX = etDelayedNote.uint8
  SXX = etDelayedCut.uint8

suite "ir.Operation":

  test "empty row is noop":
    let op = toOperation(default(TrackRow))
    check op.isNoop()

  test "unknown effect is noop":
    let
      row = mkRow(et1 = EffectType.high.uint8 + 1)
      op = toOperation(row)
    check op.isNoop()

  test "G00 is noop":
    let op = rowOp(et1 = GXX)
    check op.isNoop()

  test "invalid speed is noop":
    let 
      op1 = rowOp(et1 = FXX, ep1 = 0x0F)
      op2 = rowOp(et2 = FXX, ep2 = 0xF2)
    check:
      op1.isNoop()
      op2.isNoop()

  test "frequency effect conflict":
    let
      op = rowOp(et1 = e0XY, et2 = e1XX, et3 = e3XX)
    # all effect columns conflict with each other, the last effect is always
    # used.
    check:
      op.flags == { opsFreqMod }
      op.freqMod == freqPortamento
  
  test "pattern command conflict":
    let
      op = rowOp(et1 = etPatternSkip.uint8,
                 et2 = etPatternGoto.uint8,
                 et3 = etPatternHalt.uint8)
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
      op2 = rowOp(et1 = SXX)
      op3 = rowOp(note = CUT, et1 = GXX)
      op4 = rowOp(et1 = GXX, et2 = SXX)
      op5 = rowOp(note = CUT, et1 = GXX, et2 = SXX)
      # case 2 (runtime of 3: cuts in 3 frames)
      op6 = rowOp(note = CUT, et1 = GXX, ep1 = 3)
      op7 = rowOp(note = CUT, et2 = SXX, ep2 = 3)
      op8 = rowOp(note = CUT, et1 = GXX, et2 = SXX, ep2 = 3)
      # case 3 (runtime of 6: delays note by 4, then delayed cut in 2 frames)
      op9 = rowOp(note = CUT, et1 = GXX, ep1 = 4,
                              et2 = SXX, ep2 = 2)

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
  
