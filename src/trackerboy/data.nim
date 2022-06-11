##[

Module for the data model. This module contains data types used in the library.

]##

import common, private/data, version 
export common

import std/[math, options, parseutils, sequtils, tables]
export options

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
    
    TrackLen* = PositiveByte
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

    Instrument* = object
        name*: string
        channel*: ChannelId
        initEnvelope*: bool
        envelope*: uint8
        sequences*: array[SequenceKind, Sequence]

    Waveform* = object
        ## Container for a waveform to use on CH3.
        name*: string
        data*: WaveData

    SomeData* = Instrument|Waveform

    Table[T: SomeData] = object
        nextId: TableId
        len: int
        data: array[TableId, EqRef[T]]

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

    Track* = object
        ## Pattern data for a single track. Valid tracks contain 1-256 rows
        ## of data. A Track is invalid (or has no data) if it was default
        ## initialized, use isValid() to check for validity.
        data: seq[TrackRow]

    # Song

    Song* {.requiresInit.} = object
        ## Song type. Contains track data for a single song.
        ##
        name*: string
        rowsPerBeat*: ByteIndex
        rowsPerMeasure*: ByteIndex
        speed*: Speed
        effectCounts*: array[4, EffectColumns]
        order*: Order
        trackLen: TrackLen
        tracks: array[ChannelId, tables.Table[ByteIndex, Shallow[Track]]]

    SongList* {.requiresInit.} = object
        ## Container for songs. Songs stored in this container are references,
        ## like InstrumentTable and WaveformTable. A SongList can contain 1-256
        ## songs.
        data: seq[EqRef[Song]]

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
    defaultTrackSize*: TrackLen = 64
    defaultFramerate*: Framerate = 30

func effectTypeShortensPattern*(et: EffectType): bool =
    result = et == etPatternHalt or
             et == etPatternSkip or
             et == etPatternGoto

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

func init*(T: typedesc[Instrument]): T.typeOf =
    discard # default is sufficient

func new*(T: typedesc[Instrument]): ref T.typeOf =
    new(result)

# Waveform

func init*(T: type Waveform): T =
    discard # default is sufficient, no init needed

func new*(T: typedesc[Waveform]): ref T.typeOf =
    new(result)

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

func init*(T: typedesc[SomeTable]): T.typeOf =
    discard  # default is sufficient

func contains*[T: SomeData](t: Table[T], id: TableId): bool =
    t.data[id].src != nil

proc updateNextId[T: SomeData](t: var Table[T]) =
    for i in t.nextId..high(TableId):
        if i notin t:
            t.nextId = i
            break

proc capacity*[T: SomeData](t: Table[T]): static[int] =
    high(TableId).int + 1

proc `[]`*[T: SomeData](t: var Table[T], id: TableId): ref T =
    t.data[id].src

func `[]`*[T: SomeData](t: Table[T], id: TableId): Immutable[ref T] =
    t.data[id].src.toImmutable

iterator items*[T: SomeData](t: Table[T]): TableId {.noSideEffect.} =
    ## Iterates all items in the table, via their id, in order.
    for id in low(TableId)..high(TableId):
        if id in t:
            yield id

proc insert[T: SomeData](t: var Table[T], id: TableId) =
    t.data[id].src = T.new
    inc t.len

proc add*[T: SomeData](t: var Table[T]): TableId =
    assert t.len < t.capacity
    t.insert(t.nextId)
    result = t.nextId
    t.updateNextId()

proc add*[T: SomeData](t: var Table[T], id: TableId) =
    assert t.len < t.capacity and id notin t
    t.insert(id)
    if t.nextId == id:
        t.updateNextId()

proc duplicate*[T: SomeData](t: var Table[T], id: TableId): TableId =
    assert id in t
    result = t.add()
    # duplicate the newly added item
    t.data[result].src[] = t.data[id].src[]

proc remove*[T: SomeData](t: var Table[T], id: TableId) =
    assert id in t
    t.data[id].src = nil
    dec t.len
    if t.nextId > id:
        t.nextId = id

proc len*[T: SomeData](t: Table[T]): int =
    t.len

func nextAvailableId*[T: SomeData](t: Table[T]): TableId =
    t.nextId

func next*[T: SomeData](t: Table[T], start: TableId = 0): Option[TableId] =
    for id in start..high(TableId):
        if id in t:
            return some(id)
    none(TableId)

