
#import trackerboy/private/hardware 
import trackerboy/[data, engine]
import ../testing

#import std/[bitops]

testclass "Engine.playback"

# type
#     ApuWrite = tuple[address, value: uint8]

#     DumbApu = object
#         ## The dumb apu only emulates apu register io, and logs all register
#         ## writes
#         enabled: bool
#         regs: array[0..(rNR52 - rNR10).int, uint8]
#         writes: seq[ApuWrite]

# func registerIndex(address: uint8): Option[int] =
#     let index = address.int - rNR10.int
#     if index >= low(DumbApu.regs) and index <= high(DumbApu.regs):
#         result = some(index)

# func readRegister(a: DumbApu, address: uint8): uint8 =
#     const readMasks: DumbApu.regs.type = [
#         0x80u8, 0x3F, 0x00, 0xFF, 0xBF,
#         0xFF,   0x3F, 0x00, 0xFF, 0xBF,
#         0x7F,   0xFF, 0x9F, 0xFF, 0xBF,
#         0xFF,   0xFF, 0x00, 0x00, 0xBF,
#         0x00,   0x00, 0x70
#     ]

#     if not a.enabled:
#         return 0xFF

#     let index = registerIndex(address)
#     if index.isSome():
#         if index.get() == high(DumbApu.regs):
#             result = if a.enabled: 0xF0 else: 0x70
#         else:
#             result = a.regs[index.get()] or readMasks[index.get()]
#     else:
#         result = 0xFF

# func writeRegister(a: var DumbApu, address, val: uint8) =
#     a.writes.add((address, val))
#     let index = registerIndex(address)
#     if index.isSome():
#         if index.get() == high(DumbApu.regs):
#             a.enabled = val.testBit(7)
#         else:
#             a.regs[index.get()] = val

proc stepRow(engine: var Engine, instruments: InstrumentTable) =
    while true:
        engine.step(instruments)
        if engine.currentFrame().startedNewRow:
            break

# the suite setup template doesn't seem to work, nim complains that
# the variables are global and not GC-safe
template testsetup(): untyped {.dirty.} =
    # var apu: DumbApu
    # var module = Module.new()
    var engine = Engine.init()
    let song = Song.new()
    var instruments = InstrumentTable.init()
    #apu.writes.setLen(0)
    #engine.module = module.toImmutable()


# these test the behavior of the engine. Sample module data is played and
# diagnostic data from the engine is checked, or the writes made to the
# apu.

dtest "empty pattern":
    testsetup
    engine.play(song.toImmutable)
    for i in 0..32:
        engine.step(instruments)
        check engine.currentFrame().time == i

dtest "speed timing":
    proc speedtest(expected: openarray[bool], speed: Speed) =
        const testAmount = 5
        var engine = Engine.init()
        var instruments = InstrumentTable.init()
        checkpoint "speed = " & $speed
        let song = Song.new()
        song.speed = speed
        engine.play(song.toImmutable)
        for i in 0..<testAmount:
            for startedNewRow in expected:
                engine.step(instruments)
                let frame = engine.currentFrame()
                check frame.speed == speed
                check frame.startedNewRow == startedNewRow

    speedtest([true],  0x10)
    speedtest([true, false, false, true, false], 0x28)
    speedtest([true, false, false, false, false, false], 0x60)

dtest "song looping":
    testsetup
    song.speed = unitSpeed
    song[].setTrackLen(1)
    song.order.setLen(3)
    engine.play(song.toImmutable)

    engine.step(instruments)
    check engine.currentFrame().order == 0
    engine.step(instruments)
    check engine.currentFrame().order == 1 and engine.currentFrame().startedNewPattern
    engine.step(instruments)
    check engine.currentFrame().order == 2 and engine.currentFrame().startedNewPattern
    engine.step(instruments)
    check engine.currentFrame().order == 0 and engine.currentFrame().startedNewPattern

dtest "Bxx effect":
    testsetup
    song.speed = unitSpeed
    song.order.setLen(3)
    song.order[1] = [1u8, 0, 0, 0]
    song[].editTrack(ch1, 0, track):
        track.setEffect(0, 0, etPatternGoto, 1)
    song[].editTrack(ch1, 1, track):
        track.setEffect(0, 0, etPatternGoto, 0xFF)

    engine.play(song.toImmutable)
    engine.step(instruments)
    var frame = engine.currentFrame()
    check frame.order == 0
    engine.step(instruments)
    frame = engine.currentFrame()
    check frame.order == 1 and frame.startedNewPattern
    engine.step(instruments)
    frame = engine.currentFrame()
    check frame.order == 2 and frame.startedNewPattern

dtest "Dxx effect":
    testsetup
    song.speed = unitSpeed
    song.order.insert([0u8, 0, 1, 0], 1)
    song[].editTrack(ch1, 0, track):
        track.setEffect(0, 0, etPatternSkip, 10)
    song[].editTrack(ch3, 1, track):
        track.setEffect(10, 1, etPatternSkip, 32)

    engine.play(song.toImmutable)
    engine.step(instruments)
    var frame = engine.currentFrame()
    check frame.order == 0
    engine.step(instruments)
    frame = engine.currentFrame()
    check:
        frame.order == 1
        frame.row == 10
    engine.step(instruments)
    frame = engine.currentFrame()
    check:
        frame.order == 0
        frame.row == 32

dtest "C00 effect":
    testsetup
    song.speed = unitSpeed
    song[].editTrack(ch1, 0, track):
        track.setEffect(0, 0, etPatternHalt, 0)
    engine.play(song.toImmutable)
    # halt effect occurs here
    engine.step(instruments)
    check not engine.currentFrame().halted
    # halt takes effect before the start of a new row
    engine.step(instruments)
    check engine.currentFrame().halted
    # check that we are still halted after repeated calls to step
    engine.step(instruments)
    check engine.currentFrame().halted

dtest "Fxx effect":
    testsetup
    song[].editTrack(ch1, 0, track):
        track.setEffect(4, 0, etSetTempo, 0x40)
        track.setEffect(5, 0, etSetTempo, 0x02) # invalid speed
        track.setEffect(6, 0, etSetTempo, 0xFF) # invalid speed
    engine.play(song.toImmutable)
    for i in 0..<4:
        engine.stepRow(instruments)
        check engine.currentFrame().speed == defaultSpeed
    engine.stepRow(instruments)
    check engine.currentFrame().speed == 0x40
    engine.stepRow(instruments)
    check engine.currentFrame().speed == 0x40 # speed should be unchanged
    engine.stepRow(instruments)
    check engine.currentFrame().speed == 0x40 # speed should be unchanged

template takeAndCheck(e: var Engine, body: untyped): untyped =
    block:
        let op {.inject.} = e.takeOperation()
        check:
            body

#dtest "V0x effect":
    # testsetup
    # song.speed = unitSpeed
    # song[].editTrack(ch1, 0, track):
    #     track.setEffect(0, 0, etSetTimbre, 0)
    #     track.setEffect(1, 0, etSetTimbre, 1)
    #     track.setEffect(2, 0, etSetTimbre, 2)
    #     track.setEffect(3, 0, etSetTimbre, 3)
    #     track.setEffect(4, 0, etSetTimbre, 4)
    # engine.play(song.toImmutable)
    # engine.step(instruments)
    # takeAndCheck(engine):
    #     op.updates[ch1].flags == {}
    #     op.stateTable[ch1].timbre == 0
    # engine.step(instruments)
    # takeAndCheck(engine):
    #     op.flagTable[ch1] == {ufTimbre}
    #     op.stateTable[ch1].timbre == 1


