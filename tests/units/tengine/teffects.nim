
import libtrackerboy/[notes]
import utils
import ../testing

import std/[with]

testclass "effects"

# effect tests
# use the effect syntax as the test name
# keep in alphabetical order!

dtest "0xy":  # arpeggio
  const
    baseNote1 = "C-4".note
    baseNote2 = "C-8".note
    maxFreq = lookupToneNote(ToneNote.high)
    chord12 = [
      lookupToneNote(baseNote1),
      lookupToneNote(baseNote1 + 1),
      lookupToneNote(baseNote1 + 2)
    ]
    noiseBaseNote = NoiseNote.high - 11

  var eh = EngineHarness.init()
  eh.setupSong(s):
    s.speed = unitSpeed
    s.editTrack(ch1, 0, track):
      with track:
        setNote(0, baseNote1)
        setEffect(0, 0, etArpeggio, 0x12)
        setEffect(5, 0, etArpeggio, 0x00)
        setNote(7, baseNote2)
        setEffect(7, 0, etArpeggio, 0xFF)
    s.editTrack(ch4, 0, track):
      with track:
        setNote(0, 0)
        setEffect(0, 0, etArpeggio, 0x12)
        setEffect(5, 0, etArpeggio, 0x00)
        setNote(7, noiseBaseNote)
        setEffect(7, 0, etArpeggio, 0xFF)
  
  # tone arpeggio
  eh.play()
  check:
    eh.frequencyTest(ch1) == chord12[0]                  # 00 (note C-4, effect 012)
    eh.frequencyTest(ch1) == chord12[1]                  # 01
    eh.frequencyTest(ch1) == chord12[2]                  # 02
    eh.frequencyTest(ch1) == chord12[0]                  # 03
    eh.frequencyTest(ch1) == chord12[1]                  # 04
    eh.frequencyTest(ch1) == chord12[0]                  # 05 (effect 000)
    eh.frequencyTest(ch1) == chord12[0]                  # 06
    eh.frequencyTest(ch1) == lookupToneNote(baseNote2)   # 07 (note C-8, effect 0FF)
    eh.frequencyTest(ch1) == maxFreq                     # 08
    eh.frequencyTest(ch1) == maxFreq                     # 09
    eh.frequencyTest(ch1) == lookupToneNote(baseNote2)   # 0A
    
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
    eh.frequencyTest(ch4) == noiseBaseNote           # 07 (note C-6, effect 0FF)
    eh.frequencyTest(ch4) == NoiseNote.high.uint16   # 08
    eh.frequencyTest(ch4) == NoiseNote.high.uint16   # 09
    eh.frequencyTest(ch4) == noiseBaseNote           # 0A

dtest "1xx":  # pitch slide up
  const
    startToneNote = ToneNote.high.uint8
    toneNote2 = "C-4".note
    startFreq = lookupToneNote(startToneNote)
  
  var eh = EngineHarness.init()
  eh.setupSong(s):
    s.speed = unitSpeed
    s.editTrack(ch1, 0, track):
      with track:
        setNote(0, startToneNote)
        setEffect(0, 0, etPitchUp, 0x09)
        setEffect(1, 0, etPitchUp, 0x00)
        setEffect(2, 0, etPitchUp, 0x09)
        setNote(4, toneNote2)
    s.editTrack(ch4, 0, track):
      with track:
        setNote(0, 49)
        setEffect(0, 0, etPitchUp, 0x09)
        setEffect(1, 0, etPitchUp, 0x00)
        setEffect(2, 0, etPitchUp, 0x09)
        setNote(4, 0)

  eh.play()
  check:
    eh.frequencyTest(ch1) == startFreq + 9
    eh.frequencyTest(ch1) == startFreq + 9
    eh.frequencyTest(ch1) == 0x7FF
    eh.frequencyTest(ch1) == 0x7FF
    eh.frequencyTest(ch1) == lookupToneNote(toneNote2) + 9

  eh.play()
  check:
    eh.frequencyTest(ch4) == 49u16 + 9
    eh.frequencyTest(ch4) == 49u16 + 9
    eh.frequencyTest(ch4) == NoiseNote.high.uint16
    eh.frequencyTest(ch4) == NoiseNote.high.uint16
    eh.frequencyTest(ch4) == 0u16 + 9

# dtest "2xx":  # pitch slide down
#     discard

# dtest "3xx":  # automatic portamento
#     discard

# dtest "4xy":  # vibrato
#     discard

# dtest "5xx":  # vibrato delay
#     discard

dtest "Bxx":  # pattern goto
  var eh = EngineHarness.init()
  eh.setupSong(s):
    s.speed = unitSpeed
    s.order.setLen(3)
    s.order[1] = [1u8, 0, 0, 0]
    s.editTrack(ch1, 0, track):
      track.setEffect(0, 0, etPatternGoto, 1)
    s.editTrack(ch1, 1, track):
      track.setEffect(0, 0, etPatternGoto, 0xFF)
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

