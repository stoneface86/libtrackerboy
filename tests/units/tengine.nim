
import libtrackerboy/engine/[enginestate, apucontrol]
import libtrackerboy/private/[hardware]
import libtrackerboy/[data, engine, notes, text]

import unittest2

import std/[strformat, times]

func getSampleTable(): WaveformTable =
  result = initWaveformTable()
  let id = result.add()
  result[id][].data = litWave("0123456789ABCDEFFEDCBA9876543210")

func `==`(a, b: ChannelUpdate): bool =
  if a.action == b.action:
    if a.action == caUpdate:
      return a.state == b.state and a.flags == b.flags and a.trigger == b.trigger
    else:
      return true

# shortcut constructors

template mkState(f = 0u16, e = 0u16, t = 0u8, p = 0u8): ChannelState =
  ChannelState(
    frequency: f,
    envelope: e,
    timbre: t,
    panning: p
  )

template mkCut(): ChannelUpdate =
  ChannelUpdate(action: caCut)

template mkShutdown(): ChannelUpdate =
  ChannelUpdate(action: caShutdown)

template mkUpdate(s = ChannelState(), f: UpdateFlags = {}, t = false): ChannelUpdate =
  ChannelUpdate(
    action: caUpdate,
    state: s,
    flags: f,
    trigger: t
  )

template mkUpdates(up1 = ChannelUpdate(); up2 = ChannelUpdate();
                   up3 = ChannelUpdate(); up4 = ChannelUpdate()
                  ): array[ChannelId, ChannelUpdate] =
  [up1, up2, up3, up4]

template mkOperation(u: array[ChannelId, ChannelUpdate], s = none(uint8), v = none(uint8)): ApuOperation =
  ApuOperation(
    updates: u,
    sweep: s,
    volume: v
  )

# proc stepRow(engine: var Engine, instruments: InstrumentTable) =
#   while true:
#     engine.step(instruments)
#     if engine.currentFrame().startedNewRow:
#       break

type
  EngineHarness = object
    engine*: Engine
    instruments*: InstrumentTable
    song*: ref Song
  

func initEngineHarness(): EngineHarness =
  result = EngineHarness(
    engine: initEngine(),
    instruments: initInstrumentTable(),
    song: newSong()
  )

proc play(e: var EngineHarness; order = 0; row = 0) =
  e.engine.play(e.song.toImmutable, songPos(order, row))

func currentState(e: EngineHarness, chno: ChannelId): ChannelState =
  e.engine.currentState(chno)

func currentFrame(e: EngineHarness): EngineFrame =
  e.engine.currentFrame()

func currentFrequency(e: EngineHarness, chno: ChannelId): uint16 =
  e.currentState(chno).frequency

func currentNote(e: EngineHarness, chno: ChannelId): int =
  e.engine.currentNote(chno)

proc step(e: var EngineHarness) =
  e.engine.step(e.instruments)

proc stepRow(e: var EngineHarness) =
  while true:
    e.step()
    if e.currentFrame().startedNewRow:
      break

proc frequencyTest(e: var EngineHarness, chno: ChannelId): uint16 =
  e.step()
  result = e.currentFrequency(chno)

proc noteTest(e: var EngineHarness, chno: ChannelId): int =
  e.step()
  result = e.currentNote(chno)

proc panningTest(e: var EngineHarness, chno: ChannelId): tuple[track, state: uint8] =
  e.step()
  result = (
    e.engine.getTrackPanning(chno),
    e.currentState(chno).panning
  )

proc timbreTest(e: var EngineHarness, chno: ChannelId): tuple[track, state: uint8] =
  e.step()
  result = (
    e.engine.getTrackTimbre(chno),
    e.currentState(chno).timbre
  )

proc envelopeTest(e: var EngineHarness, chno: ChannelId): tuple[track: uint8, state: uint16] =
  e.step()
  result = (
    e.engine.getTrackEnvelope(chno),
    e.currentState(chno).envelope
  )

template setupSong(e: var EngineHarness, songVar, body: untyped) =
  template songVar(): var Song =
    e.song[]
  body

# template setupInstruments(e: var EngineHarness, instrumentsVar, body: untyped) =
#   template instrumentsVar(): var InstrumentTable =
#     e.instruments
#   body

template forCurrentFrame(e: EngineHarness, frameVar, body: untyped) =
  ## Sets `frameVar` to the engine's current frame for checking.
  block:
    let frameVar {.inject.} = e.currentFrame()
    body

