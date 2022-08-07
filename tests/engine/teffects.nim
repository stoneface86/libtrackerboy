
import trackerboy/[notes]
import utils
import ../testing

import std/[with]

testclass "effects"

func frequencyTestImpl(ch: ChannelId, engine: var Engine, itable: InstrumentTable): uint16 =
    engine.step(itable)
    engine.currentState(ch).frequency

template frequencyTest(ch: ChannelId): untyped =
    frequencyTestImpl(ch, engine, instruments)

# effect tests
# use the effect syntax as the test name
# keep in alphabetical order!

dtest "0xy":  # arpeggio
    testsetup

    const baseNote1 = "C-4".note
    const baseNote2 = "C-8".note
    const maxFreq = lookupToneNote(ToneNote.high)
    const chord12 = [
        lookupToneNote(baseNote1),
        lookupToneNote(baseNote1 + 1),
        lookupToneNote(baseNote1 + 2)
    ]
    const noiseBaseNote = NoiseNote.high - 11

    song.speed = unitSpeed
    song[].editTrack(ch1, 0, track):
        with track:
            setNote(0, baseNote1)
            setEffect(0, 0, etArpeggio, 0x12)
            setEffect(5, 0, etArpeggio, 0x00)
            setNote(7, baseNote2)
            setEffect(7, 0, etArpeggio, 0xFF)
    song[].editTrack(ch4, 0, track):
        with track:
            setNote(0, 0)
            setEffect(0, 0, etArpeggio, 0x12)
            setEffect(5, 0, etArpeggio, 0x00)
            setNote(7, noiseBaseNote)
            setEffect(7, 0, etArpeggio, 0xFF)
    
    # tone arpeggio
    engine.play(song.toImmutable)
    check:
        frequencyTest(ch1) == chord12[0]                  # 00 (note C-4, effect 012)
        frequencyTest(ch1) == chord12[1]                  # 01
        frequencyTest(ch1) == chord12[2]                  # 02
        frequencyTest(ch1) == chord12[0]                  # 03
        frequencyTest(ch1) == chord12[1]                  # 04
        frequencyTest(ch1) == chord12[0]                  # 05 (effect 000)
        frequencyTest(ch1) == chord12[0]                  # 06
        frequencyTest(ch1) == lookupToneNote(baseNote2)   # 07 (note C-8, effect 0FF)
        frequencyTest(ch1) == maxFreq                     # 08
        frequencyTest(ch1) == maxFreq                     # 09
        frequencyTest(ch1) == lookupToneNote(baseNote2)   # 0A
        
    # noise arpeggio
    engine.play(song.toImmutable)
    check:
        frequencyTest(ch4) == 0                       # 00 (note C-2, effect 012)
        frequencyTest(ch4) == 1                       # 01
        frequencyTest(ch4) == 2                       # 02
        frequencyTest(ch4) == 0                       # 03
        frequencyTest(ch4) == 1                       # 04
        frequencyTest(ch4) == 0                       # 05 (effect 000)
        frequencyTest(ch4) == 0                       # 06
        frequencyTest(ch4) == noiseBaseNote           # 07 (note C-6, effect 0FF)
        frequencyTest(ch4) == NoiseNote.high.uint16   # 08
        frequencyTest(ch4) == NoiseNote.high.uint16   # 09
        frequencyTest(ch4) == noiseBaseNote           # 0A

dtest "1xx":  # pitch slide up
    testsetup
    song.speed = unitSpeed

    const startToneNote = ToneNote.high.uint8
    const toneNote2 = "C-4".note
    const startFreq = lookupToneNote(startToneNote)
    song[].editTrack(ch1, 0, track):
        with track:
            setNote(0, startToneNote)
            setEffect(0, 0, etPitchUp, 0x09)
            setEffect(1, 0, etPitchUp, 0x00)
            setEffect(2, 0, etPitchUp, 0x09)
            setNote(4, toneNote2)
    song[].editTrack(ch4, 0, track):
        with track:
            setNote(0, 49)
            setEffect(0, 0, etPitchUp, 0x09)
            setEffect(1, 0, etPitchUp, 0x00)
            setEffect(2, 0, etPitchUp, 0x09)
            setNote(4, 0)

    engine.play(song.toImmutable)
    check:
        frequencyTest(ch1) == startFreq + 9
        frequencyTest(ch1) == startFreq + 9
        frequencyTest(ch1) == 0x7FF
        frequencyTest(ch1) == 0x7FF
        frequencyTest(ch1) == lookupToneNote(toneNote2) + 9

    engine.play(song.toImmutable)
    check:
        frequencyTest(ch4) == 49u16 + 9
        frequencyTest(ch4) == 49u16 + 9
        frequencyTest(ch4) == NoiseNote.high.uint16
        frequencyTest(ch4) == NoiseNote.high.uint16
        frequencyTest(ch4) == 0u16 + 9

