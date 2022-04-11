##
## This module contains data types used in the library.
##

import std/[math, options, sequtils, tables]

export options

import common
import version

const
    speedFractionBits = 4
    unitSpeed* = 1 shl speedFractionBits

type
    TableId* = range[0u8..63u8]
        ## Integer ID type for items in an InstrumentTable or WaveformTable.

    SequenceSize* = range[0..high(uint8).int]
        ## Size range a sequence's data can be.

    OrderSize* = PositiveByte
        ## Size range of a song order.
    
    TrackSize* = PositiveByte
        ## Size range of a Track
    
    TrackId* = uint8
        ## Integer ID type for a Track in a Song.
    
    OrderId* = uint8
        ## Integer ID type for an OrderRow in an Order.
    
    Framerate* = range[1..high(uint16).int]
        ## Range of a Module's custom framerate setting.

    Speed* = range[unitSpeed.uint8..(high(uint8)+1-unitSpeed).uint8]
        ## Range of a Song's speed setting.

    EffectIndex* = range[0..2]
        ## Index type for an Effect in a TrackRow.
    
    EffectColumns* = range[1..3]
    
    EffectCounts* = array[4, EffectColumns]
        ## Number of effects to display for each channel.

    WaveData* = array[16, uint8]
        ## Waveform data. A waveform consists of 16 bytes, with each byte
        ## containing 2 4-bit PCM samples. The first sample is the upper nibble
        ## of the byte, with the second being the lower nibble.

    ItemData = object
        id: TableId
        name: string

    SequenceKind* = enum
        ## Enumeration for the kinds of parameters a sequence can operate on.
        ## An `Instrument` has a `Sequence` for each one of these kinds.
        skArp,
        skPanning,
        skPitch,
        skTimbre

    Sequence* = object
        ## A sequence is a sequence of parameter changes with looping capability.
        loopIndex*: Option[ByteIndex]
            ## If set, the sequence will loop to this index at the end. If unset
            ## or the index exceeds the bounds of the sequence data, the sequence
            ## will stop at the end instead.
        data: seq[uint8]

    Instrument* {.requiresInit.} = object
        item: ItemData
        initEnvelope*: bool
        envelope*: uint8
        sequences*: array[SequenceKind, Sequence]

    Waveform* {.requiresInit.} = object
        ## Container for a waveform to use on CH3.
        item: ItemData
        data*: WaveData

    SomeData* = Instrument|Waveform

    Table[T: SomeData] {.requiresInit.} = object
        nextId: TableId
        size: int
        data: array[TableId, ref T]

    InstrumentTable* = Table[Instrument]
        ## Container for Instruments. Up to 64 Instruments can be stored in this
        ## table and is addressable via a TableId.
    WaveformTable* = Table[Waveform]
        ## Container for Waveforms. Up to 64 Waveforms can be stored in this
        ## table and is addressable via a TableId.

    # song order

    OrderRow* = array[ChannelId, TrackId]
        ## An OrderRow is a set of TrackIds, one for each channel.
    Order* {.requiresInit.} = object
        ## An Order is a sequence of OrderRows, that determine the layout of
        ## a Song. Each Order must have at least 1 OrderRow and no more than
        ## 256 rows.
        data: seq[OrderRow]

    # patterns

    EffectType* = enum
        ## Enumeration for all available effects.
        ## 
        etNoEffect = 0,         ## No effect, this effect column is unset.
        etPatternGoto,          ## `Bxx` begin playing given pattern immediately
        etPatternHalt,          ## `C00` stop playing
        etPatternSkip,          ## `D00` begin playing next pattern immediately
        etSetTempo,             ## `Fxx` set the tempo
        etSfx,                  ## `Txx` play sound effect
        etSetEnvelope,          ## `Exx` set the persistent envelope/wave id setting
        etSetTimbre,            ## `Vxx` set persistent duty/wave volume setting
        etSetPanning,           ## `Ixy` set channel panning setting
        etSetSweep,             ## `Hxx` set the persistent sweep setting (CH1 only)
        etDelayedCut,           ## `Sxx` note cut delayed by xx frames
        etDelayedNote,          ## `Gxx` note trigger delayed by xx frames
        etLock,                 ## `L00` (lock) stop the sound effect on the current channel
        etArpeggio,             ## `0xy` arpeggio with semi tones x and y
        etPitchUp,              ## `1xx` pitch slide up
        etPitchDown,            ## `2xx` pitch slide down
        etAutoPortamento,       ## `3xx` automatic portamento
        etVibrato,              ## `4xy` vibrato
        etVibratoDelay,         ## `5xx` delay vibrato xx frames on note trigger
        etTuning,               ## `Pxx` fine tuning
        etNoteSlideUp,          ## `Qxy` note slide up
        etNoteSlideDown,        ## `Rxy` note slide down
        etSetGlobalVolume       ## `Jxy` set global volume scale

    Effect* {.packed.} = object
        ## Effect column. An effect has a type and a parameter.
        effectType*: uint8
        param*: uint8

    TrackRow* {.packed.} = object
        ## A single row of data in a Track. Guaranteed to be 8 bytes.
        note*: uint8
        instrument*: uint8
        effects*: array[EffectIndex, Effect]

    Track* {.requiresInit.} = object
        ## Pattern data for a single channel, stored in a `seq[TrackRow]`. A
        ## Track can have 1-256 rows.
        data: seq[TrackRow]

    SomeTrackRef = ref Track | CRef[Track]

    GenericPattern[T: SomeTrackRef] {.requiresInit.} = object
        tracks*: array[ChannelId, T]

    Pattern* = GenericPattern[ref Track]
    # Pattern with immutable access
    CPattern* = GenericPattern[CRef[Track]]

    # Song

    Song* {.requiresInit.} = object
        ## Song type. Contains track data for a single song.
        ##
        name*: string
        rowsPerBeat*: PositiveByte
        rowsPerMeasure*: PositiveByte
        speed*: Speed
        effectCounts*: array[4, EffectColumns]
        order*: Order
        trackSize: TrackSize
        # ref Track is used since Table doesn't provide a view return for
        # accessing, resulting in a wasteful copy
        tracks: array[ChannelId, tables.Table[ByteIndex, ref Track]]

    SongList* {.requiresInit.} = object
        ## Container for songs. Songs stored in this container are references,
        ## like InstrumentTable and WaveformTable. A SongList can contain 1-256
        ## songs.
        data: seq[ref Song]

    InfoString* = array[32, char]
        ## Fixed-length string of 32 characters, used for artist information.

    System* = enum
        ## Enumeration for types of systems the module is for. The system
        ## determines the vblank interval, or tick rate, of the engine.
        SystemDmg,      ## DMG/CGB system, 59.7 Hz
        SystemSgb,      ## SGB system, 61.1 Hz
        SystemCustom    ## Custom tick rate

    # Module
    Module* {.requiresInit.} = object
        ## A module is a container for songs, instruments and waveforms.
        ## Each module can store up to 256 songs, 64 instruments and 64
        ## waveforms. Instruments and Waveforms are shared between all songs.
        ##
        songs*: SongList
        instruments*: InstrumentTable
        waveforms*: WaveformTable

        version: Version
        revisionMajor: int
        revisionMinor: int

        title*, artist*, copyright*: InfoString

        comments*: string
        system*: System
        customFramerate*: Framerate

    