template frameTest(e: var EngineHarness, frameVar, body: untyped) =
  ## Utility template combines e.step() and e.forCurrentFrame(frameVar, body)
  e.step()
  forCurrentFrame(e, frameVar):
    body

block: # =========================================================== apucontrol

  func `$`(aw: ApuWrite): string =
    &"${aw.regaddr:02X} <- ${aw.value:02X}"

  func `$`(list: ApuWriteList): string =
    result.add('[')
    if list.len >= 1:
      for i in 0..<list.len-1:
        result.add($list.data[i])
        result.add(", ")
      result.add($list.data[list.len-1])
    result.add(']')

  func aw(reg, val: uint8): ApuWrite = (reg, val)

  func `^`[Idx](data: sink array[Idx, ApuWrite]): ApuWriteList =
    when Idx.high - Idx.low > ApuWriteList.data.len:
      {.error: "Cannot make a ApuWriteList from the given array".}
    for i, item in data.pairs:
      result.data[i] = item
    result.len = data.len

  func `==`(a, b: ApuWriteList): bool =
    if a.len != b.len:
      return false
    for i in 0..<a.len:
      if a.data[i] != b.data[i]:
        return false
    result = true

  suite "engine.apucontrol":
    test "ApuWriteList":
      var list: ApuWriteList
      list.add(0, 1)
      list.add(1, 2)
      list.add(0, 0)

      check list == ^[aw(0, 1), aw(1, 2), aw(0, 0)]


    test "empty operation results in no writes":
      let wt = initWaveformTable()
      check getWrites(ApuOperation(), wt, 0x00u8).len == 0

    test "update timbre":
      let wt = initWaveformTable()
      
      func timbreTest(timbre: uint8, wt: WaveformTable): ApuWriteList =
        let op = mkOperation(
          mkUpdates(
            mkUpdate(mkState(t = timbre), {ufTimbre}),
            mkUpdate(mkState(t = timbre), {ufTimbre}),
            mkUpdate(mkState(t = timbre), {ufTimbre}),
            mkUpdate(mkState(t = timbre), {ufTimbre})
          )
        )
        getWrites(op, wt, 0)

      check timbreTest(0, wt) == ^[
        aw(rNR11, 0x00),
        aw(rNR21, 0x00),
        aw(rNR32, 0x00),
        aw(rNR43, lookupNoiseNote(0))
      ]
      check timbreTest(1, wt) == ^[
        aw(rNR11, 0x40),
        aw(rNR21, 0x40),
        aw(rNR32, 0x60),
        aw(rNR43, lookupNoiseNote(0) or 0x8)
      ]
      check timbreTest(2, wt) == ^[
        aw(rNR11, 0x80),
        aw(rNR21, 0x80),
        aw(rNR32, 0x40),
        aw(rNR43, lookupNoiseNote(0) or 0x8)
      ]
      check timbreTest(3, wt) == ^[
        aw(rNR11, 0xC0),
        aw(rNR21, 0xC0),
        aw(rNR32, 0x20),
        aw(rNR43, lookupNoiseNote(0) or 0x8)
      ]

    test "cuts":
      let wt = initWaveformTable()
      let op = mkOperation(
        mkUpdates(mkCut(), mkCut(), mkCut(), mkCut())
      )
      check getWrites(op, wt, 0xFF) == ^[
        aw(rNR51, 0x00)
      ]

    test "panning":
      # ch1 and ch4 will update the panning
      # ch2 and ch3 panning should be untouched
      let wt = initWaveformTable()
      let op = mkOperation(
        mkUpdates(
          up1 = mkUpdate(mkState(p = 2), {ufPanning}),
          up4 = mkUpdate(mkState(p = 3), {ufPanning})
        )
      )
      check getWrites(op, wt, 0b0000_0000) == ^[aw(rNR51, 0b1000_1001)]
      check getWrites(op, wt, 0b0110_0110) == ^[aw(rNR51, 0b1110_1111)]
      # no change in panning results in no write to nr51 being added
      check getWrites(op, wt, 0b10001001).len == 0

    test "trigger":
      let wt = initWaveformTable()
      let op = mkOperation(
        mkUpdates(
          mkUpdate(mkState(e = 0xF0, p = 3), t = true),
          mkUpdate(mkState(e = 0xF1, f = 0x3DE, p = 3), t = true),
          mkUpdate(mkState(p = 3), t = true),
          mkUpdate(mkState(e = 0xA3, p = 3), t = true)
        )
      )
      check getWrites(op, wt, 0) == ^[
        aw(rNR12, 0xF0),
        aw(rNR14, 0x80),
        aw(rNR22, 0xF1),
        aw(rNR24, 0x83), # Note that the 3 comes from the MSB of frequency
        aw(rNR42, 0xA3),
        aw(rNR44, 0x80),
        aw(rNR51, 0xFF)
      ]

    test "envelope":
      let wt = getSampleTable()
      var op = mkOperation(
        mkUpdates(
          up2 = mkUpdate(mkState(e = 0xD4), {ufEnvelope}),
          up3 = mkUpdate(mkState(e = 0x00), {ufEnvelope})
        )
      )
      check getWrites(op, wt, 0) == ^[
        aw(rNR22, 0xD4),
        aw(rNR24, 0x80),
        aw(rNR30, 0x00),
        aw(rWAVERAM, 0x01),
        aw(rWAVERAM+1, 0x23),
        aw(rWAVERAM+2, 0x45),
        aw(rWAVERAM+3, 0x67),
        aw(rWAVERAM+4, 0x89),
        aw(rWAVERAM+5, 0xAB),
        aw(rWAVERAM+6, 0xCD),
        aw(rWAVERAM+7, 0xEF),
        aw(rWAVERAM+8, 0xFE),
        aw(rWAVERAM+9, 0xDC),
        aw(rWAVERAM+10, 0xBA),
        aw(rWAVERAM+11, 0x98),
        aw(rWAVERAM+12, 0x76),
        aw(rWAVERAM+13, 0x54),
        aw(rWAVERAM+14, 0x32),
        aw(rWAVERAM+15, 0x10),
        aw(rNR30, 0x80),
        aw(rNR34, 0x80)
      ]
      # no waveform with the id, no writes
      op = mkOperation(mkUpdates(up3 = mkUpdate(mkState(e = 3), {ufEnvelope})))
      check getWrites(op, wt, 0).len == 0

    test "frequency":
      let wt = initWaveformTable()
      let op = mkOperation(
        mkUpdates(
          up2 = mkUpdate(ChannelState(frequency: 0x1D9, envelope: 0x77), {ufFrequency, ufEnvelope}),
          up3 = mkUpdate(ChannelState(frequency: 0x7FF), {ufFrequency}),
          up4 = mkUpdate(ChannelState(frequency: 20), {ufFrequency})
        )
      )
      check getWrites(op, wt, 0) == ^[
        aw(rNR22, 0x77),
        aw(rNR23, 0xD9),
        aw(rNR24, 0x81),
        aw(rNR33, 0xFF),
        aw(rNR34, 0x07),
        aw(rNR43, lookupNoiseNote(20))
      ]

    test "sweep":
      let wt = initWaveformTable()
      let op = mkOperation(
        mkUpdates(
          up1 = mkUpdate(mkState(e = 0xF0), t = true)
        ),
        some(0x77u8)
      )
      check getWrites(op, wt, 0) == ^[
        aw(rNR10, 0x77),
        aw(rNR12, 0xF0),
        aw(rNR14, 0x80),
        aw(rNR10, 0x00)
      ]

    test "volume":
      let wt = initWaveformTable()
      let op = mkOperation(
        mkUpdates(),
        v = some(0x43u8)
      )
      check getWrites(op, wt, 0) == ^[aw(rNR50, 0x43)]

    test "stress test":
      # this should be the maximum number of writes possible from an ApuOperation
      # to make sure getWrites() never exceeds the capacity of an ApuWriteList
      let wt = getSampleTable()
      let op = mkOperation(
        mkUpdates(
          mkShutdown(),   # +5 writes
          mkShutdown(),   # +5
          mkUpdate(
            mkState(0x432, 0, 3, 3),
            ufAll
          ),              # 1 + 16 + 1 + 3 = 21
          mkShutdown()    # +5
        ),
        some(0x11u8),       # +2
        some(0x45u8)        # +1
      )
      check getWrites(op, wt, 0) == ^[
        aw(rNR10, 0x11),
        aw(rNR10, 0x00),
        aw(rNR11, 0x00),
        aw(rNR12, 0x00),
        aw(rNR13, 0x00),
        aw(rNR14, 0x00),
        aw(rNR10, 0x00),

        aw(rNR21 - 1, 0x00),
        aw(rNR21, 0x00),
        aw(rNR22, 0x00),
        aw(rNR23, 0x00),
        aw(rNR24, 0x00),

        aw(rNR30, 0x00),
        aw(rWAVERAM, 0x01),
        aw(rWAVERAM+1, 0x23),
        aw(rWAVERAM+2, 0x45),
        aw(rWAVERAM+3, 0x67),
        aw(rWAVERAM+4, 0x89),
        aw(rWAVERAM+5, 0xAB),
        aw(rWAVERAM+6, 0xCD),
        aw(rWAVERAM+7, 0xEF),
        aw(rWAVERAM+8, 0xFE),
        aw(rWAVERAM+9, 0xDC),
        aw(rWAVERAM+10, 0xBA),
        aw(rWAVERAM+11, 0x98),
        aw(rWAVERAM+12, 0x76),
        aw(rWAVERAM+13, 0x54),
        aw(rWAVERAM+14, 0x32),
        aw(rWAVERAM+15, 0x10),
        aw(rNR30, 0x80),
        aw(rNR32, 0x20),
        aw(rNR33, 0x32),
        aw(rNR34, 0x84),

        aw(rNR41 - 1, 0x00),
        aw(rNR41, 0x00),
        aw(rNR42, 0x00),
        aw(rNR43, 0x00),
        aw(rNR44, 0x00),

        aw(rNR50, 0x45),
        aw(rNR51, 0x44)
      ]