dtest "C00":  # halt
  var eh = EngineHarness.init()
  eh.setupSong(s):
    s.speed = unitSpeed
    s.editTrack(ch1, 0, track):
      track.setEffect(0, 0, etPatternHalt, 0)
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

dtest "Dxx":  # pattern skip
  var eh = EngineHarness.init()
  eh.setupSong(s):
    s.speed = unitSpeed
    s.order.insert([0u8, 0, 1, 0], 1)
    s.editTrack(ch1, 0, track):
      track.setEffect(0, 0, etPatternSkip, 10)
    s.editTrack(ch3, 1, track):
      track.setEffect(10, 1, etPatternSkip, 32)

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

dtest "Fxx":  # set speed
  var eh = EngineHarness.init()
  eh.setupSong(s):
    s.editTrack(ch1, 0, track):
      track.setEffect(4, 0, etSetTempo, 0x40)
      track.setEffect(5, 0, etSetTempo, 0x02) # invalid speed
      track.setEffect(6, 0, etSetTempo, 0xFF) # invalid speed
  eh.play()
  for i in 0..<4:
    eh.stepRow()
    check eh.currentFrame().speed == defaultSpeed
  
  eh.stepRow()
  check eh.currentFrame().speed == 0x40u8
  
  eh.stepRow()
  check eh.currentFrame().speed == 0x40u8 # speed should be unchanged
  
  eh.stepRow()
  check eh.currentFrame().speed == 0x40u8 # speed should be unchanged

dtest "Exx":  # set envelope
  discard

dtest "Gxx":  # note delay
  var eh = EngineHarness.init()

  const 
    testNote1 = "A-4".note
    testNote2 = "G-3".note
    testNote3 = "F-3".note
  eh.setupSong(s):
    s.speed = 0x20
    # 00 : A-4 -- G01
    # 01 : G-3 -- G04
    # 02 : --- -- ---
    # 03 : --- -- ---
    # 04 : A-4 -- G02 <- this note doesn't play since row 5 occurs before the delay expires
    # 05 : F-3 -- ---
    s.editTrack(ch1, 0, track):
      with track:
        setNote(0, testNote1)
        setEffect(0, 0, etDelayedNote, 1)
        setNote(1, testNote2)
        setEffect(1, 0, etDelayedNote, 4)
        setNote(4, testNote1)
        setEffect(4, 0, etDelayedNote, 2)
        setNote(5, testNote3)

  eh.play()
  
  # frame 0: no change
  check eh.noteTest(ch1) == 0
  # frame 1: note was set to testNote1 (row 00 delayed by 1 frame)
  check eh.noteTest(ch1) == testNote1.int

  # frames 2-5, no change
  for i in 2..5:
    check eh.noteTest(ch1) == testNote1.int

  # frame 6: not was set to testNote2 (row 01 delayed by 4 frames)
  check eh.noteTest(ch1) == testNote2.int

  # frames 7-9: no change
  for i in 7..9:
    check eh.noteTest(ch1) == testNote2.int

  # frame 10: note was set to testNote3 (row 05 performed)
  check eh.noteTest(ch1) == testNote3.int


# dtest "Hxx":  # set sweep register
#     discard

# dtest "I0x":  # set channel panning
#     discard

# dtest "Jxy":  # set global volume
#     discard

dtest "L00":  # lock channel (music priority)
  var eh = EngineHarness.init()
  eh.setupSong(s):
    s.speed = unitSpeed
    s.editPattern(0, pat):
      pat(ch1).setEffect(0, 0, etLock)
      pat(ch2).setEffect(1, 0, etLock)
      pat(ch3).setEffect(2, 0, etLock)
      pat(ch4).setEffect(3, 0, etLock)
  
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

# dtest "Pxx":  # fine tuning
#     discard

# dtest "Qxy":  # note slide up
#     discard

# dtest "Rxy":  # note slide down
#     discard

# dtest "Sxx":  # delayed note cut
#     discard

# dtest "Txx":  # play sound effect
#     discard

dtest "V0x":  # set timbre
  var eh = EngineHarness.init()
  eh.setupSong(s):
    s.speed = unitSpeed
    s.editTrack(ch1, 0, track):
      with track:
        setEffect(0, 0, etSetTimbre, 0)
        setEffect(1, 0, etSetTimbre, 1)
        setEffect(2, 0, etSetTimbre, 2)
        setEffect(3, 0, etSetTimbre, 3)
        setEffect(4, 0, etSetTimbre, 4)
        setEffect(5, 0, etSetTimbre, 0)
        setEffect(6, 0, etSetTimbre, 0xFF)
        setNote(7, "C-2".note)
        setEffect(8, 0, etSetTimbre, 2)
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