const
    defaultRpb* = 4
    defaultRpm* = 16
    defaultSpeed*: Speed = 0x60
    defaultTrackSize*: TrackSize = 64

func effectTypeShortensPattern*(et: EffectType): bool =
    result = et == etPatternHalt or
             et == etPatternSkip or
             et == etPatternGoto

# ItemData

func initItemData(): ItemData =
    result = ItemData(
        id: 0,
        name: ""
    )

proc `id=`*[T: SomeData](self: var T, value: TableId) {.inline.} =
    self.item.id = value

proc id*[T: SomeData](self: T): TableId {.inline.} =
    self.item.id

proc `name=`*[T: SomeData](self: var T, value: string) {.inline.} =
    self.item.name = value

proc name*[T: SomeData](self: T): lent string {.inline.} =
    self.item.name

# Sequence

proc `[]`*(s: Sequence, i: ByteIndex): uint8 =
    s.data[i]

proc `[]=`*(s: var Sequence, i: ByteIndex, val: uint8) =
    s.data[i] = val

proc setLen*(s: var Sequence, len: SequenceSize) =
    s.data.setLen(len)

proc data*(s: Sequence): lent seq[uint8] =
    s.data

proc `data=`*(s: var Sequence, data: sink seq[uint8]) =
    if data.len > 256:
        raise newException(InvalidOperationDefect, "cannot set data: sequence is too big")
    s.data = data

# Instrument

template tInitInstrument[T: Instrument|ref Instrument](): untyped =
    T(
        item: initItemData(),
        initEnvelope: false,
        envelope: 0xF0,
        sequences: default(T.sequences.type)
    )

proc initInstrument*(): Instrument =
    result = tInitInstrument[Instrument]()

