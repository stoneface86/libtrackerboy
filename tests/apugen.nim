## module generates wav files for verification that the apu module works
## each test is a sequence of register writes using the vblank interval as a time
## step. Each test will test a specific part of the APU.

import ../src/trackerboy/apu
import ../src/trackerboy/private/hardware


type
    ApuTestOperation = enum
        opHold,
        opWrite
    
    # can't use object variants due to nim vm issue with const
    ApuTestCommand = object
        op: ApuTestOperation
        frames: int
        address, value: uint8


proc cmdHold(frames: int): ApuTestCommand =
    ApuTestCommand(op: opHold, frames: frames)

proc cmdWrite(address, value: uint8): ApuTestCommand =
    ApuTestCommand(op: opWrite, address: address, value: value)

const
    testSamplerate* = 44100
    cyclesPerWrite = 12
    cyclesPerFrame = 70256u32

const tests* = (
    duty: [
        cmdWrite(rNR52, 0x80), cmdWrite(rNR50, 0x77), cmdWrite(rNR51, 0x11),
        cmdWrite(rNR12, 0xF0), cmdWrite(rNR13, 0), cmdWrite(rNR14, 0x87),
        cmdWrite(rNR11, 0x00), cmdHold(60), # duty = 12.5%

        cmdWrite(rNR11, 0x40), cmdHold(60), # duty = 25%
        cmdWrite(rNR11, 0x80), cmdHold(60), # duty = 50%
        cmdWrite(rNR11, 0xC0), cmdHold(60)  # duty = 75%
    ],
    masterVolume: [
        # frame 0, setup control regs and retrigger CH1 with duty = 0 (12.5%)
        cmdWrite(rNR52, 0x80), cmdWrite(rNR51, 0x11), cmdWrite(rNR50, 0x07),
        cmdWrite(rNR11, 0x80), cmdWrite(rNR12, 0xF0), cmdWrite(rNR13, 0x00), cmdWrite(rNR14, 0x87),
        cmdHold(2),
        cmdWrite(rNR50, 0x16), cmdHold(2),
        cmdWrite(rNR50, 0x25), cmdHold(2),
        cmdWrite(rNR50, 0x34), cmdHold(2),
        cmdWrite(rNR50, 0x43), cmdHold(2),
        cmdWrite(rNR50, 0x52), cmdHold(2),
        cmdWrite(rNR50, 0x61), cmdHold(2),
        cmdWrite(rNR50, 0x70), cmdHold(60),
        cmdWrite(rNR50, 0x61), cmdHold(2),
        cmdWrite(rNR50, 0x52), cmdHold(2),
        cmdWrite(rNR50, 0x43), cmdHold(2),
        cmdWrite(rNR50, 0x34), cmdHold(2),
        cmdWrite(rNR50, 0x25), cmdHold(2),
        cmdWrite(rNR50, 0x16), cmdHold(2),
        cmdWrite(rNR50, 0x07), cmdHold(60)
    ],
    noise: [
        # frame 0, setup control regs and retrigger CH4
        cmdWrite(rNR52, 0x80), cmdWrite(rNR50, 0x77), cmdWrite(rNR51, 0x88),
        cmdWrite(rNR42, 0xF0), cmdWrite(rNR43, 0x77), cmdWrite(rNR44, 0x80), cmdHold(5),
        cmdWrite(rNR43, 0x76), cmdHold(5),
        cmdWrite(rNR43, 0x75), cmdHold(5),
        cmdWrite(rNR43, 0x74), cmdHold(5),
        cmdWrite(rNR43, 0x67), cmdHold(5),
        cmdWrite(rNR43, 0x66), cmdHold(5),
        cmdWrite(rNR43, 0x65), cmdHold(5),
        cmdWrite(rNR43, 0x64), cmdHold(5),
        cmdWrite(rNR43, 0x57), cmdHold(5),
        cmdWrite(rNR43, 0x56), cmdHold(5),
        cmdWrite(rNR43, 0x55), cmdHold(5),
        cmdWrite(rNR43, 0x54), cmdHold(5),
        cmdWrite(rNR43, 0x47), cmdHold(5),
        cmdWrite(rNR43, 0x46), cmdHold(5),
        cmdWrite(rNR43, 0x45), cmdHold(5),
        cmdWrite(rNR43, 0x44), cmdHold(5),
        cmdWrite(rNR43, 0x37), cmdHold(5),
        cmdWrite(rNR43, 0x36), cmdHold(5),
        cmdWrite(rNR43, 0x35), cmdHold(5),
        cmdWrite(rNR43, 0x34), cmdHold(5),
        cmdWrite(rNR43, 0x27), cmdHold(5),
        cmdWrite(rNR43, 0x26), cmdHold(5),
        cmdWrite(rNR43, 0x25), cmdHold(5),
        cmdWrite(rNR43, 0x24), cmdHold(5),
        cmdWrite(rNR43, 0x17), cmdHold(5),
        cmdWrite(rNR43, 0x16), cmdHold(5),
        cmdWrite(rNR43, 0x15), cmdHold(5),
        cmdWrite(rNR43, 0x14), cmdHold(5),
        cmdWrite(rNR43, 0x07), cmdHold(5),
        cmdWrite(rNR43, 0x06), cmdHold(5),
        cmdWrite(rNR43, 0x05), cmdHold(5),
        cmdWrite(rNR43, 0x04), cmdHold(5),
        cmdWrite(rNR43, 0x03), cmdHold(5),
        cmdWrite(rNR43, 0x02), cmdHold(5),
        cmdWrite(rNR43, 0x01), cmdHold(5),
        cmdWrite(rNR43, 0x00), cmdHold(5)
    ],
    wave: [
        # frame 0, setup control regs and retrigger CH4
        cmdWrite(rNR52, 0x80), cmdWrite(rNR50, 0x77), cmdWrite(rNR51, 0x44),
        cmdWrite(rNR32, 0x20), # volume = 100%
        cmdWrite(rWAVERAM,      0x01),
        cmdWrite(rWAVERAM + 1,  0x23),
        cmdWrite(rWAVERAM + 2,  0x45),
        cmdWrite(rWAVERAM + 3,  0x67),
        cmdWrite(rWAVERAM + 4,  0x89),
        cmdWrite(rWAVERAM + 5,  0xAB),
        cmdWrite(rWAVERAM + 6,  0xCD),
        cmdWrite(rWAVERAM + 7,  0xEF),
        cmdWrite(rWAVERAM + 8,  0xFE),
        cmdWrite(rWAVERAM + 9,  0xDC),
        cmdWrite(rWAVERAM + 10, 0xBA),
        cmdWrite(rWAVERAM + 11, 0x98),
        cmdWrite(rWAVERAM + 12, 0x76),
        cmdWrite(rWAVERAM + 13, 0x54),
        cmdWrite(rWAVERAM + 14, 0x32),
        cmdWrite(rWAVERAM + 15, 0x10),
        cmdWrite(rNR30, 0x80), # DAC on
        cmdWrite(rNR34, 0x80), # trigger
        cmdHold(30),
        cmdWrite(rNR34, 0x01), cmdHold(30),
        cmdWrite(rNR34, 0x02), cmdHold(30),
        cmdWrite(rNR34, 0x03), cmdHold(30),
        cmdWrite(rNR34, 0x04), cmdHold(30),
        cmdWrite(rNR34, 0x05), cmdHold(30),
        cmdWrite(rNR34, 0x06), cmdHold(30),
        cmdWrite(rNR34, 0x07), cmdHold(60),
        # fade out
        cmdWrite(rNR32, 2 shl 5), cmdHold(15),
        cmdWrite(rNR32, 3 shl 5), cmdHold(15),
        cmdWrite(rNR32, 0 shl 5), cmdHold(15)
    ],
    headroom: [
        cmdWrite(rNR52, 0x80), cmdWrite(rNR51, 0xFF), cmdWrite(rNR50, 0x77),
        cmdWrite(rNR12, 0xF0), cmdWrite(rNR14, 0x87), cmdHold(60),
        cmdWrite(rNR21, 0x80), cmdWrite(rNR22, 0xF0), cmdWrite(rNR24, 0x87), cmdHold(60),
        cmdWrite(rWAVERAM,      0x01),
        cmdWrite(rWAVERAM + 1,  0x23),
        cmdWrite(rWAVERAM + 2,  0x45),
        cmdWrite(rWAVERAM + 3,  0x67),
        cmdWrite(rWAVERAM + 4,  0x89),
        cmdWrite(rWAVERAM + 5,  0xAB),
        cmdWrite(rWAVERAM + 6,  0xCD),
        cmdWrite(rWAVERAM + 7,  0xEF),
        cmdWrite(rWAVERAM + 8,  0xFE),
        cmdWrite(rWAVERAM + 9,  0xDC),
        cmdWrite(rWAVERAM + 10, 0xBA),
        cmdWrite(rWAVERAM + 11, 0x98),
        cmdWrite(rWAVERAM + 12, 0x76),
        cmdWrite(rWAVERAM + 13, 0x54),
        cmdWrite(rWAVERAM + 14, 0x32),
        cmdWrite(rWAVERAM + 15, 0x10),
        cmdWrite(rNR30, 0x80), # DAC on
        cmdWrite(rNR34, 0x84), cmdHold(60),
        cmdWrite(rNR42, 0xF0), cmdWrite(rNR43, 0x55), cmdWrite(rNR44, 0x80),
        cmdHold(60)
    ],
    envelope: [
        cmdWrite(rNR52, 0x80), cmdWrite(rNR50, 0x77), cmdWrite(rNR51, 0x11),
        cmdWrite(rNR12, 0xF7), cmdWrite(rNR14, 0x87), cmdHold(120),
        cmdWrite(rNR12, 0xF6), cmdWrite(rNR14, 0x87), cmdHold(90),
        cmdWrite(rNR12, 0xF5), cmdWrite(rNR14, 0x87), cmdHold(70),
        cmdWrite(rNR12, 0xF4), cmdWrite(rNR14, 0x87), cmdHold(60),
        cmdWrite(rNR12, 0xF3), cmdWrite(rNR14, 0x87), cmdHold(50),
        cmdWrite(rNR12, 0xF2), cmdWrite(rNR14, 0x87), cmdHold(40),
        cmdWrite(rNR12, 0xF1), cmdWrite(rNR14, 0x87), cmdHold(30),
        cmdWrite(rNR14, 0x87), cmdHold(10),
        cmdWrite(rNR14, 0x87), cmdHold(10),
        cmdWrite(rNR14, 0x87), cmdHold(10),
        cmdWrite(rNR14, 0x87), cmdHold(10)
    ],
    panning: [
        cmdWrite(rNR52, 0x80), cmdWrite(rNR51, 0x00), cmdWrite(rNR50, 0x77),
        cmdWrite(rNR11, 0x80), cmdWrite(rNR12, 0xFF), cmdWrite(rNR14, 0x87),
        cmdWrite(rNR11, 0x80), cmdWrite(rNR12, 0xFF), cmdWrite(rNR14, 0x87),
        cmdWrite(rNR21, 0x40), cmdWrite(rNR22, 0xFF), cmdWrite(rNR24, 0x87),
        cmdWrite(rWAVERAM,      0x01),
        cmdWrite(rWAVERAM + 1,  0x23),
        cmdWrite(rWAVERAM + 2,  0x45),
        cmdWrite(rWAVERAM + 3,  0x67),
        cmdWrite(rWAVERAM + 4,  0x89),
        cmdWrite(rWAVERAM + 5,  0xAB),
        cmdWrite(rWAVERAM + 6,  0xCD),
        cmdWrite(rWAVERAM + 7,  0xEF),
        cmdWrite(rWAVERAM + 8,  0xFE),
        cmdWrite(rWAVERAM + 9,  0xDC),
        cmdWrite(rWAVERAM + 10, 0xBA),
        cmdWrite(rWAVERAM + 11, 0x98),
        cmdWrite(rWAVERAM + 12, 0x76),
        cmdWrite(rWAVERAM + 13, 0x54),
        cmdWrite(rWAVERAM + 14, 0x32),
        cmdWrite(rWAVERAM + 15, 0x10),
        cmdWrite(rNR30, 0x80), cmdWrite(rNR34, 0x87),
        cmdWrite(rNR42, 0xFF), cmdWrite(rNR43, 0x44),  cmdWrite(rNR44, 0x80),
        cmdHold(2),
        cmdWrite(rNR51, 0x10), cmdHold(4),
        cmdWrite(rNR51, 0x01), cmdHold(4),
        cmdWrite(rNR51, 0x11), cmdHold(4),
        cmdWrite(rNR51, 0x20), cmdHold(4),
        cmdWrite(rNR51, 0x02), cmdHold(4),
        cmdWrite(rNR51, 0x22), cmdHold(4),
        cmdWrite(rNR51, 0x40), cmdHold(4),
        cmdWrite(rNR51, 0x04), cmdHold(4),
        cmdWrite(rNR51, 0x44), cmdHold(4),
        cmdWrite(rNR51, 0x80), cmdHold(4),
        cmdWrite(rNR51, 0x08), cmdHold(4),
        cmdWrite(rNR51, 0x88), cmdHold(4)
    ],
    pops: [
        cmdWrite(rNR52, 0x80), cmdWrite(rNR50, 0x77),
        cmdWrite(rNR51, 0x11), cmdHold(4),
        cmdWrite(rNR51, 0x33), cmdHold(4),
        cmdWrite(rNR51, 0x77), cmdHold(4),
        cmdWrite(rNR51, 0xFF), cmdHold(4),
        cmdWrite(rNR51, 0x77), cmdHold(4),
        cmdWrite(rNR51, 0x33), cmdHold(4),
        cmdWrite(rNR51, 0x11), cmdHold(4),
        cmdWrite(rNR51, 0x00), cmdHold(4),
        cmdWrite(rNR51, 0x10), cmdHold(4),
        cmdWrite(rNR51, 0x01), cmdHold(4),
        cmdWrite(rNR51, 0x00), cmdHold(4),
        cmdWrite(rNR51, 0xFF), cmdHold(4),
        cmdWrite(rNR51, 0x00), cmdHold(4),
        cmdWrite(rNR51, 0xFF), cmdHold(4)
    ],
    lengthCounter: [
        cmdWrite(rNR52, 0x80), cmdWrite(rNR50, 0x77), cmdWrite(rNR51, 0x11),
        cmdWrite(rNR11, 0x10),
        cmdWrite(rNR12, 0x80),
        cmdWrite(rNR14, 0xC3), cmdHold(30),
        cmdWrite(rNR14, 0xC2), cmdHold(30)
    ],
    highFrequency: [
        cmdWrite(rNR52, 0x80), cmdWrite(rNR50, 0x77), cmdWrite(rNR51, 0x11),
        cmdWrite(rNR11, 0x80),
        cmdWrite(rNR12, 0xF0),
        cmdWrite(rNR13, 0xE0),
        cmdWrite(rNR14, 0x87), cmdHold(10), # 4096
        cmdWrite(rNR13, 0xE4), cmdHold(10), # 4681
        cmdWrite(rNR13, 0xE8), cmdHold(10), # 5461
        cmdWrite(rNR13, 0xEC), cmdHold(10), # 6553
        cmdWrite(rNR13, 0xF0), cmdHold(10), # 8192
        cmdWrite(rNR13, 0xF4), cmdHold(10), # 10922
        cmdWrite(rNR13, 0xF8), cmdHold(10), # 16384
        cmdWrite(rNR13, 0xF9), cmdHold(10), # 18724
        cmdWrite(rNR13, 0xFA), cmdHold(10), # 21845
        cmdWrite(rNR13, 0xFB), cmdHold(10), # 26214
        cmdWrite(rNR13, 0xFC), cmdHold(10), # 32768
        cmdWrite(rNR13, 0xF8), cmdHold(10), #
        cmdWrite(rNR13, 0xF9), cmdHold(10), #
        cmdWrite(rNR13, 0xF8), cmdHold(10),
        cmdWrite(rNR13, 0xF7), cmdHold(10),
        cmdWrite(rNR13, 0xF6), cmdHold(10)
    ]
)

when isMainModule:
    import ../src/trackerboy/private/wavwriter

    proc runTest(test: openarray[ApuTestCommand], apu: var Apu, wav: var WavWriter) =
        var buf: seq[Pcm]
        apu.reset()

        var time = 0u32
        for cmd in test:
            case cmd.op
            of opHold:
                var frames = cmd.frames
                while frames > 0:
                    apu.run(cyclesPerFrame - time)
                    apu.takeSamples(buf)
                    time = 0
                    wav.write(buf)

                    dec frames
            of opWrite:
                apu.run(cyclesPerWrite)
                time += cyclesPerWrite
                apu.writeRegister(cmd.address, cmd.value)


    import std/os

    var a = Apu.init(testSamplerate, testSamplerate)
    let outDir = getAppDir().joinPath("apugen")
    outDir.createDir()
    
    for name, data in tests.fieldPairs:
        var wav = WavWriter.init(joinPath(outDir, "apu_test_" & name & ".wav"), 2, testSamplerate)
        runTest(data, a, wav)