func wavedata*(t: WaveformTable, id: TableId): WaveData =
    ## Shortcut for getting the waveform's wavedata via id. The waveform must
    ## exist in the table!
    assert id in t
    t.data[id].src.data

# Order

func init*(T: typedesc[Order]): T.typeof =
    result = Order(
        data: @[[0u8, 0, 0, 0]]
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
    for track in ChannelId:
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
    #cast[uint64](row) == 0u64
    row == default(TrackRow)

# Track

proc init*(T: typedesc[Track], len: TrackLen): T.typeOf =
    Track(
        data: newSeq[TrackRow](len)
    )

func `[]`*(t: Track, i: ByteIndex): TrackRow =
    t.data[i]

proc `[]`*(t: var Track, i: ByteIndex): var TrackRow =
    t.data[i]

proc `[]=`*(t: var Track, i: ByteIndex, v: TrackRow) =
    t.data[i] = v

func isValid*(t: Track): bool =
    t.data.len > 0

func len*(t: Track): int =
    t.data.len

proc setLen*(t: var Track, len: TrackLen) =
    t.data.setLen(len)

iterator items*(t: Track): TrackRow =
    for t in t.data:
        yield t

iterator mitems*(t: var Track): var TrackRow =
    for t in t.data.mitems:
        yield t

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
    for row in t:
        if not row.isEmpty():
            inc result

# Song

template construct(T: typedesc[Song|ref Song]): untyped =
    T(
        name: "",
        rowsPerBeat: defaultRpb,
        rowsPerMeasure: defaultRpm,
        speed: defaultSpeed,
        effectCounts: [2.EffectColumns, 2, 2, 2],
        order: Order.init,
        trackLen: defaultTrackSize,
        tracks: default(Song.tracks.typeOf)
    )

func init*(T: typedesc[Song]): T.typeOf =
    T.construct

func new*(T: typedesc[Song]): ref T.typeOf =
    (ref T).construct

func new*(T: typedesc[Song], song: Song): ref T.typeOf =
    (ref T)(
        name: song.name,
        rowsPerBeat: song.rowsPerBeat,
        rowsPerMeasure: song.rowsPerMeasure,
        speed: song.speed,
        effectCounts: song.effectCounts,
        order: song.order,
        trackLen: song.trackLen,
        tracks: song.tracks
    )

proc removeAllTracks*(s: var Song) =
    for table in s.tracks.mitems:
        table.clear()

proc speedToFloat*(speed: Speed): float =
    speed.float * (1.0 / (1 shl speedFractionBits))

proc speedToTempo*(speed: float, rowsPerBeat: PositiveByte, framerate: float): float =
    (framerate * 60.0) / (speed * rowsPerBeat.float)

proc getTrack(s: var Song, ch: ChannelId, order: ByteIndex): ptr Track =
    if order notin s.tracks[ch]:
        s.tracks[ch][order] = Track.init(s.trackLen).toShallow
    s.tracks[ch].withValue(order, t):
        # pointer return and not var since we cannot prove result will be initialized
        # nil should never be returned though
        result = t.src.addr

template getShallowTrack(s: Song, ch: ChannelId, order: ByteIndex): Shallow[Track] =
    s.tracks[ch].getOrDefault(order)

func getTrack*(s: Song, ch: ChannelId, order: ByteIndex): Track =
    ## Gets a copy of the track for the given channel and track id. If there is
    ## no track for this address, an invalid Track is returned. Note that this
    ## proc returns a copy! For non-copying access use the viewTrack template.
    s.getShallowTrack(ch, order).src

iterator trackIds*(s: Song, ch: ChannelId): ByteIndex =
    for id in s.tracks[ch].keys:
        yield id

proc getRow*(s: var Song, ch: ChannelId, order, row: ByteIndex): var TrackRow =
    s.getTrack(ch, order)[][row]

proc getRow*(s: Song, ch: ChannelId, order, row: ByteIndex): TrackRow =
    if order in s.tracks[ch]:
        result = s.tracks[ch][order].src[row]
    else:
        result = TrackRow()

func totalTracks*(s: Song): int =
    for t in s.tracks:
        result += t.len

proc trackLen*(s: Song): TrackLen {.inline.} =
    s.trackLen

proc setTrackLen*(s: var Song, size: TrackLen) =
    for table in s.tracks.mitems:
        for track in table.mvalues:
            track.src.setLen(size)
    s.trackLen = size

proc setTrack*(s: var Song, ch: ChannelId, order: ByteIndex, track: sink Track) =
    s.tracks[ch][order] = track.toShallow

proc estimateSpeed*(s: Song, tempo, framerate: float): Speed =
    let speedFloat = speedToTempo(tempo, s.rowsPerBeat, framerate)
    let speed = round(speedFloat * (1 shl speedFractionBits).float).uint8
    result = clamp(speed, low(Speed), high(Speed))

proc tempo*(s: Song, framerate: float): float =
    result = speedToTempo(speedToFloat(s.speed), s.rowsPerBeat, framerate)

template editTrack*(s: var Song, ch: ChannelId, trackId: ByteIndex, value, body: untyped): untyped =
    mixin getTrack
    block:
        let track = s.getTrack(ch, trackId)
        template value(): var Track {.inject, used.} = track[]
        body

template viewTrack*(t: Song, ch: ChannelId, trackId: ByteIndex, value, body: untyped): untyped =
    mixin getShallowTrack
    block:
        let shallow = t.getShallowTrack(ch, trackId)
        template value(): lent Track {.inject, used.} = shallow.src
        body

template editPattern*(s: var Song, orderNo: ByteIndex, value, body: untyped): untyped =
    mixin getTrack
    block:
        let pattern: array[ChannelId, ptr Track] = block:
            let orderRow = s.order[orderNo]
            [
                s.getTrack(ch1, orderRow[ch1]),
                s.getTrack(ch2, orderRow[ch2]),
                s.getTrack(ch3, orderRow[ch3]),
                s.getTrack(ch4, orderRow[ch4])
            ]
        template value(ch: ChannelId): var Track {.inject, used.} = pattern[ch][]
        body

template viewPattern*(s: Song, orderNo: ByteIndex, value, body: untyped): untyped =
    mixin getShallowTrack
    block:
        let pattern: array[ChannelId, Shallow[Track]] = block:
            let orderRow = s.order[orderNo]
            [
                s.getShallowTrack(ch1, orderRow[ch1]),
                s.getShallowTrack(ch2, orderRow[ch2]),
                s.getShallowTrack(ch3, orderRow[ch3]),
                s.getShallowTrack(ch4, orderRow[ch4])
            ]
        template value(ch: ChannelId): lent Track {.inject, used.} = pattern[ch].src
        body

func patternLen*(s: Song, order: ByteIndex): Natural =
    ## Gets the length, in rows, of a pattern taking effects into consideration.
    ## If no pattern jump/halt effect is used then the track length is returned
    s.viewPattern(order, pattern):
        for i in 0..<s.trackLen:
            inc result
            for ch in ChannelId:
                if pattern(ch).isValid:
                    let row = pattern(ch)[i]
                    for effect in row.effects:
                        if effectTypeShortensPattern(effect.effectType.EffectType):
                            return

# SongList

func init*(T: typedesc[SongList], len: PositiveByte = 1): T.typeOf =
    result = SongList(
        data: newSeq[EqRef[Song]](len)
    )
    for songref in result.data.mitems:
        songref.src = Song.new

proc `[]`*(l: var SongList, i: ByteIndex): ref Song =
    l.data[i].src

func `[]`*(l: SongList, i: ByteIndex): Immutable[ref Song] =
    l.data[i].src.toImmutable

proc `[]=`*(l: var SongList, i: ByteIndex, s: ref Song) =
    l.data[i].src = s

proc canAdd(l: SongList) =
    if l.data.len == 256:
        raise newException(InvalidOperationDefect, "SongList cannot have more than 256 songs")

proc add*(l: var SongList) =
    l.canAdd()
    l.data.add(Song.new.toEqRef)

proc add*(l: var SongList, song: ref Song) =
    l.canAdd()
    l.data.add(song.toEqRef)

proc duplicate*(l: var SongList, i: ByteIndex) =
    l.canAdd()
    l.data.add( Song.new( l.data[i].src[] ).toEqRef )

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

template construct(T: typedesc[Module | ref Module]): untyped =
    T(
        songs: SongList.init,
        instruments: InstrumentTable.init,
        waveforms: WaveformTable.init,
        title: default(InfoString),
        artist: default(InfoString),
        copyright: default(InfoString),
        comments: "",
        system: systemDmg,
        customFramerate: defaultFramerate,
        private: ModulePrivate(
            version: appVersion,
            revisionMajor: fileMajor,
            revisionMinor: fileMinor
        )
    )

func init*(T: typedesc[Module]): T.typeOf =
    T.construct

func new*(T: typedesc[Module]): ref T.typeOf =
    (ref T).construct

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

