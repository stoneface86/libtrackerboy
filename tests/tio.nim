{.used.}

import trackerboy/[data, io]

import std/[streams, unittest]

# correct serialized waveform
const waveformBinary = [
    # "\0TRACKERBOY\0"
    0x00u8, 0x54, 0x52, 0x41, 0x43, 0x4B, 0x45, 0x52, 0x42, 0x4F, 0x59, 0x00,
    # Major: 0, Minor: 6, Patch: 1
    0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
    # RevMajor: 1, RevMinor: 1
    0x01, 0x01,
    # Block(Id: "WAVE", size: 26)
    0x57, 0x41, 0x56, 0x45, 0x1A, 0x00, 0x00, 0x00, 
    # string(len: 8, data: "triangle")
    0x08, 0x00, 0x74, 0x72, 0x69, 0x61, 0x6E, 0x67, 0x6C, 0x65, 
    # WaveData
    0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
    0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10
]

const waveform = block:
    var w = initWaveform()
    w.name = "triangle"
    w.data = "0123456789ABCDEFFEDCBA9876543210".parseWave
    w

const instrumentBinary = [
    # "\0TRACKERBOY\0"
    0x00u8, 0x54, 0x52, 0x41, 0x43, 0x4B, 0x45, 0x52, 0x42, 0x4F, 0x59, 0x00,
    # Major: 0, Minor: 6, Patch: 1
    0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
    # RevMajor: 1, RevMinor: 1
    0x01, 0x01,
    # Block(id: "INST", size: 28)
    0x49, 0x4E, 0x53, 0x54, 0x1C, 0x00, 0x00, 0x00,
    # string(len: 6, data: "main 1")
    0x06, 0x00, 0x6D, 0x61, 0x69, 0x6E, 0x20, 0x31,
    # channel: 0, initEnvelope: true, envelope: 0x57
    0x00, 0x01, 0x57,
    # sequences[skArp] = ""
    0x00, 0x00, 0x00, 0x00,
    # sequences[skPanning] = ""
    0x00, 0x00, 0x00, 0x00,
    # sequences[skPitch] = ""
    0x00, 0x00, 0x00, 0x00,
    # sequences[skTimbre] = "1"
    0x01, 0x00, 0x00, 0x00, 0x01
]

suite "io":

    setup:
        var stream = newStringStream()

    test "persistance - module":

        var module = initModule()

        module.artist = "foobar"
        module.copyright = "2020"
        module.title = "stuff"

        require module.serialize(stream) == frNone

        var module2 = initModule()

        stream.setPosition(0)
        require module2.deserialize(stream) == frNone

        check:
            module.artist == module2.artist
            module.copyright == module2.copyright
            module.title == module2.title

    test "persistance: waveform":
        require waveform.serialize(stream) == frNone
        stream.setPosition(0)
        var waveformIn = initWaveform()
        require waveformIn.deserialize(stream) == frNone
        check waveform == waveformIn

    test "deserialize: waveform":
        var waveformIn = initWaveform()
        stream.write(waveformBinary)
        stream.setPosition(0)

        require waveformIn.deserialize(stream) == frNone
        check waveformIn == waveform