proc newInstrument*(): ref Instrument =
    result = tInitInstrument[ref Instrument]()

# Waveform

template tInitWaveform[T: Waveform|ref Waveform](): untyped =
    T(
        item: initItemData(),
        data: default(T.data.type)
    )

proc initWaveform*(): Waveform =
    result = tInitWaveform[Waveform]()

proc newWaveform*(): ref Waveform =
    result = tInitWaveform[ref Waveform]()

proc fromString*(w: var WaveData, str: sink string) =
    proc toHex(ch: char): uint8 =
        if ch >= 'A':
            result = (ord(ch) - ord('A')).uint8
        else:
            result = (ord(ch) - ord('0')).uint8

    assert str.len == 32
    var index = 0
    for sample in w.mitems:
        var result = toHex(str[index]) shl 4
        inc index
        result = result or toHex(str[index])
        inc index
        sample = result

# Table

proc initTable*[T: SomeData](): Table[T] =
    result = Table[T](
        nextId: 0,
        size: 0,
        data: default(Table[T].data)
    )

proc updateNextId[T: SomeData](t: var Table[T]) =
    for i in t.nextId..high(TableId):
        if t.data[i] == nil:
            t.nextId = i
            break

proc capacity*[T: SomeData](t: Table[T]): static[int] =
    high(TableId).int + 1

proc `[]`*[T: SomeData](t: var Table[T], id: TableId): ref T =
    t.data[id]

proc `[]`*[T: SomeData](t: Table[T], id: TableId): CRef[T] =
    toCRef(t.data[id])

proc insert[T: SomeData](t: var Table[T], id: TableId) =
    t.data[id] = when T is Instrument:
        newInstrument()
    else:
        newWaveform()
    t.data[id][].id = id
    inc t.size

proc add*[T: SomeData](t: var Table[T]): TableId =
    assert t.size < t.capacity
    t.insert(t.nextId)
    result = t.nextId
    t.updateNextId()

proc add*[T: SomeData](t: var Table[T], id: TableId) =
    assert t.size < t.capacity and t.data[id] == nil
    t.insert(id)
    if t.nextId == id:
        t.updateNextId()

proc duplicate*[T: SomeData](t: var Table[T], id: TableId): TableId =
    assert t.data[id] != nil
    result = t.add()
    # duplicate the newly added item
    t.data[result][] = t.data[id][]

proc remove*[T: SomeData](t: var Table[T], id: TableId) =
    assert t.data[id] != nil
    t.data[id] = nil
    dec t.size
    if t.nextId > id:
        t.nextId = id

proc size*[T: SomeData](t: Table[T]): int =
    t.size

proc nextAvailableId*[T: SomeData](t: Table[T]): TableId =
    t.nextId

# Order

proc initOrder*(): Order =
    result = Order(
        data: @[[0u8, 0u8, 0u8, 0u8]]
    )

proc `[]`*(o: Order, index: Natural): OrderRow =
    o.data[index]

proc `[]=`*(o: var Order, index: Natural, val: OrderRow) =
    o.data[index] = val

proc data*(o: Order): lent seq[OrderRow] =
    o.data

proc `data=`*(o: var Order, data: sink seq[OrderRow]) =
    assert data.len >= 1
    o.data = data

proc size*(o: Order): int =
    o.data.len

proc nextUnused*(o: Order): OrderRow =
    result = [0u8, 0u8, 0u8, 0u8]
    for track in low(ChannelId)..high(ChannelId):
        var idmap: set[uint8]
        for row in o.data:
            idmap.incl(row[track])
        for id in low(uint8)..high(uint8):
            if not idmap.contains(id):
                result[track] = id
                break

template assertCanInsert(o: Order) =
    assert o.data.len < high(OrderSize)

proc insert*(o: var Order, row: OrderRow, before: ByteIndex = 0) =
    o.assertCanInsert()
    o.data.insert(row, before)

proc insert*(o: var Order, data: openarray[OrderRow], before: ByteIndex) =
    assert o.data.len + data.len <= high(OrderSize)
    o.data.insert(data, before)

proc remove*(o: var Order, index: ByteIndex, count: OrderSize = 1) =
    assert o.data.len > count
    o.data.delete(index.int..(index + count - 1))

proc resize*(o: var Order, size: OrderSize) =
    o.data.setLen(size)

proc swap*(o: var Order, i1, i2: ByteIndex) =
    swap(o.data[i1], o.data[i2])

# TrackRow

