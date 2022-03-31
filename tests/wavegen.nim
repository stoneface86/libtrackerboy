
# module generates wav files for verification that Synth works
# a square tone is generated for a couple different samplerates.
# The CRC32 of each generated tone is reported to be stored in tsynth.nim

# run via nimble:
# $ nimble wavegen

# you only need to run this if you change the filter or resampling algorithm
# used in the synth module. Doing so invalidates the checksums stored in the
# test_synth module. The unit test just generates the tones and compares its
# generated checksums to the verified ones.

# to verify:
# run the wavegen task and listen to each of the wav files generated
# the filename has the format tone_xHz_yHz_zHz.wav where
#  x - the samplerate
#  y - the frequency of the tone on the left channel (0 for silence)
#  z - the frequency of the tone on the right channel (0 for silence)
# play each wav file and verify by ear that the tones on each channel are
# correct and of desired quality.

import trackerboy/synth
import trackerboy/private/hardware
import crc32
export Crc32


type

    Waveform = object
        samplerate: int
        leftFrequency: int
        rightFrequency: int
        description: string

const

    presetWaveforms = [
        # these test the resampling
        Waveform(samplerate: 11025, leftFrequency: 440, rightFrequency: 440, description: "resampling test: 11025 Hz"),
        Waveform(samplerate: 12000, leftFrequency: 440, rightFrequency: 440, description: "resampling test: 12000 Hz"),
        Waveform(samplerate: 22050, leftFrequency: 440, rightFrequency: 440, description: "resampling test: 22050 Hz"),
        Waveform(samplerate: 24000, leftFrequency: 440, rightFrequency: 440, description: "resampling test: 24000 Hz"),
        Waveform(samplerate: 44100, leftFrequency: 440, rightFrequency: 440, description: "resampling test: 44100 Hz"),
        Waveform(samplerate: 48000, leftFrequency: 440, rightFrequency: 440, description: "resampling test: 48000 Hz"),
        # these test the mixing (0 frequency is mute)
        Waveform(samplerate: 44100, leftFrequency: 1200, rightFrequency: 0, description: "mixing test: left"),
        Waveform(samplerate: 44100, leftFrequency: 0, rightFrequency: 4000, description: "mixing test: right"),
        Waveform(samplerate: 44100, leftFrequency: 64, rightFrequency: 12000, description: "mixing test: middle")
    ]

    volumeStep = 0.5f


proc generateWaveform(s: var Synth, w: Waveform) =
    s.samplerate = w.samplerate
    s.setBuffer(w.samplerate) # 1 sec

    proc generate(s: var Synth, mode: static MixMode, timeStep: float32) =
        var time = 0.0f
        var delta = 1.int8
        while time < gbClockrate:
            s.mix(mode, delta, time.uint32)
            delta = -delta
            time += timeStep

    proc getTimeStep(freq: int): float32 =
        result = gbClockrate.float32 / freq.float32 / 2.0f

    if w.leftFrequency == w.rightFrequency:
        generate(s, MixMode.middle, getTimeStep(w.leftFrequency))
    else:
        if w.leftFrequency > 0:
            generate(s, MixMode.left, getTimeStep(w.leftFrequency))
        if w.rightFrequency > 0:
            generate(s, MixMode.right, getTimeStep(w.rightFrequency))
    
    s.endFrame(gbClockrate)

iterator generatePresets*(buf: var seq[Pcm]): (int, Crc32) =
    var s = initSynth()
    s.leftVolume = volumeStep
    s.rightVolume = volumeStep
    for i, preset in presetWaveforms.pairs:
        generateWaveform(s, preset)
        buf.setLen(s.availableSamples() * 2)
        assert s.readSamples(buf) == buf.len() div 2

        yield (i, buf.crc32)

proc describePreset*(index: int): string =
    result = presetWaveforms[index].description


when isMainModule:
    import trackerboy/private/wavwriter
    import std/[os, strformat, typetraits]

    proc `$`(w: Waveform): string =
        result = fmt"tone_{w.samplerate}Hz_{w.leftFrequency}Hz_{w.rightFrequency}Hz.wav"

    var buf: seq[Pcm]
    var checksums: array[presetWaveforms.len, Crc32]
    let appDir = getAppDir()

    for i, checksum in generatePresets(buf):
        let preset = presetWaveforms[i]
        var wav = initWavWriter(joinPath(appDir, $preset), 2, preset.samplerate)
        wav.write(buf)

        checksums[i] = checksum

    proc printChecksum(crc: Crc32) =
        stdout.write($crc & "." & name(Crc32))

    for checksum in checksums[0..^2]:
        printChecksum(checksum)
        echo ","
    printChecksum(checksums[^1])
    echo ""
