##
## This module contains data types used in the library.
##

import std/[options, sequtils, tables]

const
    speedFractionBits = 4
    unitSpeed = 1 shl speedFractionBits

type
    TableId* = range[0u8..63u8]
    ChannelId* = range[0u8..3u8]
    SequenceSize* = range[0..high(uint8).int+1]
    ByteIndex* = range[0..high(uint8).int]
    PositiveByte = range[1..high(uint8).int+1]
    OrderSize* = PositiveByte
    TrackSize* = PositiveByte
    TrackId* = uint8
    OrderId* = uint8

    Speed* = range[unitSpeed.uint8..(high(uint8)+1-unitSpeed).uint8]

    EffectIndex* = range[0..2]
    EffectColumns* = range[1..3]
    EffectCounts* = array[4, EffectColumns]

    WaveData* = array[16, uint8]

    ItemData = object
        id: TableId
        name: string

    SequenceKind* {.pure.} = enum
        ## sequence kinds
        arp,
        panning,
        pitch,
        timbre

    Sequence* = object
        ## A sequence is a sequence of parameter changes with looping capability
        loopIndex: Option[uint8]
        data: seq[uint8]

    Instrument* = object
        item: ItemData
        initEnvelope: bool
        envelope: uint8
        sequences: array[SequenceKind, Sequence]

    Waveform* = object
        item: ItemData
        data: WaveData

    SomeData* = Instrument|Waveform

    Table[T: SomeData] {.requiresInit.} = object
        nextId: TableId
        size: int
        data: array[TableId, ref T]

    InstrumentTable* = Table[Instrument]
    WaveformTable* = Table[Waveform]

    # song order

    OrderRow* = array[ChannelId, uint8]
    Order* {.requiresInit.} = object
        data: seq[OrderRow]

    # patterns

    EffectType* {.pure.} = enum
        noEffect = 0,
        # pattern effect
        patternGoto,                            #   Bxx begin playing given pattern immediately
        patternHalt,                            #   C00 stop playing
        patternSkip,                            #   D00 begin playing next pattern immediately
        setTempo,                               #   Fxx set the tempo
        sfx,                                    # * Txx play sound effect
        # track effect
        setEnvelope,                            #   Exx set the persistent envelope/wave id setting
        setTimbre,                              #   Vxx set persistent duty/wave volume setting
        setPanning,                             #   Ixy set channel panning setting
        setSweep,                               #   Hxx set the persistent sweep setting (CH1 only)
        delayedCut,                             #   Sxx note cut delayed by xx frames
        delayedNote,                            #   Gxx note trigger delayed by xx frames
        lock,                                   #   L00 (lock) stop the sound effect on the current channel
        # frequency effect
        arpeggio,                               # * 0xy arpeggio with semi tones x and y
        pitchUp,                                # * 1xx pitch slide up
        pitchDown,                              # * 2xx pitch slide down
        autoPortamento,                         # * 3xx automatic portamento
        vibrato,                                # * 4xy vibrato
        vibratoDelay,                           #   5xx delay vibrato xx frames on note trigger
        tuning,                                 #   Pxx fine tuning
        noteSlideUp,                            # * Qxy note slide up
        noteSlideDown                           # * Rxy note slide down

    Effect* {.packed.} = object
        effectType*: uint8
        param*: uint8

    TrackRow* {.packed.} = object
        note*: uint8
        instrument*: uint8
        effects*: array[EffectIndex, Effect]

    Track* = object
        data: seq[TrackRow]

    # Song

    Song* {.requiresInit.} = object
        name*: string
        rowsPerBeat*: PositiveByte
        rowsPerMeasure*: PositiveByte
        speed*: Speed
        effectCounts*: array[4, EffectColumns]
        order*: Order
        trackSize: TrackSize
        tracks: array[ChannelId, tables.Table[ByteIndex, Track]]

    InvalidOperationDefect* = object of Defect

    SongList* {.requiresInit.} = object
        data: seq[ref Song]

    Version* = object
        major*: Natural
        minor*: Natural
        patch*: Natural

    InfoString* = array[32, char]

    System* = enum
        SystemDmg,
        SystemSgb,
        SystemCustom

    Framerate = object
        case system: System
        of SystemDmg:
            discard
        of SystemSgb:
            discard
        of SystemCustom:
            custom: int

    # Module
    Module* {.requiresInit.} = object
        songs*: SongList
        instruments*: InstrumentTable
        waveforms*: WaveformTable

        version: Version
        revisionMajor: int
        revisionMinor: int

        title*, artist*, copyright*: InfoString

        comments*: string
        framerate: Framerate

    # PatternCursor
    # PatternCursor = object
    #     row*: ByteIndex
    #     track: ChannelId
    #     column

const
    defaultRpb* = 4
    defaultRpm* = 16
    defaultSpeed*: Speed = 0x60
    defaultTrackSize*: TrackSize = 64

# ItemData

proc initItemData(): ItemData =
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

# Instrument

proc initInstrument*(): Instrument =
    result = Instrument(
        item: initItemData(),
        initEnvelope: false,
        envelope: 0xF0,
    )

proc newInstrument*(): ref Instrument =
    result = new(Instrument)
    result[] = initInstrument()

proc `initEnvelope=`*(i: var Instrument, val: bool) =
    i.initEnvelope = val

proc initEnvelope*(i: Instrument): bool =
    i.initEnvelope

proc `envelope=`*(i: var Instrument, envelope: uint8) =
    i.envelope = envelope

proc `envelope`*(i: Instrument): uint8 =
    i.envelope

