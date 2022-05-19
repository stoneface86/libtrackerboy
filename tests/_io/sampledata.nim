
#
# Sample data to be used in testing the io module
#

import ../../src/trackerboy/data

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
            i.initEnvelope = true
            i.envelope = 0x57
            i.sequences[skTimbre] = "1".parseSequence
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
            w.data = "0123456789ABCDEFFEDCBA9876543210".parseWave
            w
        ,
        block:
            var w = Waveform.init
            w.name = "Duty 37.5%"
            w.data = "FFFFFFFFFFFF00000000000000000000".parseWave
            w
    ]

let 
    songData: array[SongSamples, Song] = [
        block:
            var s = Song.init
            s.name = "empty"
            s
        ,
        block:
            # file path: data/sample.tbs
            var s = Song.init
            s.name = "test song"
            s.rowsPerBeat = 2
            s.rowsPerMeasure = 8
            s.speed = 0x48
            s.effectCounts = [3.EffectColumns, 1, 1, 1]
            s.setTrackSize(16)
            s.order.setLen(3)
            s.order[0] = [0u8, 0, 0, 0]
            s.order[1] = [1u8, 1, 1, 1]
            s.order[2] = [2u8, 2, 2, 2]
            block:
                var track = s.getTrack(0, 0)
                track[].setNote(0, 0x1F)
                track[].setNote(8, 0x1F)
            block:
                var track = s.getTrack(2, 2)
                track[].setNote(4, 0x1F)
            s
    ]

func get*(sample: InstrumentSamples): lent Instrument =
    instrumentData[sample]

func get*(sample: WaveformSamples): lent Waveform = 
    waveformData[sample]

proc get*(sample: SongSamples): lent Song =
    songData[sample]
