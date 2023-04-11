
import utils
import ../testing
import libtrackerboy/notes

import std/with

const
  testNote = 24

func getHarness(): EngineHarness =
  result = EngineHarness.init()
  let id = result.instruments.add()
  result.setupSong(s):
    s.editTrack(ch1, 0, track):
      with track:
        setNote(0, testNote)
        setInstrument(0, id)

testclass "instruments"

testgroup:
  setup:
    var eh = getHarness()
    let instrument = eh.instruments[0]

  dtest "arp":
    const
      expected = [
        lookupToneNote(testNote),
        lookupToneNote(testNote + 1),
        lookupToneNote(testNote + 2),
        lookupToneNote(testNote + 3)
      ]
    
    instrument[].sequences[skArp] = parseSequence("0 1 2 3")

    eh.play()
    check:
      eh.frequencyTest(ch1) == expected[0]
      eh.frequencyTest(ch1) == expected[1]
      eh.frequencyTest(ch1) == expected[2]
      eh.frequencyTest(ch1) == expected[3]
      # non-looping sequence ends, ensure that state is the last value in the sequence
      eh.frequencyTest(ch1) == expected[3]
      eh.frequencyTest(ch1) == expected[3]
  
  dtest "pitch":
    const
      baseFreq = lookupToneNote(testNote)

    instrument[].sequences[skPitch] = parseSequence("0 | -1 -1 -1 1 1 1")
    
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

  dtest "panning":
    instrument[].sequences[skPanning] = parseSequence("3 2 1 0 2 -1 5")

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

  dtest "timbre":
    instrument[].sequences[skTimbre] = parseSequence("0 0 1 1 3 2")
    eh.play()
    check:
      eh.timbreTest(ch1) == (3u8, 0u8)
      eh.timbreTest(ch1) == (3u8, 0u8)
      eh.timbreTest(ch1) == (3u8, 1u8)
      eh.timbreTest(ch1) == (3u8, 1u8)
      eh.timbreTest(ch1) == (3u8, 3u8)
      eh.timbreTest(ch1) == (3u8, 2u8) # sequence ends
      eh.timbreTest(ch1) == (3u8, 2u8)

  dtest "envelope":
    instrument[].sequences[skEnvelope].data = @[0x91u8, 0x00, 0x91, 0x00]
    eh.play()
    check:
      eh.envelopeTest(ch1) == (0xF0u8, 0x91u16)
      eh.envelopeTest(ch1) == (0xF0u8, 0x00u16)
      eh.envelopeTest(ch1) == (0xF0u8, 0x91u16)
      eh.envelopeTest(ch1) == (0xF0u8, 0x00u16)