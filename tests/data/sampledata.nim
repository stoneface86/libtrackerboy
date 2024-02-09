
#
# Sample data to be used in testing the io module
#

import libtrackerboy/[data, text]

type
  InstrumentSamples* = enum
    sampleInstrumentEmpty
    sampleInstrument1

  SongSamples* = enum
    sampleSongEmpty
    sampleSongTest

  WaveformSamples* = enum
    sampleWaveformEmpty
    sampleWaveformTriangle
    sampleWaveformDuty375

const
  instrumentData: array[InstrumentSamples, Instrument] = [
    block:
      var i = Instrument.init
      i.name = "empty"
      i
    ,
    block:
      # file path: data/sample.tbi
      var i = Instrument.init
      i.name = "main 1"
      i.sequences[skEnvelope] = litSequence("87")
      i.sequences[skTimbre] = litSequence("1")
      i
  ]
  waveformData: array[WaveformSamples, Waveform] = [
    block:
      var w = Waveform.init
      w.name = "empty"
      w
    ,
    block:
      # file path: data/sample.tbw
      var w = Waveform.init
      w.name = "triangle"
      w.data = litWave("0123456789ABCDEFFEDCBA9876543210")
      w
    ,
    block:
      var w = Waveform.init
      w.name = "Duty 37.5%"
      w.data = litWave("FFFFFFFFFFFF00000000000000000000")
      w
  ]

func get*(sample: InstrumentSamples): lent Instrument =
  instrumentData[sample]

func get*(sample: WaveformSamples): lent Waveform = 
  waveformData[sample]

func get*(sample: SongSamples): Song =
  result = Song.init
  case sample:
  of sampleSongEmpty:
    result.name = "empty"
  of sampleSongTest:
    result.name = "test song"
    result.rowsPerBeat = 2
    result.rowsPerMeasure = 8
    result.speed = 0x48
    result.effectCounts = [3.EffectColumns, 1, 1, 1]
    result.trackLen = 16
    result.order.setLen(3)
    result.order[0] = [0u8, 0, 0, 0]
    result.order[1] = [1u8, 1, 1, 1]
    result.order[2] = [2u8, 2, 2, 2]
    result.editTrack(ch1, 0, track):
      track.setNote(0, 0x1F)
      track.setNote(8, 0x1F)
    result.editTrack(ch3, 2, track):
      track.setNote(4, 0x1F)

func makeModule*(): Module =
  result = Module.init
  result.title = "sample"
  result.artist = "stoneface86"
  result.copyright = "2022 - stoneface86"
  result.comments = "sample module for unit testing"
  result.songs[0][] = get(sampleSongTest)
  for sample in InstrumentSamples:
    let id = result.instruments.add()
    result.instruments[id][] = get(sample)
  for sample in WaveformSamples:
    let id = result.waveforms.add()
    result.waveforms[id][] = get(sample)
