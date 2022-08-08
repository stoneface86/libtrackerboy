
import ../apu, ../engine, ../private/wavwriter

import std/[os, strformat]

type

    WavConfig* = object
        song*: Natural
        filename*: string
        samplerate*: Natural
        channels*: set[ChannelId]
        progressBeginCallback*: proc(): int
            ## Callback returning the upper bound of the progress value
        progressCallback*: proc(): int
            ## Callback returning the current progress value. The value returned
            ## is a measure of the total progress of the export, and can be
            ## used for updating a progress bar widget.

    WavExporter* = object
        apu: Apu
        engine: Engine
        writer: WavWriter
        channels*: set[ChannelId]

func init*(T: typedesc[WavConfig]): T.typeOf =
    T(
        samplerate: 44100,
        channels: {ch1..ch4}
    )

proc exportWav*(module: Module, config: WavConfig): bool =
    discard

proc batched*(config: WavConfig): seq[WavConfig] =
    let (dir, name, ext) = splitFile(config.filename)
    for ch in config.channels:
        var batch = config
        batch.channels = {ch}
        batch.filename = dir / &"{name}.ch{ch.ord + 1}.{ext}"
        result.add(batch)