proc `[]`*(i: var Instrument, kind: SequenceKind): var Sequence =
    i.sequences[kind]

proc `[]`*(i: Instrument, kind: SequenceKind): lent Sequence =
    i.sequences[kind]


# Waveform

proc initWaveform*(): Waveform =
    result = Waveform(
        item: initItemData()
    )

proc newWaveform*(): ref Waveform =
    result = new(Waveform)
    result[] = initWaveform()

proc `[]=`* (w: var Waveform, i: int, val: uint8) {.inline.} =
    w.data[i] = val

proc `[]`* (w: Waveform, i: int): uint8 {.inline.} =
    w.data[i]

proc `data=`* (self: var Waveform, value: WaveData) {.inline.} =
    self.data = value

proc `data=`*(w: var Waveform, str: sink string) =
    proc toHex(ch: char): uint8 =
        if ch >= 'A':
            result = (ord(ch) - ord('A')).uint8
        else:
            result = (ord(ch) - ord('0')).uint8

    assert str.len == 32
    var index = 0
    for sample in w.data.mitems:
        var result = toHex(str[index]) shl 4
        inc index
        result = result or toHex(str[index])
        inc index
        sample = result

proc data* (self: Waveform): WaveData {.inline.} =
    self.data

# Sequence

proc `[]`*(s: Sequence, index: ByteIndex): uint8 =
    s.data[index]

proc `[]=`*(s: var Sequence, index: ByteIndex, val: uint8) =
    s.data[index] = val

proc `loopIndex=`* (self: var Sequence, value: Option[uint8]) {.inline.} =
    self.loopIndex = value

proc loopIndex* (self: Sequence): Option[uint8] {.inline.} =
    self.loopIndex

proc `data`*(s: Sequence): lent seq[uint8] =
    s.data

proc `data`*(s: var Sequence): var seq[uint8] =
    s.data

proc `data=`*(s: var Sequence, val: seq[uint8]) =
    s.data = val

proc setLen*(s: var Sequence, len: SequenceSize) =
    s.data.setLen(len)

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

proc `[]`*[T: SomeData](t: Table[T], id: TableId): ref T =
    t.data[id]

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

proc initTrack*(size: TrackSize): Track =
    result = Track(
        data: newSeq[TrackRow](size)
    )

proc `[]`*(t: var Track, i: ByteIndex): var TrackRow =
    t.data[i]

proc `[]`*(t: Track, i: ByteIndex): TrackRow =
    t.data[i]

proc data*(t: Track): lent seq[TrackRow] =
    t.data

proc len*(t: Track): int =
    t.data.len

proc resize*(t: var Track, size: TrackSize) =
    t.data.setLen(size)

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

proc getRow*(s: var Song, ch: ChannelId, order, row: ByteIndex): var TrackRow =
    if not s.tracks[ch].contains(order):
        s.tracks[ch][order] = initTrack(s.trackSize)
    result = s.tracks[ch][order][row]

proc getRow*(s: Song, ch: ChannelId, order, row: ByteIndex): TrackRow =
    if s.tracks[ch].contains(order):
        result = s.tracks[ch][order][row]
    else:
        result = TrackRow()

proc speedToFloat*(speed: Speed): float =
    speed.float * (1.0 / (1 shl speedFractionBits))

proc speedToTempo*(speed: float, rowsPerBeat: PositiveByte, framerate: float): float =
    (framerate * 60.0) / (speed * rowsPerBeat.float)

proc effectTypeShortensPattern*(et: EffectType): bool =
    result = et == EffectType.patternHalt or
             et == EffectType.patternSkip or
             et == EffectType.patternGoto

proc estimateSpeed*(tempo, framerate: float): Speed =
    16

proc tempo*(s: Song, framerate: float): float =
    result = speedToTempo(speedToFloat(s.speed), s.rowsPerBeat, framerate)

# SongList

proc initSongList*(): SongList =
    result = SongList(
        data: newSeq[ref Song](1)
    )
    result.data[0] = newSong()

proc canAdd(l: SongList) =
    if l.data.len == 256:
        raise newException(InvalidOperationDefect, "SongList cannot have more than 256 songs")

proc add*(l: var SongList) =
    l.canAdd()
    l.data.add(newSong())

proc duplicate*(l: var SongList, i: ByteIndex) =
    l.canAdd()
    var dupe: ref Song
    new(dupe)
    dupe[] = l.data[i][]
    l.data.add(dupe)

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
        raise newException(IndexDefect, "cannot move bottomost item up")
    swap(l.data[i], l.data[i + 1])

proc len*(l: var SongList): Natural =
    l.data.len

# Module

proc initModule*(): Module =
    result = Module(
        songs: initSongList(),
        instruments: initTable[Instrument](),
        waveforms: initTable[Waveform](),
        version: Version(major: 0, minor: 0, patch: 0),
        revisionMajor: 0,
        revisionMinor: 0,
        title: default(InfoString),
        artist: default(InfoString),
        copyright: default(InfoString),
        comments: "",
        framerate: Framerate(system: SystemDmg)
    )

proc version*(m: Module): Version =
    m.version

proc revisionMajor*(m: Module): int =
    m.revisionMajor

proc revisionMinor*(m: Module): int = 
    m.revisionMinor

proc system*(m: Module): System =
    m.framerate.system

proc framerate*(m: Module): float =
    case m.framerate.system:
    of SystemDmg:
        result = 59.7f
    of SystemSgb:
        result = 61.1f
    of SystemCustom:
        result = m.framerate.custom.float

