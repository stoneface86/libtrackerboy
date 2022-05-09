##
## This module contains data types used in the library.
##

import std/[math, options, parseutils, sequtils, tables]

export options

import common
import version
import private/data

export common

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
    
    EffectColumns* = range[1u8..3u8]
    
    EffectCounts* = array[4, EffectColumns]
        ## Number of effects to display for each channel.

    WaveData* = array[16, uint8]
        ## Waveform data. A waveform consists of 16 bytes, with each byte
        ## containing 2 4-bit PCM samples. The first sample is the upper nibble
        ## of the byte, with the second being the lower nibble.

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
        id: TableId
        name*: string
        channel*: ChannelId
        initEnvelope*: bool
        envelope*: uint8
        sequences*: array[SequenceKind, Sequence]

    Waveform* {.requiresInit.} = object
        ## Container for a waveform to use on CH3.
        id: TableId
        name*: string
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

    SomeTable* = InstrumentTable|WaveformTable

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
        tracks: array[ChannelId, tables.Table[ByteIndex, DeepEqualsRef[Track]]]

    SongList* {.requiresInit.} = object
        ## Container for songs. Songs stored in this container are references,
        ## like InstrumentTable and WaveformTable. A SongList can contain 1-256
        ## songs.
        data: seq[DeepEqualsRef[Song]]

    InfoString* = array[32, char]
        ## Fixed-length string of 32 characters, used for artist information.

    System* = enum
        ## Enumeration for types of systems the module is for. The system
        ## determines the vblank interval, or tick rate, of the engine.
        systemDmg       ## DMG/CGB system, 59.7 Hz
        systemSgb       ## SGB system, 61.1 Hz
        systemCustom    ## Custom tick rate

    ModulePiece* = Instrument|Song|Waveform

    # Module
    Module* {.requiresInit.} = object
        ## A module is a container for songs, instruments and waveforms.
        ## Each module can store up to 256 songs, 64 instruments and 64
        ## waveforms. Instruments and Waveforms are shared between all songs.
        ##
        songs*: SongList
        instruments*: InstrumentTable
        waveforms*: WaveformTable

        title*, artist*, copyright*: InfoString

        comments*: string
        system*: System
        customFramerate*: Framerate

        private*: ModulePrivate

const
    defaultRpb* = 4
    defaultRpm* = 16
    defaultSpeed*: Speed = 0x60
    defaultTrackSize*: TrackSize = 64

func effectTypeShortensPattern*(et: EffectType): bool =
    result = et == etPatternHalt or
             et == etPatternSkip or
             et == etPatternGoto

# Instrument|Waveform

proc id*[T: SomeData](self: T): TableId {.inline.} =
    self.id

# Sequence

proc `[]`*(s: Sequence, i: ByteIndex): uint8 =
    s.data[i]

proc `[]=`*(s: var Sequence, i: ByteIndex, val: uint8) =
    s.data[i] = val

proc setLen*(s: var Sequence, len: SequenceSize) =
    s.data.setLen(len)

func len*(s: Sequence): int =
    s.data.len

func data*(s: Sequence): lent seq[uint8] =
    s.data

proc `data=`*(s: var Sequence, data: sink seq[uint8]) =
    if data.len > 256:
        raise newException(InvalidOperationDefect, "cannot set data: sequence is too big")
    s.data = data

func `$`*(s: Sequence): string =
    ## Stringify operator for Sequences. The string returned can be passed to
    ## `parseSequence` to get the original sequence.
    let loopIndex = if s.loopIndex.isSome(): s.loopIndex.get().int else: -1
    for i, item in s.data.pairs:
        if i == loopIndex:
            result.add("| ")
        result.add($cast[int8](s.data[i]))
        if i != s.data.high:
            result.add(' ')

func parseSequence*(str: string, minVal = int8.low, maxVal = int8.high): Sequence =
    ## Convert a string to a Sequence. The string should have its sequence data
    ## separated by whitespace, with the loop index using a '|' char before the
    ## data to loop to. Any invalid element is ignored.
    var i = 0
    while true:
        i += str.skipWhitespace(i)
        if i >= str.len:
            break
        if str[i] == '|':
            result.loopIndex = some(result.data.len.ByteIndex)
            inc i
        else:
            var data: int
            
            let parsed = str.parseInt(data, i)
            if parsed == 0:
                # skip this character
                inc i
            else:
                i += parsed
                result.data.add(cast[uint8](clamp(data, minVal, maxVal)))