block: # =========================================================== effects
  suite "engine.effects":
    test "0xy":  # arpeggio
      const
        baseNote1 = litNote("C-4")
        baseNote2 = litNote("C-8")
        maxFreq = lookupToneNote(ToneNote.high)
        chord12 = [
          lookupToneNote(baseNote1.value),
          lookupToneNote(baseNote1.value + 1),
          lookupToneNote(baseNote1.value + 2)
        ]
        noiseBaseNote = noteColumn(NoiseNote.high - 11)

      var eh = initEngineHarness()
      eh.setupSong(s):
        s.speed = unitSpeed
        s.editTrack(ch1, 0, track):
          track[0].note = baseNote1
          track[0].effects[0] = litEffect("012")
          track[5].effects[0] = litEffect("000")
          track[7].note = baseNote2
          track[7].effects[0] = litEffect("0FF")
        s.editTrack(ch4, 0, track):
          track[0] = litTrackRow("C-2 .. 012 ... ...")
          track[5] = litTrackRow("... .. 000 ... ...")
          track[7].note = noiseBaseNote
          track[7].effects[0] = litEffect("0FF")
      
      # tone arpeggio
      eh.play()
      check:
        eh.frequencyTest(ch1) == chord12[0]                       # 00 (note C-4, effect 012)
        eh.frequencyTest(ch1) == chord12[1]                       # 01
        eh.frequencyTest(ch1) == chord12[2]                       # 02
        eh.frequencyTest(ch1) == chord12[0]                       # 03
        eh.frequencyTest(ch1) == chord12[1]                       # 04
        eh.frequencyTest(ch1) == chord12[0]                       # 05 (effect 000)
        eh.frequencyTest(ch1) == chord12[0]                       # 06
        eh.frequencyTest(ch1) == lookupToneNote(baseNote2.value)  # 07 (note C-8, effect 0FF)
        eh.frequencyTest(ch1) == maxFreq                          # 08
        eh.frequencyTest(ch1) == maxFreq                          # 09
        eh.frequencyTest(ch1) == lookupToneNote(baseNote2.value)  # 0A
        
      # noise arpeggio
      eh.play()
      check:
        eh.frequencyTest(ch4) == 0                       # 00 (note C-2, effect 012)
        eh.frequencyTest(ch4) == 1                       # 01
        eh.frequencyTest(ch4) == 2                       # 02
        eh.frequencyTest(ch4) == 0                       # 03
        eh.frequencyTest(ch4) == 1                       # 04
        eh.frequencyTest(ch4) == 0                       # 05 (effect 000)
        eh.frequencyTest(ch4) == 0                       # 06
        eh.frequencyTest(ch4) == noiseBaseNote.value     # 07 (note C-6, effect 0FF)
        eh.frequencyTest(ch4) == NoiseNote.high.uint16   # 08
        eh.frequencyTest(ch4) == NoiseNote.high.uint16   # 09
        eh.frequencyTest(ch4) == noiseBaseNote.value     # 0A

    test "1xx":  # pitch slide up
      const
        startToneNote = noteColumn(ToneNote.high)
        toneNote2 = litNote("C-4")
        startFreq = lookupToneNote(startToneNote.value)
      
      var eh = initEngineHarness()
      eh.setupSong(s):
        s.speed = unitSpeed
        s.editTrack(ch1, 0, track):
          track[0].note = startToneNote
          track[0].effects[0] = litEffect("109")
          track[1].effects[0] = litEffect("100")
          track[2].effects[0] = litEffect("109")
          track[4].note = toneNote2
        s.editTrack(ch4, 0, track):
          track[0].note = noteColumn(49)
          track[0].effects[0] = litEffect("109")
          track[0].effects[0] = litEffect("109")
          track[1].effects[0] = litEffect("100")
          track[2].effects[0] = litEffect("109")
          track[4].note = noteColumn(0)

      eh.play()
      check:
        eh.frequencyTest(ch1) == startFreq + 9
        eh.frequencyTest(ch1) == startFreq + 9
        eh.frequencyTest(ch1) == 0x7FF
        eh.frequencyTest(ch1) == 0x7FF
        eh.frequencyTest(ch1) == lookupToneNote(toneNote2.value) + 9

      eh.play()
      check:
        eh.frequencyTest(ch4) == 49u16 + 9
        eh.frequencyTest(ch4) == 49u16 + 9
        eh.frequencyTest(ch4) == NoiseNote.high.uint16
        eh.frequencyTest(ch4) == NoiseNote.high.uint16
        eh.frequencyTest(ch4) == 0u16 + 9

    # test "2xx":  # pitch slide down
    #     discard

    # test "3xx":  # automatic portamento
    #     discard

    # test "4xy":  # vibrato
    #     discard

    # test "5xx":  # vibrato delay
    #     discard

    test "Bxx":  # pattern goto
      var eh = initEngineHarness()
      eh.setupSong(s):
        s.speed = unitSpeed
        s.order.setLen(3)
        s.order[1] = [1u8, 0, 0, 0]
        s.editTrack(ch1, 0, track):
          track[0] = litTrackRow("... .. B01 ... ...")
        s.editTrack(ch1, 1, track):
          track[0] = litTrackRow("... .. BFF ... ...")
      eh.play()
      
      eh.frameTest(f):
        check f.order == 0
      
      eh.frameTest(f):
        check:
          f.order == 1
          f.startedNewPattern

      eh.frameTest(f):
        check:
          f.order == 2
          f.startedNewPattern

    test "C00":  # halt
      var eh = initEngineHarness()
      eh.setupSong(s):
        s.speed = unitSpeed
        s.editTrack(ch1, 0, track):
          track[0] = litTrackRow("... .. C00 ... ...")
      eh.play()

      # halt effect occurs here
      eh.frameTest(f):
        check not f.halted
      # halt takes effect before the start of a new row
      eh.frameTest(f):
        check f.halted
      # check that we are still halted after repeated calls to step
      eh.frameTest(f):
        check f.halted

    test "Dxx":  # pattern skip
      var eh = initEngineHarness()
      eh.setupSong(s):
        s.speed = unitSpeed
        s.order = @[
          orow(0, 0, 0, 0),
          orow(0, 0, 1, 0)
        ]
        s.editTrack(ch1, 0, track):
          track[0] = litTrackRow("... .. D0A ... ...")
        s.editTrack(ch3, 1, track):
          track[10] = litTrackRow("... .. ... D20 ...")

      eh.play()
      eh.frameTest(f):
        check f.order == 0
      eh.frameTest(f):
        check:
          f.order == 1
          f.row == 10
      eh.frameTest(f):
        check:
          f.order == 0
          f.row == 32

    test "Fxx":  # set speed
      var eh = initEngineHarness()
      eh.setupSong(s):
        s.editTrack(ch1, 0, track):
          track[4] = litTrackRow("... .. F40 ... ...")
          track[5] = litTrackRow("... .. F02 ... ...") # invalid speed
          track[6] = litTrackRow("... .. FFF ... ...") # invalid speed
      eh.play()
      for i in 0..<4:
        eh.stepRow()
        check eh.currentFrame().speed == uint8(defaultSpeed)
      
      eh.stepRow()
      check eh.currentFrame().speed == 0x40u8
      
      eh.stepRow()
      check eh.currentFrame().speed == 0x40u8 # speed should be unchanged
      
      eh.stepRow()
      check eh.currentFrame().speed == 0x40u8 # speed should be unchanged

    test "Exx":  # set envelope
      discard

    test "Gxx":  # note delay
      var eh = initEngineHarness()

      eh.setupSong(s):
        s.speed = Speed(0x20)
        # 00 : A-4 -- G01
        # 01 : G-3 -- G04
        # 02 : --- -- ---
        # 03 : --- -- ---
        # 04 : A-4 -- G02 <- this note doesn't play since row 5 occurs before the delay expires
        # 05 : F-3 -- ---
        s.editTrack(ch1, 0, track):
          track[0] = litTrackRow("A-4 .. G01 ... ...")
          track[1] = litTrackRow("G-3 .. G04 ... ...")
          # 02
          # 03
          track[4] = litTrackRow("A-4 .. G02 ... ...")
          track[5] = litTrackRow("F-3 .. ... ... ...")

      eh.play()
      
      const 
        noteA4 = toNote(A, 4)
        noteG3 = toNote(G, 3)
        noteF3 = toNote(F, 3)

      # frame 0: no change
      check eh.noteTest(ch1) == 0
      # frame 1: note was set to A-4 (row 00 delayed by 1 frame)
      check eh.noteTest(ch1) == noteA4.int

      # frames 2-5, no change
      for i in 2..5:
        check eh.noteTest(ch1) == noteA4.int

      # frame 6: note was set to G-3 (row 01 delayed by 4 frames)
      check eh.noteTest(ch1) == noteG3.int

      # frames 7-9: no change
      for i in 7..9:
        check eh.noteTest(ch1) == noteG3.int

      # frame 10: note was set to F-3 (row 05 performed)
      check eh.noteTest(ch1) == noteF3.int


    # test "Hxx":  # set sweep register
    #     discard

    # test "I0x":  # set channel panning
    #     discard

    # test "Jxy":  # set global volume
    #     discard

    test "L00":  # lock channel (music priority)
      var eh = initEngineHarness()
      eh.setupSong(s):
        s.speed = unitSpeed
        s.editPattern(0, pat):
          pat[ch1][0] = litTrackRow("... .. L00 ... ...")
          pat[ch2][1] = litTrackRow("... .. L00 ... ...")
          pat[ch3][2] = litTrackRow("... .. L00 ... ...")
          pat[ch4][3] = litTrackRow("... .. L00 ... ...")
      
      eh.play()
      
      for ch in ChannelId:
        eh.engine.unlock(ch)

      check eh.engine.getLocked() == {}
      
      eh.step()
      check eh.engine.getLocked() == { ch1 }

      eh.step()
      check eh.engine.getLocked() == { ch1..ch2 }

      eh.step()
      check eh.engine.getLocked() == { ch1..ch3 }

      eh.step()
      check eh.engine.getLocked() == { ch1..ch4 }

    test "Pxx (tone)":  # fine tuning
      const
        testNote1Freq = lookupToneNote(toNote(C, 4))
        testNote2Freq = lookupToneNote(toNote(D, 6))

      var eh = initEngineHarness()
      # 00 C-4 .. ... ; freq = testNote1Freq
      # 01 ... .. P80 ; freq = testNote1Freq
      # 02 ... .. P7F ; freq = testNote1Freq - 1
      # 03 ... .. P81 ; freq = testNote1Freq + 1
      # 04 D-6 .. ... ; freq = testNote2Freq + 1
      # 05 C-4 .. P80 ; freq = testNote1Freq
      # 06 ... .. P00 ; freq = testNote1Freq - 128
      # 07 ... .. PFF ; freq = testNote1Freq + 127
      # 08 B-8 .. ... ; freq = 2047 (clamped)
      # 09 C-2 .. P00 ; freq = 0 (clamped)
      eh.setupSong(s):
        s.speed = unitSpeed
        s.editTrack(ch1, 0, track):
          track[0] = litTrackRow("C-4 .. ... ... ...")
          track[1] = litTrackRow("... .. P80 ... ...")
          track[2] = litTrackRow("... .. P7F ... ...")
          track[3] = litTrackRow("... .. P81 ... ...")
          track[4] = litTrackRow("D-6 .. ... ... ...")
          track[5] = litTrackRow("C-4 .. P80 ... ...")
          track[6] = litTrackRow("... .. P00 ... ...")
          track[7] = litTrackRow("... .. PFF ... ...")
          track[8] = litTrackRow("B-8 .. ... ... ...")
          track[9] = litTrackRow("C-2 .. P00 ... ...")

      eh.play()
      check:
        eh.frequencyTest(ch1) == testNote1Freq
        eh.frequencyTest(ch1) == testNote1Freq
        eh.frequencyTest(ch1) == testNote1Freq - 1
        eh.frequencyTest(ch1) == testNote1Freq + 1
        eh.frequencyTest(ch1) == testNote2Freq + 1
        eh.frequencyTest(ch1) == testNote1Freq
        eh.frequencyTest(ch1) == testNote1Freq - 128
        eh.frequencyTest(ch1) == testNote1Freq + 127
        eh.frequencyTest(ch1) == 2047
        eh.frequencyTest(ch1) == 0

    test "Pxx (noise)":
      const
        testNote = uint16(toNote(C, 4))

      var eh = initEngineHarness()
      eh.setupSong(s):
        s.speed = unitSpeed
        s.editTrack(ch4, 0, track):
          track[0] = litTrackRow("C-4 .. ... ... ...")
          track[1] = litTrackRow("... .. P80 ... ...")
          track[2] = litTrackRow("... .. P81 ... ...")
          track[3] = litTrackRow("... .. P7F ... ...")
          track[4] = litTrackRow("... .. PFF ... ...")
          track[5] = litTrackRow("... .. P00 ... ...")
      
      eh.play()
      check:
        eh.frequencyTest(ch4) == testNote
        eh.frequencyTest(ch4) == testNote
        eh.frequencyTest(ch4) == testNote + 1
        eh.frequencyTest(ch4) == testNote - 1
        eh.frequencyTest(ch4) == NoiseNote.high.uint16
        eh.frequencyTest(ch4) == NoiseNote.low.uint16

    # test "Qxy":  # note slide up
    #     discard

    # test "Rxy":  # note slide down
    #     discard

    # test "Sxx":  # delayed note cut
    #     discard

    # test "Txx":  # play sound effect
    #     discard

    test "V0x":  # set timbre
      var eh = initEngineHarness()
      eh.setupSong(s):
        s.speed = unitSpeed
        s.editTrack(ch1, 0, track):
          track[0] = litTrackRow("... .. V00 ... ...")
          track[1] = litTrackRow("... .. V01 ... ...")
          track[2] = litTrackRow("... .. V02 ... ...")
          track[3] = litTrackRow("... .. V03 ... ...")
          track[4] = litTrackRow("... .. V04 ... ...")
          track[5] = litTrackRow("... .. V00 ... ...")
          track[6] = litTrackRow("... .. VFF ... ...")
          track[7] = litTrackRow("C-2 .. ... ... ...")
          track[8] = litTrackRow("... .. V02 ... ...")
      eh.play()

      check:
        eh.timbreTest(ch1) == (0u8, 0xFFu8)
        eh.timbreTest(ch1) == (1u8, 0xFFu8)
        eh.timbreTest(ch1) == (2u8, 0xFFu8)
        eh.timbreTest(ch1) == (3u8, 0xFFu8)
        eh.timbreTest(ch1) == (3u8, 0xFFu8)
        eh.timbreTest(ch1) == (0u8, 0xFFu8)
        eh.timbreTest(ch1) == (3u8, 0xFFu8)
        eh.timbreTest(ch1) == (3u8, 3u8)
        eh.timbreTest(ch1) == (2u8, 2u8)