proc queryNote*(row: TrackRow): Option[uint8] =
    if row.note > 0:
        return some(row.note - 1)
    else:
        return none(uint8)

proc queryInstrument*(row: TrackRow): Option[uint8] = 
    if row.instrument > 0:
        return some(row.instrument - 1)
    else:
        return none(uint8)

# Track

template tInitTrack[T](size: TrackSize): untyped =
    T(data: newSeq[TrackRow](size))

proc initTrack*(size: TrackSize): Track =
    result = tInitTrack[Track](size)

proc newTrack*(size: TrackSize): ref Track =
    result = tInitTrack[ref Track](size)

iterator items*(t: Track): lent TrackRow =
    for row in t.data:
        yield row

iterator items*(t: Track, slice: Slice[ByteIndex]): lent TrackRow =
    for row in slice:
        yield t.data[row]

iterator mitems*(t: var Track): var TrackRow =
    for row in t.data.mitems:
        yield row

iterator mitems*(t: var Track, slice: Slice[ByteIndex]): var TrackRow =
    for row in slice:
        yield t.data[row]

proc `[]`*(t: var Track, i: ByteIndex): var TrackRow =
    t.data[i]

proc `[]`*(t: Track, i: ByteIndex): TrackRow =
    t.data[i]

proc setNote*(t: var Track, i: ByteIndex, note: uint8) =
    t.data[i].note = note + 1

proc setInstrument*(t: var Track, i: ByteIndex, instrument: TableId) =
    t.data[i].instrument = instrument + 1

proc setEffect*(t: var Track, i: ByteIndex, effectNo: EffectIndex, et: EffectType, param = 0u8) =
    t.data[i].effects[effectNo] = Effect(effectType: et.uint8, param: param)

proc setEffectType*(t: var Track, i: ByteIndex, effectNo: EffectIndex, et: EffectType) =
    t.data[i].effects[effectNo].effectType = et.uint8

proc setEffectParam*(t: var Track, i: ByteIndex, effectNo: EffectIndex, param: uint8) =
    t.data[i].effects[effectNo].param = param

proc data*(t: Track): lent seq[TrackRow] =
    t.data

proc len*(t: Track): int =
    t.data.len

proc resize*(t: var Track, size: TrackSize) =
    t.data.setLen(size)

# Pattern

func toCPattern*(p: sink Pattern): CPattern =
    result = CPattern(
        tracks: [p.tracks[0].toCRef, p.tracks[1].toCRef, p.tracks[2].toCRef, p.tracks[3].toCRef]
    )

func clone*(p: CPattern): Pattern =
    template cloneTrack(t: Track): ref Track =
        (ref Track)(data: t.data)
    result = Pattern(tracks: [
        cloneTrack(p.tracks[0][]),
        cloneTrack(p.tracks[1][]),
        cloneTrack(p.tracks[2][]),
        cloneTrack(p.tracks[3][])
    ])

func rowsWhenRun*(p: CPattern): Natural =
    for i in 0..p.tracks[0][].len-1:
        inc result
        for track in p.tracks:
            let row = track[][i]
            for effect in row.effects:
                if effectTypeShortensPattern(effect.effectType.EffectType):
                    return

# Song

template tInitSong[T: Song|ref Song](): untyped =
    T(
        name: "",
        rowsPerBeat: defaultRpb,
        rowsPerMeasure: defaultRpm,
        speed: defaultSpeed,
        effectCounts: [2.EffectColumns, 2, 2, 2],
        order: initOrder(),
        trackSize: defaultTrackSize,
        tracks: default(T.tracks.type)
    )

proc initSong*(): Song =
    result = tInitSong[Song]()

proc newSong*(): ref Song =
    result = tInitSong[ref Song]()

proc speedToFloat*(speed: Speed): float =
    speed.float * (1.0 / (1 shl speedFractionBits))

proc speedToTempo*(speed: float, rowsPerBeat: PositiveByte, framerate: float): float =
    (framerate * 60.0) / (speed * rowsPerBeat.float)

proc getTrack*(s: var Song, ch: ChannelId, order: ByteIndex): ref Track =
    result = s.tracks[ch].getOrDefault(order)
    if result == nil:
        result = newTrack(s.trackSize)
        s.tracks[ch][order] = result

proc getTrack*(s: Song, ch: ChannelId, order: ByteIndex): CRef[Track] =
    result = s.tracks[ch].getOrDefault(order).toCRef

proc getRow*(s: var Song, ch: ChannelId, order, row: ByteIndex): var TrackRow =
    result = s.getTrack(ch, order)[][row]