# dtest "2xx":  # pitch slide down
#     discard

# dtest "3xx":  # automatic portamento
#     discard

# dtest "4xy":  # vibrato
#     discard

# dtest "5xx":  # vibrato delay
#     discard

dtest "Bxx":  # pattern goto
    testsetup
    song.speed = unitSpeed
    song.order.setLen(3)
    song.order[1] = [1u8, 0, 0, 0]
    song[].editTrack(ch1, 0, track):
        track.setEffect(0, 0, etPatternGoto, 1)
    song[].editTrack(ch1, 1, track):
        track.setEffect(0, 0, etPatternGoto, 0xFF)

    engine.play(song.toImmutable)
    engine.step(instruments)
    var frame = engine.currentFrame()
    check frame.order == 0
    engine.step(instruments)
    frame = engine.currentFrame()
    check frame.order == 1 and frame.startedNewPattern
    engine.step(instruments)
    frame = engine.currentFrame()
    check frame.order == 2 and frame.startedNewPattern

dtest "C00":  # halt
    testsetup
    song.speed = unitSpeed
    song[].editTrack(ch1, 0, track):
        track.setEffect(0, 0, etPatternHalt, 0)
    engine.play(song.toImmutable)
    # halt effect occurs here
    engine.step(instruments)
    check not engine.currentFrame().halted
    # halt takes effect before the start of a new row
    engine.step(instruments)
    check engine.currentFrame().halted
    # check that we are still halted after repeated calls to step
    engine.step(instruments)
    check engine.currentFrame().halted

dtest "Dxx":  # pattern skip
    testsetup
    song.speed = unitSpeed
    song.order.insert([0u8, 0, 1, 0], 1)
    song[].editTrack(ch1, 0, track):
        track.setEffect(0, 0, etPatternSkip, 10)
    song[].editTrack(ch3, 1, track):
        track.setEffect(10, 1, etPatternSkip, 32)

    engine.play(song.toImmutable)
    engine.step(instruments)
    var frame = engine.currentFrame()
    check frame.order == 0
    engine.step(instruments)
    frame = engine.currentFrame()
    check:
        frame.order == 1
        frame.row == 10
    engine.step(instruments)
    frame = engine.currentFrame()
    check:
        frame.order == 0
        frame.row == 32

dtest "Fxx":  # set speed
    testsetup
    song[].editTrack(ch1, 0, track):
        track.setEffect(4, 0, etSetTempo, 0x40)
        track.setEffect(5, 0, etSetTempo, 0x02) # invalid speed
        track.setEffect(6, 0, etSetTempo, 0xFF) # invalid speed
    engine.play(song.toImmutable)
    for i in 0..<4:
        engine.stepRow(instruments)
        check engine.currentFrame().speed == defaultSpeed
    engine.stepRow(instruments)
    check engine.currentFrame().speed == 0x40
    engine.stepRow(instruments)
    check engine.currentFrame().speed == 0x40 # speed should be unchanged
    engine.stepRow(instruments)
    check engine.currentFrame().speed == 0x40 # speed should be unchanged

dtest "Exx":  # set envelope
    discard

# dtest "Gxx":  # note delay
#     discard

# dtest "Hxx":  # set sweep register
#     discard

# dtest "I0x":  # set channel panning
#     discard

# dtest "Jxy":  # set global volume
#     discard

# dtest "L00":  # lock channel (music priority)
#     discard

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
    testsetup
    song.speed = unitSpeed
    song[].editTrack(ch1, 0, track):
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
    engine.play(song.toImmutable)

    func timbreTestImpl(engine: var Engine, itable: InstrumentTable): (uint8, uint8) =
        engine.step(itable)
        (engine.getTrackTimbre(ch1), engine.currentState(ch1).timbre)
    
    template timbreTest(): untyped =
        timbreTestImpl(engine, instruments)


    check:
        timbreTest() == (0u8, 0xFFu8)
        timbreTest() == (1u8, 0xFFu8)
        timbreTest() == (2u8, 0xFFu8)
        timbreTest() == (3u8, 0xFFu8)
        timbreTest() == (3u8, 0xFFu8)
        timbreTest() == (0u8, 0xFFu8)
        timbreTest() == (3u8, 0xFFu8)
        timbreTest() == (3u8, 3u8)
        timbreTest() == (2u8, 2u8)