# Instrument

template tInitInstrument[T: Instrument|ref Instrument](): untyped =
    T(
        id: 0,
        name: "",
        channel: ch1,
        initEnvelope: false,
        envelope: 0xF0,
        sequences: default(T.sequences.type)
    )

func initInstrument*(): Instrument =
    result = tInitInstrument[Instrument]()

func newInstrument*(): ref Instrument =
    result = tInitInstrument[ref Instrument]()

# Waveform

template tInitWaveform[T: Waveform|ref Waveform](): untyped =
    T(
        id: 0,
        name: "",
        data: default(T.data.type)
    )

func initWaveform*(): Waveform =
    result = tInitWaveform[Waveform]()

func newWaveform*(): ref Waveform =
    result = tInitWaveform[ref Waveform]()

func `$`*(wave: WaveData): string {.noInit.} =
    const hextable = ['0', '1', '2', '3', '4', '5', '6', '7',
                      '8', '9', 'A', 'B', 'C', 'D', 'E', 'F']
    result = newString(32)
    var i = 0
    for samples in wave:
        result[i] = hextable[samples shr 4]
        inc i
        result[i] = hextable[samples and 0xF]
        inc i

func parseWave*(str: string): WaveData {.noInit.} =
    var start = 0
    for dest in result.mitems:
        let parsed = parseHex(str, dest, start, 2)
        if parsed != 2:
            # clear the rest
            for i in (start div 2)..<result.len:
                result[i] = 0
            break
        start += 2

# Table

func initTable*[T: SomeData](): Table[T] =
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

func `[]`*[T: SomeData](t: Table[T], id: TableId): CRef[T] =
    toCRef(t.data[id])

iterator items*[T: SomeData](t: Table[T]): TableId {.noSideEffect.} =
    ## Iterates all items in the table, via their id, in order.
    for id in low(TableId)..high(TableId):
        if t.data[id] != nil:
            yield id

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

proc len*[T: SomeData](t: Table[T]): int =
    t.size

func nextAvailableId*[T: SomeData](t: Table[T]): TableId =
    t.nextId

func next*[T: SomeData](t: Table[T], start: TableId = 0): Option[TableId] =
    for id in start..high(TableId):
        if t.data[id] != nil:
            return some(id)
    none(TableId)

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

proc len*(o: Order): int =
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

proc setLen*(o: var Order, len: OrderSize) =
    o.data.setLen(len)

proc swap*(o: var Order, i1, i2: ByteIndex) =
    swap(o.data[i1], o.data[i2])

# TrackRow

func queryNote*(row: TrackRow): Option[uint8] =
    if row.note > 0:
        return some(row.note - 1)
    else:
        return none(uint8)

func queryInstrument*(row: TrackRow): Option[uint8] = 
    if row.instrument > 0:
        return some(row.instrument - 1)
    else:
        return none(uint8)

func isEmpty*(row: TrackRow): bool =
    row == default(TrackRow)

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

proc `[]=`*(t: var Track, i: ByteIndex, row: TrackRow) =
    t.data[i] = row

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

func totalRows*(t: Track): int =
    for row in t.data:
        if not row.isEmpty():
            inc result

proc data*(t: Track): lent seq[TrackRow] =
    t.data

proc len*(t: Track): int =
    t.data.len

proc setLen*(t: var Track, size: TrackSize) =
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

proc removeAllTracks*(s: var Song) =
    for tab in s.tracks.mitems:
        tab.clear()

proc speedToFloat*(speed: Speed): float =
    speed.float * (1.0 / (1 shl speedFractionBits))

proc speedToTempo*(speed: float, rowsPerBeat: PositiveByte, framerate: float): float =
    (framerate * 60.0) / (speed * rowsPerBeat.float)

proc getTrack*(s: var Song, ch: ChannelId, order: ByteIndex): ref Track =
    result = s.tracks[ch].getOrDefault(order).data
    if result == nil:
        result = newTrack(s.trackSize)
        s.tracks[ch][order] = deepEqualsRef(result)