block: # =========================================================== Engine
  suite "engine.Engine":
    setup:
      var engine = initEngine()
    
    test "play raises AssertionDefect on nil song":
      expect AssertionDefect:
        engine.play(toImmutable[ref Song](nil))

    test "play raises IndexDefect on invalid pattern index":
      var song = newSong()
      expect IndexDefect:
        engine.play(song.toImmutable, songPos(song.order.len))

    test "play raises IndexDefect on invalid row index":
      var song = newSong()
      expect IndexDefect:
        engine.play(song.toImmutable, songPos(0, song[].trackLen))

block: # ========================================================== instruments
  const
    testNote = 24

  func getHarness(): EngineHarness =
    result = initEngineHarness()
    let id = result.instruments.add()
    result.setupSong(s):
      s.editTrack(ch1, 0, track):
        track[0].note = noteColumn(testNote)
        track[0].instrument = instrumentColumn(id)
  
  suite "engine.instruments":

    setup:
      var eh = getHarness()
      let instrument = eh.instruments[0]

    test "arp":
      const
        expected = [
          lookupToneNote(testNote),
          lookupToneNote(testNote + 1),
          lookupToneNote(testNote + 2),
          lookupToneNote(testNote + 3),
          lookupToneNote(testNote - 1)
        ]
      
      instrument[].sequences[skArp] = litSequence("0 1 2 3 -1")

      eh.play()
      check:
        eh.frequencyTest(ch1) == expected[0]
        eh.frequencyTest(ch1) == expected[1]
        eh.frequencyTest(ch1) == expected[2]
        eh.frequencyTest(ch1) == expected[3]
        eh.frequencyTest(ch1) == expected[4]
        # non-looping sequence ends, ensure that state is the last value in the sequence
        eh.frequencyTest(ch1) == expected[4]
        eh.frequencyTest(ch1) == expected[4]
    
    test "pitch":
      const
        baseFreq = lookupToneNote(testNote)

      instrument[].sequences[skPitch] = litSequence("0 | -1 -1 -1 1 1 1")
      
      # this pitch sequence simulates a triangle vibrato in range [-3, 0]

      eh.play()
      check eh.frequencyTest(ch1) == baseFreq
      for _ in 0..2:
        check:
          eh.frequencyTest(ch1) == baseFreq - 1
          eh.frequencyTest(ch1) == baseFreq - 2
          eh.frequencyTest(ch1) == baseFreq - 3
          eh.frequencyTest(ch1) == baseFreq - 2
          eh.frequencyTest(ch1) == baseFreq - 1
          eh.frequencyTest(ch1) == baseFreq

    test "panning":
      instrument[].sequences[skPanning] = litSequence("3 2 1 0 2 -1 5")

      eh.play()
      check:
        eh.panningTest(ch1) == (3u8, 3u8)
        eh.panningTest(ch1) == (3u8, 2u8)
        eh.panningTest(ch1) == (3u8, 1u8)
        eh.panningTest(ch1) == (3u8, 0u8)
        eh.panningTest(ch1) == (3u8, 2u8)
        # tests that invalid values in the sequence are clamped
        eh.panningTest(ch1) == (3u8, 3u8)
        eh.panningTest(ch1) == (3u8, 3u8)

    test "timbre":
      instrument[].sequences[skTimbre] = litSequence("0 0 1 1 3 2")
      eh.play()
      check:
        eh.timbreTest(ch1) == (3u8, 0u8)
        eh.timbreTest(ch1) == (3u8, 0u8)
        eh.timbreTest(ch1) == (3u8, 1u8)
        eh.timbreTest(ch1) == (3u8, 1u8)
        eh.timbreTest(ch1) == (3u8, 3u8)
        eh.timbreTest(ch1) == (3u8, 2u8) # sequence ends
        eh.timbreTest(ch1) == (3u8, 2u8)

    test "envelope":
      instrument[].sequences[skEnvelope].data = @[0x91u8, 0x00, 0x91, 0x00]
      eh.play()
      check:
        eh.envelopeTest(ch1) == (0xF0u8, 0x91u16)
        eh.envelopeTest(ch1) == (0xF0u8, 0x00u16)
        eh.envelopeTest(ch1) == (0xF0u8, 0x91u16)
        eh.envelopeTest(ch1) == (0xF0u8, 0x00u16)

