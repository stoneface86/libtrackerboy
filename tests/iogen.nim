
import trackerboy/[data, io]
import std/[os, streams]

when isMainModule:

    var module = initModule()

    var id = module.instruments.add()
    block:
        let inst = module.instruments[id]
        inst[].name = "main 1"
        inst.initEnvelope = true
        inst.envelope = 0x57
        inst.sequences[skTimbre].data = @[1u8]
    id = module.instruments.add()
    block:
        let inst = module.instruments[id]
        inst[].name = "main 2"
        inst.initEnvelope = true
        inst.envelope = 0x77
        inst.sequences[skTimbre].data = @[0u8]

    id = module.waveforms.add()
    block:
        let wave = module.waveforms[id]
        wave[].name = "triangle"
        wave.data = parseWave("0123456789ABCDEFFEDCBA9876543210")

    block:
        let song = module.songs[0]
        song.name = "rushing heart"
        song.speed = 0x22
        song.order.insert([0u8, 1, 0, 1])
        song.order.insert([0u8, 0, 0, 0])
        song.order.insert([0u8, 2, 0, 2])

    let outDir = getAppDir().joinPath("example-modules")
    outDir.createDir()

    # save the module
    block:
        var stream = newFileStream(outDir.joinPath("sample.tbm"), fmWrite)
        if module.serialize(stream) != frNone:
            echo "failed to serialize module"
            quit(1)
    
    for id in module.instruments:
        let inst = module.instruments[id]
        var stream = newFileStream(outDir.joinPath(inst[].name & ".tbi"), fmWrite)
        if inst[].serialize(stream) != frNone:
            echo "failed to serialize instrument"
            quit(1)

    for id in module.waveforms:
        let wave = module.waveforms[id]
        var stream = newFileStream(outDir.joinPath(wave[].name & ".tbw"), fmWrite)
        if wave[].serialize(stream) != frNone:
            echo "failed to serialize waveform"
            quit(1)

