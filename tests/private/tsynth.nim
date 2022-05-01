discard """
"""

import ../../src/trackerboy/private/[hardware, synth]
import ../../src/trackerboy/common

import ../unittest_wrapper

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

unittests:
    suite "synth":

        const samplerate = 44100

        test "highpass":
            # test the highpass filter
            # an impulse is mixed at time 0 and the signal generated should
            # decay to 0. Only the decay is tested, not the performance of the filter itself

            var synth = initSynth(samplerate, samplerate)
            # mix an impulse on the left channel
            synth.mixDc(1.0f, 0.0f, 0)
            synth.endFrame(gbClockrate) # 1 sec

            # read samples, check that 1 second of audio was generated
            var buf: seq[Pcm]
            synth.takeSamples(buf)
            check buf.len == samplerate * 2

            # check that only the left channel has a signal
            check not buf.isZero(0)
            check buf.isZero(1)

            # check that the left signal decays
            checkpoint "checking the decay"
            let first = buf[0]
            let last = buf[^2]
            proc checkDecay(): bool =
                for sample in iterateChannel(buf.toOpenArray(2, buf.len - 4), 0):
                    if sample < last or sample >= first:
                        return
                result = true
            check checkDecay()

        test "resampling":
            const samplerates = [11025, 22050, 44100, 88200]

            var synth = initSynth()
            var buf: seq[Pcm]
            for rate in samplerates:
                checkpoint "resample test @ " & $rate & " Hz"
                synth.samplerate = rate
                synth.setBufferSize(rate * 2)
                # mix an impulse at t = 1s
                synth.mixDc(1.0f, 0.0f, gbClockRate)
                synth.endFrame(gbClockRate * 2)

                # get the samples
                synth.takeSamples(buf)
                check buf.len == rate * 2 * 2

                # check that at t == 1s, the buffer contains an impulse
                check buf[rate * 2] > 0.0f


        test "mixing":
            proc equals(buf1, buf2: openarray[Pcm], channel: int): bool =
                if buf1.len == buf2.len:
                    var time = channel
                    while time < buf1.len:
                        if buf1[time] != buf2[time]:
                            return false
                        time += 2
                    result = true

            var synth = initSynth(samplerate, samplerate)
            synth.volumeStepLeft = 0.125f
            synth.volumeStepRight = 0.125f
            var bufleft, bufright, bufmiddle: seq[Pcm]

            proc mixtest(buf: var seq[Pcm], mode: MixMode) =
                synth.clear()
                # mix a simple square waveform
                synth.mix(mode, 1, 4000)    # +1 volume step at t = 0.000953s
                synth.mix(mode, -2, 262144) # -1 volume step at t = 0.0625s
                synth.mix(mode, 1, 524288)  # zero crossing at t = 0.125s
                synth.endFrame(786432)      # end frame at t = 0.1875s
                synth.takeSamples(buf)
            
            mixtest(bufleft, mixLeft)
            mixtest(bufright, mixRight)
            mixtest(bufmiddle, mixMiddle)

            check:
                not bufleft.isZero(0)
                bufleft.isZero(1)
                bufright.isZero(0)
                not bufright.isZero(1)
                not bufmiddle.isZero(0)
                not bufmiddle.isZero(1)
                equals(bufleft, bufmiddle, 0)
                equals(bufright, bufmiddle, 1)