block: # ============================================================= playback
  
  # these test the behavior of the engine. Sample module data is played and
  # diagnostic data from the engine is checked, or the writes made to the
  # apu.
  
  suite "engine.playback":
    
    test "empty pattern":
      var eh = initEngineHarness()
      eh.play()
      for i in 0..32:
        eh.step()
        check:
          eh.engine.takeOperation() == ApuOperation.default
          eh.currentFrame().time == i

    test "speed timing":
      proc speedtest(expected: openarray[bool], speed: Speed) =
        const testAmount = 5
        var eh = initEngineHarness()
        checkpoint "speed = " & $speed
        eh.song.speed = speed
        eh.play()
        for i in 0..<testAmount:
          for startedNewRow in expected:
            eh.frameTest(f):
              check:
                f.speed == uint8(speed)
                f.startedNewRow == startedNewRow

      speedtest([true],  Speed(0x10))
      speedtest([true, false, false, true, false], Speed(0x28))
      speedtest([true, false, false, false, false, false], Speed(0x60))

    test "song looping":
      var eh = initEngineHarness()
      eh.setupSong(s):
        s.speed = unitSpeed
        s.trackLen = 1
        s.order.setLen(3)
      eh.play()
      eh.frameTest(f):
        check f.order == 0
      eh.frameTest(f):
        check:
          f.order == 1
          f.startedNewPattern
      eh.frameTest(f):
        check:
          f.order == 2
          f.startedNewPattern
      eh.frameTest(f):
        check:
          f.order == 0
          f.startedNewPattern
