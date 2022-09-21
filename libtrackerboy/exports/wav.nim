
import ../apu, ../engine, ../private/[player, wavwriter]

import std/[os, strformat]

type

    DurationKind* = enum
        dkSeconds
        dkLoops
    
    Duration* = object
        kind*: DurationKind
        amount*: Natural

    WavConfig* = object
        song*: Natural
        duration*: Duration
        filename*: string
        samplerate*: Natural
        channels*: set[ChannelId]

    WavExporter* = object
        apu: Apu
        engine: Engine
        writer: WavWriter
        player: Player
        buf: seq[Pcm]

func init*(_: typedesc[WavConfig]): WavConfig =
    WavConfig(
        samplerate: 44100,
        channels: {ch1..ch4},
        duration: Duration(kind: dkSeconds, amount: 60)
    )

proc init*(_: typedesc[WavExporter], module: Module, config: WavConfig): WavExporter =
    proc init(_: typedesc[Player], module: Module, config: WavConfig): Player =
        case config.duration.kind:
        of dkSeconds:
            Player.init(module.framerate, config.duration.amount)
        of dkLoops:
            Player.init(module.songs[config.song], config.duration.amount)
    
    result = WavExporter(
        apu: Apu.init(config.samplerate, module.framerate),
        engine: Engine.init(),
        writer: WavWriter.init(config.filename, 2, config.samplerate),
        player: Player.init(module, config),
        buf: newSeq[Pcm]()
    )
    result.engine.play(module.songs[config.song])
    result.apu.setup()
    for ch in ChannelId:
        if ch in config.channels:
            result.engine.lock(ch)
        else:
            result.engine.unlock(ch)


func hasWork*(ex: WavExporter): bool =
    ex.player.isPlaying

proc process*(ex: var WavExporter, module: Module) =
    if ex.player.isPlaying:
        discard ex.player.step(ex.engine, module.instruments)
        ex.apu.apply(ex.engine.takeOperation(), module.waveforms)
        ex.apu.runToFrame()
        ex.apu.takeSamples(ex.buf)
        ex.writer.write(ex.buf)

func progress*(ex: WavExporter): int =
    ex.player.progress

func progressMax*(ex: WavExporter): int =
    ex.player.progressMax

proc batched*(config: WavConfig): seq[WavConfig] =
    let (dir, name, ext) = splitFile(config.filename)
    for ch in config.channels:
        var batch = config
        batch.channels = {ch}
        batch.filename = dir / &"{name}.ch{ch.ord + 1}.{ext}"
        result.add(batch)

proc exportWav*(module: Module, config: WavConfig): bool =
    var ex = WavExporter.init(module, config)
    while ex.hasWork():
        ex.process(module)
        #if not ex.process(module):
            #return false
    result = true
