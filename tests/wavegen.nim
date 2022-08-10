
# module generates wav files for verification that Synth works
# a square tone is generated for a couple different samplerates.
# the wav files are generated in a folder called "wavegen" in the same directory
# as the executable

import libtrackerboy/private/[hardware, synth, wavwriter]
import libtrackerboy/common

import std/[os, strformat, typetraits]

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
    s.setBufferSize(w.samplerate) # 1 sec

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
        generate(s, mixMiddle, getTimeStep(w.leftFrequency))
    else:
        if w.leftFrequency > 0:
            generate(s, mixLeft, getTimeStep(w.leftFrequency))
        if w.rightFrequency > 0:
            generate(s, mixRight, getTimeStep(w.rightFrequency))

proc `$`(w: Waveform): string =
    result = fmt"tone_{w.samplerate}Hz_{w.leftFrequency}Hz_{w.rightFrequency}Hz.wav"

when isMainModule:

    var buf: seq[Pcm]
    let outDir = getAppDir().joinPath("wavegen.d")
    outDir.createDir()

    var s = Synth.init()
    s.volumeStepLeft = volumeStep
    s.volumeStepRight = volumeStep
    for i, preset in presetWaveforms.pairs:
        generateWaveform(s, preset)
        s.takeSamples(gbClockrate, buf.addr)
        var wav = WavWriter.init(joinPath(outDir, $preset), 2, preset.samplerate)
        wav.write(buf)
