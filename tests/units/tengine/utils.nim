
import libtrackerboy/[data, engine]
import libtrackerboy/private/enginestate

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

template mkUpdates*(up1 = ChannelUpdate(); up2 = ChannelUpdate();
                    up3 = ChannelUpdate(); up4 = ChannelUpdate()
                   ): array[ChannelId, ChannelUpdate] =
  [up1, up2, up3, up4]

template mkOperation*(u: array[ChannelId, ChannelUpdate], s = none(uint8), v = none(uint8)): ApuOperation =
  ApuOperation(
    updates: u,
    sweep: s,
    volume: v
  )

proc stepRow*(engine: var Engine, instruments: InstrumentTable) =
  while true:
    engine.step(instruments)
    if engine.currentFrame().startedNewRow:
      break

type
  EngineHarness* = object
    engine*: Engine
    instruments*: InstrumentTable
    song*: ref Song
  

func init*(T: typedesc[EngineHarness]): EngineHarness =
  result = EngineHarness(
    engine: Engine.init(),
    instruments: InstrumentTable.init(),
    song: Song.new()
  )



proc play*(e: var EngineHarness; order = 0; row = 0) =
  e.engine.play(e.song.toImmutable, order, row)

func currentState*(e: EngineHarness, chno: ChannelId): ChannelState =
  e.engine.currentState(chno)

func currentFrame*(e: EngineHarness): EngineFrame =
  e.engine.currentFrame()

func currentFrequency*(e: EngineHarness, chno: ChannelId): uint16 =
  e.currentState(chno).frequency

func currentNote*(e: EngineHarness, chno: ChannelId): int =
  e.engine.currentNote(chno)

proc step*(e: var EngineHarness) =
  e.engine.step(e.instruments)

proc stepRow*(e: var EngineHarness) =
  while true:
    e.step()
    if e.currentFrame().startedNewRow:
      break

proc frequencyTest*(e: var EngineHarness, chno: ChannelId): uint16 =
  e.step()
  result = e.currentFrequency(chno)

proc noteTest*(e: var EngineHarness, chno: ChannelId): int =
  e.step()
  result = e.currentNote(chno)

proc panningTest*(e: var EngineHarness, chno: ChannelId): tuple[track, state: uint8] =
  e.step()
  result = (
    e.engine.getTrackPanning(chno),
    e.currentState(chno).panning
  )

proc timbreTest*(e: var EngineHarness, chno: ChannelId): tuple[track, state: uint8] =
  e.step()
  result = (
    e.engine.getTrackTimbre(chno),
    e.currentState(chno).timbre
  )

proc envelopeTest*(e: var EngineHarness, chno: ChannelId): tuple[track: uint8, state: uint16] =
  e.step()
  result = (
    e.engine.getTrackEnvelope(chno),
    e.currentState(chno).envelope
  )

template setupSong*(e: var EngineHarness, songVar, body: untyped) =
  template songVar(): var Song =
    e.song[]
  body

template setupInstruments*(e: var EngineHarness, instrumentsVar, body: untyped) =
  template instrumentsVar(): var InstrumentTable =
    e.instruments
  body

template forCurrentFrame*(e: EngineHarness, frameVar, body: untyped) =
  ## Sets `frameVar` to the engine's current frame for checking.
  block:
    let frameVar {.inject.} = e.currentFrame()
    body

template frameTest*(e: var EngineHarness, frameVar, body: untyped) =
  ## Utility template combines e.step() and e.forCurrentFrame(frameVar, body)
  e.step()
  forCurrentFrame(e, frameVar):
    body