proc getTrack*(s: Song, ch: ChannelId, order: ByteIndex): CRef[Track] =
    result = s.tracks[ch].getOrDefault(order).data.toCRef

iterator tracks*(s: Song, ch: ChannelId): (ByteIndex, CRef[Track]) =
    for pair in s.tracks[ch].pairs:
        yield (pair[0], pair[1].data.toCRef)

proc getRow*(s: var Song, ch: ChannelId, order, row: ByteIndex): var TrackRow =
    result = s.getTrack(ch, order)[][row]

proc getRow*(s: Song, ch: ChannelId, order, row: ByteIndex): TrackRow =
    if s.tracks[ch].contains(order):
        result = s.tracks[ch][order].data[][row]
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

func totalTracks*(s: Song): int =
    for t in s.tracks:
        result += t.len

proc trackSize*(s: Song): TrackSize {.inline.} =
    s.trackSize

proc setTrackSize*(s: var Song, size: TrackSize) =
    for table in s.tracks.mitems:
        for track in table.mvalues:
            track.data[].setLen(size)
    s.trackSize = size

proc estimateSpeed*(s: Song, tempo, framerate: float): Speed =
    let speedFloat = speedToTempo(tempo, s.rowsPerBeat, framerate)
    let speed = round(speedFloat * (1 shl speedFractionBits).float).uint8
    result = clamp(speed, low(Speed), high(Speed))

proc tempo*(s: Song, framerate: float): float =
    result = speedToTempo(speedToFloat(s.speed), s.rowsPerBeat, framerate)

# SongList

proc initSongList*(len: PositiveByte = 1): SongList =
    result = SongList(
        data: newSeq[DeepEqualsRef[Song]](len)
    )
    for songref in result.data.mitems:
        songref = deepEqualsRef(newSong())

proc `[]`*(l: var SongList, i: ByteIndex): ref Song =
    l.data[i].data

func `[]`*(l: SongList, i: ByteIndex): CRef[Song] =
    toCRef(l.data[i].data)

proc `[]=`*(l: var SongList, i: ByteIndex, s: ref Song) =
    l.data[i] = deepEqualsRef(s)

proc canAdd(l: SongList) =
    if l.data.len == 256:
        raise newException(InvalidOperationDefect, "SongList cannot have more than 256 songs")

proc add*(l: var SongList) =
    l.canAdd()
    l.data.add(deepEqualsRef(newSong()))

proc add*(l: var SongList, song: ref Song) =
    l.canAdd()
    l.data.add(deepEqualsRef(song))

proc duplicate*(l: var SongList, i: ByteIndex) =
    l.canAdd()
    let src = l.data[i].data
    # gross, but there's no other way to do this :(
    # dest[] = src[] won't work cause we have to init dest first (Song has .requiresInit. pragma)
    # we could init dest first via newSong(), but that's inefficient
    l.data.add(deepEqualsRef((ref Song)(
        name: src.name,
        rowsPerBeat: src.rowsPerBeat,
        rowsPerMeasure: src.rowsPerMeasure,
        speed: src.speed,
        effectCounts: src.effectCounts,
        order: src.order,
        trackSize: src.trackSize,
        tracks: src.tracks
    )))


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
        title: default(InfoString),
        artist: default(InfoString),
        copyright: default(InfoString),
        comments: "",
        system: systemDmg,
        customFramerate: 30,
        private: ModulePrivate(
            version: appVersion,
            revisionMajor: fileMajor,
            revisionMinor: fileMinor
        )
    )

proc initModule*(): Module =
    result = tInitModule(Module)

proc newModule*(): ref Module =
    result = tInitModule(ref Module)

proc version*(m: Module): Version =
    m.private.version

proc revisionMajor*(m: Module): int =
    m.private.revisionMajor

proc revisionMinor*(m: Module): int = 
    m.private.revisionMinor

proc framerate*(m: Module): float =
    case m.system:
    of systemDmg:
        result = 59.7f
    of systemSgb:
        result = 61.1f
    of systemCustom:
        result = m.customFramerate.float

converter toInfoString*(str: string): InfoString =
    for i in 0..<min(str.len, result.len):
        result[i] = str[i]

template initPiece*(T: typedesc[ModulePiece]): T =
    when T is Instrument:
        initInstrument()
    elif T is Song:
        initSong()
    else:
        initWaveform()
