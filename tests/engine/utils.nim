
import trackerboy/[data, engine]
import trackerboy/private/enginestate

export data, engine

func getSampleTable*(): WaveformTable =
    result = WaveformTable.init
    let id = result.add()
    result[id][].data = "0123456789ABCDEFFEDCBA9876543210".parseWave

func `==`*(a, b: ChannelUpdate): bool =
    if a.action == b.action:
        if a.action == caUpdate:
            return a.state == b.state and a.flags == b.flags and a.trigger == b.trigger
        else:
            return true

# shortcut constructors

template mkState*(f = 0u16, e = 0u16, t = 0u8, p = 0u8): ChannelState =
    ChannelState(
        frequency: f,
        envelope: e,
        timbre: t,
        panning: p
    )

template mkCut*(): ChannelUpdate =
    ChannelUpdate(action: caCut)

template mkShutdown*(): ChannelUpdate =
    ChannelUpdate(action: caShutdown)

template mkUpdate*(s = ChannelState(), f: UpdateFlags = {}, t = false): ChannelUpdate =
    ChannelUpdate(
        action: caUpdate,
        state: s,
        flags: f,
        trigger: t
    )

template mkUpdates*(up1, up2, up3, up4 = ChannelUpdate()): array[ChannelId, ChannelUpdate] =
    [up1, up2, up3, up4]

template mkOperation*(u: array[ChannelId, ChannelUpdate], s = none(uint8), v = none(uint8)): ApuOperation =
    ApuOperation(
        updates: u,
        sweep: s,
        volume: v
    )

# the suite setup template doesn't seem to work, nim complains that
# the variables are global and not GC-safe
template testsetup*(): untyped {.dirty.} =
    # var apu: DumbApu
    # var module = Module.new()
    var engine = Engine.init()
    let song = Song.new()
    var instruments = InstrumentTable.init()
    #apu.writes.setLen(0)
    #engine.module = module.toImmutable()

proc stepRow*(engine: var Engine, instruments: InstrumentTable) =
    while true:
        engine.step(instruments)
        if engine.currentFrame().startedNewRow:
            break
