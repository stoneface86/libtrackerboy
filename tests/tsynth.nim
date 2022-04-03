{.used.}

import std/unittest

import trackerboy/[common, synth]
import trackerboy/private/hardware

iterator iterateChannel(buf: openArray[Pcm], channel: int): Pcm =
    var time = channel
    while time < buf.len:
        yield buf[time]
        time += 2

proc isZero(buf: openArray[Pcm], channel: int): bool =
    for sample in iterateChannel(buf, channel):
        if sample != 0:
            return false
    result = true

suite "synth":


    test "highpass":

        const samplerate = 44100

        # test the highpass filter
        # an impulse is mixed at time 0 and the signal generated should
        # decay to 0. Only the decay is tested, not the performance of the filter itself

        var synth = initSynth(samplerate)
        synth.setBuffer(samplerate)
        # mix an impulse on the left channel
        synth.mixDc(1.0f, 0.0f, 0)
        synth.endFrame(gbClockrate) # 1 sec

        # read samples, check that 1 second of audio was generated
        var samples: array[samplerate * 2, PcmF32]
        check synth.readSamples(samples) == samplerate


        # check that only the left channel has a signal
        check not samples.isZero(0)
        check samples.isZero(1)

        # check that the left signal decays
        checkpoint "checking the decay"
        let first = samples[0]
        let last = samples[^2]
        for sample in iterateChannel(samples.toOpenArray(2, samples.len - 4), 0):
            assert sample >= last and sample < first