proc getRow*(s: Song, ch: ChannelId, order, row: ByteIndex): TrackRow =
    if s.tracks[ch].contains(order):
        result = s.tracks[ch][order][][row]
    else:
        result = TrackRow()

proc getPattern*(s: var Song, order: ByteIndex): Pattern =
    result = Pattern(tracks: [
        s.getTrack(0, order),
        s.getTrack(1, order),
        s.getTrack(2, order),
        s.getTrack(3, order)
        ]
    )

proc getPattern*(s: Song, order: ByteIndex): CPattern =
    result = CPattern(tracks: [
        s.getTrack(0, order),
        s.getTrack(1, order),
        s.getTrack(2, order),
        s.getTrack(3, order)
        ]
    )

proc trackSize*(s: Song): TrackSize {.inline.} =
    s.trackSize

proc setTrackSize*(s: var Song, size: TrackSize) =
    for table in s.tracks.mitems:
        for track in table.mvalues:
            track[].resize(size)
    s.trackSize = size

proc estimateSpeed*(s: Song, tempo, framerate: float): Speed =
    let speedFloat = speedToTempo(tempo, s.rowsPerBeat, framerate)
    let speed = round(speedFloat * (1 shl speedFractionBits).float).uint8
    result = clamp(speed, low(Speed), high(Speed))

proc tempo*(s: Song, framerate: float): float =
    result = speedToTempo(speedToFloat(s.speed), s.rowsPerBeat, framerate)

# SongList

proc initSongList*(): SongList =
    result = SongList(
        data: newSeq[ref Song](1)
    )
    result.data[0] = newSong()

proc `[]`*(l: var SongList, i: ByteIndex): ref Song =
    l.data[i]

func `[]`*(l: SongList, i: ByteIndex): CRef[Song] =
    toCRef(l.data[i])

proc `[]=`*(l: var SongList, i: ByteIndex, s: ref Song) =
    l.data[i] = s

proc canAdd(l: SongList) =
    if l.data.len == 256:
        raise newException(InvalidOperationDefect, "SongList cannot have more than 256 songs")

proc add*(l: var SongList) =
    l.canAdd()
    l.data.add(newSong())

proc add*(l: var SongList, song: ref Song) =
    l.canAdd()
    l.data.add(song)

proc duplicate*(l: var SongList, i: ByteIndex) =
    l.canAdd()
    let src = l.data[i]
    # gross, but there's no other way to do this :(
    # dest[] = src[] won't work cause we have to init dest first (Song has .requiresInit. pragma)
    # we could init dest first via newSong(), but that's inefficient
    l.data.add((ref Song)(
        name: src.name,
        rowsPerBeat: src.rowsPerBeat,
        rowsPerMeasure: src.rowsPerMeasure,
        speed: src.speed,
        effectCounts: src.effectCounts,
        order: src.order,
        trackSize: src.trackSize,
        tracks: src.tracks
    ))


proc remove*(l: var SongList, i: ByteIndex) =
    if l.data.len == 1:
        raise newException(InvalidOperationDefect, "SongList must have at least 1 song")
    l.data.delete(i)

proc moveUp*(l: var SongList, i: ByteIndex) =
    if i == 0:
        raise newException(IndexDefect, "cannot move topmost item up")
    swap(l.data[i], l.data[i - 1])

proc moveDown*(l: var SongList, i: ByteIndex) =
    if i == l.data.len - 1:
        raise newException(IndexDefect, "cannot move bottomost item down")
    swap(l.data[i], l.data[i + 1])

proc len*(l: SongList): Natural =
    l.data.len

# Module

template tInitModule(T: typedesc[Module|ref Module]): untyped =
    T(
        songs: initSongList(),
        instruments: initTable[Instrument](),
        waveforms: initTable[Waveform](),
        version: appVersion,
        revisionMajor: fileMajor,
        revisionMinor: fileMinor,
        title: default(InfoString),
        artist: default(InfoString),
        copyright: default(InfoString),
        comments: "",
        system: SystemDmg,
        customFramerate: 30
    )

proc initModule*(): Module =
    result = tInitModule(Module)

proc newModule*(): ref Module =
    result = tInitModule(ref Module)

proc version*(m: Module): Version =
    m.version

proc revisionMajor*(m: Module): int =
    m.revisionMajor

proc revisionMinor*(m: Module): int = 
    m.revisionMinor

proc framerate*(m: Module): float =
    case m.system:
    of SystemDmg:
        result = 59.7f
    of SystemSgb:
        result = 61.1f
    of SystemCustom:
        result = m.customFramerate.float
