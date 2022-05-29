discard """
"""

import ../../src/trackerboy/private/hardware 
import ../../src/trackerboy/[data, engine]
import ../unittest_wrapper

import std/[bitops, with]

type
    ApuWrite = tuple[address, value: uint8]

    DumbApu = object
        ## The dumb apu only emulates apu register io, and logs all register
        ## writes
        enabled: bool
        regs: array[0..(rNR52 - rNR10).int, uint8]
        writes: seq[ApuWrite]

func registerIndex(address: uint8): Option[int] =
    let index = address.int - rNR10.int
    if index >= low(DumbApu.regs) and index <= high(DumbApu.regs):
        result = some(index)

func readRegister(a: DumbApu, address: uint8): uint8 =
    const readMasks: DumbApu.regs.type = [
        0x80u8, 0x3F, 0x00, 0xFF, 0xBF,
        0xFF,   0x3F, 0x00, 0xFF, 0xBF,
        0x7F,   0xFF, 0x9F, 0xFF, 0xBF,
        0xFF,   0xFF, 0x00, 0x00, 0xBF,
        0x00,   0x00, 0x70
    ]

    if not a.enabled:
        return 0xFF

    let index = registerIndex(address)
    if index.isSome():
        if index.get() == high(DumbApu.regs):
            result = if a.enabled: 0xF0 else: 0x70
        else:
            result = a.regs[index.get()] or readMasks[index.get()]
    else:
        result = 0xFF

func writeRegister(a: var DumbApu, address, val: uint8) =
    a.writes.add((address, val))
    let index = registerIndex(address)
    if index.isSome():
        if index.get() == high(DumbApu.regs):
            a.enabled = val.testBit(7)
        else:
            a.regs[index.get()] = val

proc stepRow(engine: var Engine, apu: var DumbApu) =
    while true:
        engine.step(apu)
        if engine.currentFrame().startedNewRow:
            break

unittests:
    suite "Engine playback tests":

        # these test the behavior of the engine. Sample module data is played and
        # diagnostic data from the engine is checked, or the writes made to the
        # apu.

        var apu: DumbApu
        var module = Module.new()
        var engine: Engine

        setup:
            apu.writes.setLen(0)
            module[] = Module.init()
            engine = Engine.init()
            engine.module = module.toCRef()

        test "empty pattern":
            engine.play()
            for i in 0..32:
                engine.step(apu)
                check engine.currentFrame().time == i
            check apu.writes.len == 0

        test "speed timing":

            proc speedtest(expected: openarray[bool], engine: var Engine, apu: var DumbApu, song: var Song, speed: Speed) =
                const testAmount = 5
                checkpoint "speed = " & $speed
                song.speed = speed
                engine.play()
                for i in 0..<testAmount:
                    for startedNewRow in expected:
                        engine.step(apu)
                        let frame = engine.currentFrame()
                        check frame.speed == speed
                        check frame.startedNewRow == startedNewRow

            let song = module.songs[0]
            speedtest([true], engine, apu, song[], 0x10)
            speedtest([true, false, false, true, false], engine, apu, song[], 0x28)
            speedtest([true, false, false, false, false, false], engine, apu, song[], 0x60)

        test "song looping":
            let song = module.songs[0]
            song.speed = unitSpeed
            song[].setTrackSize(1)
            song.order.setLen(3)
            engine.play()

            engine.step(apu)
            check engine.currentFrame().order == 0
            engine.step(apu)
            check engine.currentFrame().order == 1 and engine.currentFrame().startedNewPattern
            engine.step(apu)
            check engine.currentFrame().order == 2 and engine.currentFrame().startedNewPattern
            engine.step(apu)
            check engine.currentFrame().order == 0 and engine.currentFrame().startedNewPattern

        test "Bxx effect":
            let song = module.songs[0]
            song.speed = unitSpeed
            song.order.setLen(3)
            song.order[1] = [1u8, 0, 0, 0]
            var track = song[].getTrack(ch1, 0)
            track[].setEffect(0, 0, etPatternGoto, 1)
            track = song[].getTrack(ch1, 1)
            track[].setEffect(0, 0, etPatternGoto, 0xFF)

            engine.play()
            engine.step(apu)
            var frame = engine.currentFrame()
            check frame.order == 0
            engine.step(apu)
            frame = engine.currentFrame()
            check frame.order == 1 and frame.startedNewPattern
            engine.step(apu)
            frame = engine.currentFrame()
            check frame.order == 2 and frame.startedNewPattern

        test "Dxx effect":
            let song = module.songs[0]
            song.speed = unitSpeed
            song.order.insert([0u8, 0, 1, 0], 1)
            var track = song[].getTrack(ch1, 0)
            track[].setEffect(0, 0, etPatternSkip, 10)
            track = song[].getTrack(ch3, 1)
            track[].setEffect(10, 1, etPatternSkip, 32)

            engine.play()
            engine.step(apu)
            var frame = engine.currentFrame()
            check frame.order == 0
            engine.step(apu)
            frame = engine.currentFrame()
            check:
                frame.order == 1
                frame.row == 10
            engine.step(apu)
            frame = engine.currentFrame()
            check:
                frame.order == 0
                frame.row == 32

        test "C00 effect":
            let song = module.songs[0]
            song.speed = unitSpeed
            let track = song[].getTrack(ch1, 0)
            track[].setEffect(0, 0, etPatternHalt, 0)
            engine.play()
            # halt effect occurs here
            engine.step(apu)
            check not engine.currentFrame().halted
            # halt takes effect before the start of a new row
            engine.step(apu)
            check engine.currentFrame().halted
            # check that we are still halted after repeated calls to step
            engine.step(apu)
            check engine.currentFrame().halted

        test "Fxx effect":
            let song = module.songs[0]
            let track = song[].getTrack(ch1, 0)
            with track[]:
                setEffect(4, 0, etSetTempo, 0x40)
                setEffect(5, 0, etSetTempo, 0x02) # invalid speed
                setEffect(6, 0, etSetTempo, 0xFF) # invalid speed
            engine.play()
            for i in 0..<4:
                engine.stepRow(apu)
                check engine.currentFrame().speed == defaultSpeed
            engine.stepRow(apu)
            check engine.currentFrame().speed == 0x40
            engine.stepRow(apu)
            check engine.currentFrame().speed == 0x40 # speed should be unchanged
            engine.stepRow(apu)
            check engine.currentFrame().speed == 0x40 # speed should be unchanged