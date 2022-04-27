
import data
import version
import private/[endian, ioblocks]

import private/data as dataPrivate

import std/[options]

const
    headerSize = 160
        ## Size of the file header
    revOffset = 24
        ## File revision is located at this offset in the header

type
    FormatResult* = enum
        frNone
            ## No error, format is acceptable
        frInvalidSignature
            ## File has an invalid signature
        frInvalidRevision
            ## File has an unrecognized revision, possibly from a newer version of the format
        frCannotUpgrade
            ## An older revision file could not be upgraded to current revision
        frInvalid
            ## Invalid payload
        frReadError
            ## A read error occurred during processing
        frWriteError
            ## A write error occurred during processing

    BiasedUint8 = distinct uint8
        ## biased uint8, a value of 0.BiasedUint8 is equal to 1.uint8

    Signature = array[12, char]

    Header0 {.packed.} = object
        signature: Signature
        versionMajor: LittleEndian[uint32]
        versionMinor: LittleEndian[uint32]
        versionPatch: LittleEndian[uint32]
        revision: uint8
        system: uint8
        customFramerate: LittleEndian[uint16]
        title: InfoString
        artist: InfoString
        copyright: InfoString
        numberOfInstruments: LittleEndian[uint16]
        numberOfWaveforms: LittleEndian[uint16]
        reserved: array[32, byte]

    BasicHeader {.packed.} = object
        signature: Signature
        versionMajor: LittleEndian[uint32]
        versionMinor: LittleEndian[uint32]
        versionPatch: LittleEndian[uint32]
        revMajor: uint8
        revMinor: uint8

    Header1 {.packed.} = object
        bh: BasicHeader
        reserved: uint16
        title: InfoString
        artist: InfoString
        copyright: InfoString
        icount: uint8
        scount: BiasedUint8
        wcount: uint8
        system: uint8
        customFramerate: LittleEndian[uint16]
        reserved1: array[30, byte]

    Header = Header1

    ModulePiece = Instrument|Song|Waveform
    # A piece of a module, can be serialized/deserialized separately

    # payload records
    InstrumentFormat {.packed.} = object
        channel: uint8
        envelopeEnabled: bool
        envelope: uint8
    
    SequenceFormat {.packed.} = object
        length: LittleEndian[uint16]
        loopEnabled: bool
        loopIndex: uint8

    PackedEffects = distinct uint8

    SongFormat {.packed.} = object
        rowsPerBeat: uint8
        rowsPerMeasure: uint8
        speed: uint8
        patternCount: BiasedUint8
        rowsPerTrack: BiasedUint8
        numberOfTracks: LittleEndian[uint16]
        effectCounts: PackedEffects
    
    TrackFormat {.packed.} = object
        channel: uint8
        trackId: uint8
        rows: uint8
    
    RowFormat {.packed.} = object
        rowno: uint8
        rowdata: TrackRow


static:
    assert Header0.sizeof == headerSize
    assert Header1.sizeof == headerSize
    assert offsetof(Header0, revision) == revOffset
    assert offsetof(Header1, bh) + offsetof(BasicHeader, revMajor) == revOffset

const
    signature: Signature = [
        '\0', 'T', 'R', 'A', 'C', 'K', 'E', 'R', 'B', 'O', 'Y', '\0'
    ]

    terminator: Signature = block:
        # signature, reversed
        var arr: Signature
        for i in 0..high(signature):
            arr[i] = signature[signature.high - i]
        arr

    blockIdIndex        = "INDX".toBlockId # Deprecated in major 1
    blockIdComment      = "COMM".toBlockId
    blockIdSong         = "SONG".toBlockId
    blockIdInstrument   = "INST".toBlockId
    blockIdWave         = "WAVE".toBlockId

converter unbias(val: BiasedUint8): uint8 {.inline.} =
    val.uint8 + 1

converter bias(val: uint8): BiasedUint8 {.inline.} =
    (val - 1).BiasedUint8

func currentVersionHeader(): BasicHeader =
    BasicHeader(
        signature: signature,
        versionMajor: toLE(appVersion.major.uint32),
        versionMinor: toLE(appVersion.minor.uint32),
        versionPatch: toLE(appVersion.patch.uint32),
        revMajor: fileMajor,
        revMinor: fileMinor,
    )

template errorCheck(body: untyped): untyped =
    ## template for returning the FormatResult of body if it is not equal to
    ## frNone
    block:
        let error = body
        if error != frNone:
            return error

template invalidWhen(cond: bool): untyped =
    ## template to return frInvalid when cond is true
    if cond:
        return frInvalid

func packEffectCounts(ec: EffectCounts): PackedEffects =
    (ec[0] or (ec[1] shl 2) or (ec[2] shl 4) or (ec[3] shl 6)).PackedEffects

func unpackEffectCounts(ec: PackedEffects): EffectCounts =
    template toColumn(val: uint8): EffectColumns =
        # clamp(val, EffectColumns.low, EffectColumns.high)
        max(val, EffectColumns.low)
    [ 
        toColumn(ec.uint8 and 0x3),
        toColumn((ec.uint8 shr 2) and 0x3),
        toColumn((ec.uint8 shr 4) and 0x3),
        toColumn((ec.uint8 shr 6) and 0x3)
    ]

proc upgrade(h0: Header0, h1: var Header1): bool =
    ## Upgrades a rev 0 header to rev 1, returns true if the upgrade
    if h0.numberOfInstruments.toNE() > high(uint8) or h0.numberOfWaveforms.toNE() > high(uint8):
        return false
    else:
        h1.bh.signature = signature
        h1.bh.versionMajor = h0.versionMajor
        h1.bh.versionMinor = h0.versionMinor
        h1.bh.versionPatch = h0.versionPatch
        h1.bh.revMajor = 0
        h1.title = h0.title
        h1.artist = h0.artist
        h1.copyright = h0.copyright
        h1.icount = h0.numberOfInstruments.toNE().uint8
        h1.scount = 1u8
        h1.wcount = h0.numberOfWaveforms.toNE().uint8
        h1.system = h0.system
        h1.customFramerate = h0.customFramerate
        return true

# proc upgrade(h1: Header1, h2: var Header2): bool =
# etc...

proc deserialize(str: var string, ib: var InputBlock): FormatResult =
    str.setLen(block:
        # get the 2-byte length prefix
        var len: LittleEndian[uint16]
        if ib.read(len):
            return frInvalid
        len.toNE.int
    )
    if ib.read(str):
        return frInvalid
    frNone

proc deserialize[T: ModulePiece](p: var T, ib: var InputBlock, major: int): FormatResult =
    # all pieces start with a name for major > 0
    if major > 0:
        var name: string
        errorCheck: deserialize(name, ib)
        p.name = name
    when T is Instrument:
        var format: InstrumentFormat
        invalidWhen ib.read(format)
        invalidWhen format.channel.int notin ch1..ch4
        p.channel = format.channel
        p.initEnvelope = format.envelopeEnabled
        p.envelope = format.envelope
        for sequence in p.sequences.mitems:
            var sequenceFormat: SequenceFormat
            invalidWhen ib.read(sequenceFormat)
            let seqlen = toNE(sequenceFormat.length).int
            invalidWhen seqlen > high(SequenceSize)
            
            if sequenceFormat.loopEnabled:
                sequence.loopIndex = some(sequenceFormat.loopIndex.ByteIndex)
            else:
                sequence.loopIndex = none(ByteIndex)

            var seqdata = newSeq[uint8](seqlen)
            invalidWhen ib.read(seqdata)
            sequence.data = seqdata
    elif T is Song:
        var format: SongFormat
        invalidWhen ib.read(format)
        p.rowsPerBeat = format.rowsPerBeat
        p.rowsPerMeasure = format.rowsPerMeasure
        invalidWhen format.speed.Speed notin (low(Speed)..high(Speed))
        p.speed = format.speed.Speed
        if major > 0:
            var packed: PackedEffects
            invalidWhen ib.read(packed)
            p.effectCounts = unpackEffectCounts(packed)
        # Order
        block:
            var order = newSeq[OrderRow](unbias(format.patternCount))
            invalidWhen ib.read(order)
            p.order.data = order
        # Track data
        p.removeAllTracks()
        let trackSize = unbias(format.rowsPerTrack).TrackSize
        p.setTrackSize(trackSize)
        for i in 0..<toNE(format.numberOfTracks).int:
            var trackFormat: TrackFormat
            invalidWhen ib.read(trackFormat)
            invalidWhen trackFormat.channel.int notin ch1..ch4
            let track = p.getTrack(trackFormat.channel.ChannelId, trackFormat.trackId)
            let rowcount = unbias(trackFormat.rows).TrackSize
            invalidWhen rowcount > trackSize
            for j in 0..<rowcount:
                var rowFormat: RowFormat
                invalidWhen ib.read(rowFormat)
                track[][rowFormat.rowno] = rowFormat.rowdata
    else:   # Waveform
        invalidWhen ib.read(p.data)
    frNone

proc serialize(str: string, ob: var OutputBlock) =
    ob.write(toLE(str.len.uint16))
    ob.write(str)

proc serialize[T: ModulePiece](p: T, ob: var OutputBlock) =
    serialize(p.name, ob)
    when T is Instrument:
        ob.write(InstrumentFormat(
            channel: p.channel.uint8,
            envelopeEnabled: p.initEnvelope,
            envelope: p.envelope
        ))
        for sequence in p.sequences:
            ob.write(SequenceFormat(
                length: toLE(sequence.data.len.uint16),
                loopEnabled: sequence.loopIndex.isSome(),
                loopIndex: sequence.loopIndex.get(0).uint8
            ))
            ob.write(sequence.data)
    elif T is Song:
        ob.write(SongFormat(
            rowsPerBeat: p.rowsPerBeat.uint8,
            rowsPerMeasure: p.rowsPerMeasure.uint8,
            speed: p.speed.uint8,
            patternCount: bias(p.order.size.uint8),
            rowsPerTrack: bias(p.trackSize.uint8),
            numberOfTracks: toLE(p.totalTracks().uint16),
            effectCounts: packEffectCounts(p.effectCounts)
        ))
        # write the song order
        ob.write(p.order.data)
        # write out all tracks
        for chno in ch1..ch4:
            for trackid, track in p.tracks(chno):
                let rowcount = track[].totalRows()
                if rowcount > 0:
                    # only save non-empty tracks
                    ob.write(TrackFormat(
                        channel: chno.uint8,
                        trackId: trackid.uint8,
                        rows: bias(rowcount.uint8)
                    ))
                    for rowno, row in track[].data.pairs:
                        if not row.isEmpty():
                            ob.write(RowFormat(
                                rowno: rowno.uint8,
                                rowdata: row
                            ))

    else:   # Waveform
        ob.write(p.data)

# Payload processing
# A payload is composed of blocks

proc processIndx(m: var Module, ib: var InputBlock, icount, wcount: int): FormatResult =
    # Index block, only present in legacy modules

    proc legacyDeserialize(str: var string, ib: var InputBlock): bool =
        # legacy string deserializer, uses a 1-byte length prefix
        var len: uint8
        if ib.read(len):
            return true
        str.setLen(len.int)
        ib.read(str)

    if legacyDeserialize(m.songs[0].name, ib):
        return frInvalid
    
    template readListIndex(count: int, table: untyped): untyped =
        for i in 0..<count:
            var id: uint8
            if ib.read(id):
                return frInvalid
            table.add(id)
            var name: string
            if legacyDeserialize(name, ib):
                return frInvalid
            table[id][].name = name
    
    readListIndex(icount, m.instruments)
    readListIndex(wcount, m.waveforms)

template readBlock(id: BlockId, stream: Stream, body: untyped): untyped =
    block:
        var ib {.inject.} = initInputBlock(stream)
        invalidWhen ib.begin() != id
        body
        invalidWhen not ib.isFinished()

proc deserialize*(m: var Module, stream: Stream): FormatResult {.raises: [].} =
    
    proc readHeader(stream: Stream, header: var Header): FormatResult =
        var headerBuf: array[headerSize, byte]
        stream.read(headerBuf)
        let rev = headerBuf[revOffset]
        case rev:
        of 0: # rev A (legacy modules)
            if not upgrade(cast[Header0](headerBuf), header):
                return frCannotUpgrade
        of 1: # rev B, C
            header = cast[Header](headerBuf)
            return frNone
        else:
            return frInvalidRevision

    proc processComm(m: var Module, ib: var InputBlock): FormatResult =
        var comments: string
        if ib.size > 0:
            if ib.read(comments):
                return frInvalid
        m.comments = comments
        frNone

    try:
        var header: Header
        errorCheck: readHeader(stream, header)

        if header.bh.signature != signature:
            return frInvalidSignature

        if header.system.System in low(System)..high(System):
            m.system = header.system.System
            if m.system == SystemCustom:
                let framerate = toNE(header.customFramerate)
                invalidWhen framerate.int notin low(Framerate)..high(Framerate)
                m.customFramerate = framerate
        else:
            return frInvalid
        
        invalidWhen header.icount > high(TableId)+1 or header.wcount > high(TableId)+1

        m.private.revisionMajor = header.bh.revMajor.int
        m.private.revisionMinor = header.bh.revMinor.int
        m.private.version.major = header.bh.versionMajor.toNE.int
        m.private.version.minor = header.bh.versionMinor.toNE.int
        m.private.version.patch = header.bh.versionPatch.toNE.int

        m.title = header.title
        m.artist = header.artist
        m.copyright = header.copyright

        m.instruments = initTable[Instrument]()
        m.waveforms = initTable[Waveform]()
        m.songs = initSongList(header.scount.unbias.int)

        # read the payload
        let major = header.bh.revMajor.int
        case major:
        of 0: # Rev A module
            readBlock blockIdIndex, stream:
                errorCheck: processIndx(m, ib, header.icount.int, header.wcount.int)
            readBlock blockIdComment, stream:
                errorCheck: processComm(m, ib)
            readBlock blockIdSong, stream:
                errorCheck: deserialize(m.songs[0][], ib, major)

            template processTableBlock(table: var SomeTable, blockId: BlockId) =
                readBlock blockId, stream:
                    for id in table:
                        errorCheck: deserialize(table[id][], ib, major)
            
            processTableBlock(m.instruments, blockIdInstrument)
            processTableBlock(m.waveforms, blockIdWave)

        else: # Rev B and up
            readBlock blockIdComment, stream:
                errorCheck: processComm(m, ib)
            
            for i in 0..<header.scount.unbias.int:
                readBlock blockIdSong, stream:
                    errorCheck: deserialize(m.songs[i][], ib, major)

            template processTableBlock(table: var SomeTable, count: int, blockId: BlockId) =
                for i in 0..<count:
                    readBlock blockId, stream:
                        var id: TableId
                        invalidWhen ib.read(id)
                        invalidWhen id notin low(TableId)..high(TableId) or table[id] == nil
                        table.add(id)
                        errorCheck: deserialize(table[id][], ib, major)

            processTableBlock(m.instruments, header.icount.int, blockIdInstrument)
            processTableBlock(m.waveforms, header.wcount.int, blockIdWave)


        # check the terminator (rev B and up)
        if m.private.revisionMajor > 0:
            var term: Signature
            stream.read(term)
            if term != terminator:
                return frInvalid
    except IOError, OSError:
        return frWriteError

template blockIdOfType(T: typedesc[ModulePiece]): BlockId =
    when T is Instrument:
        blockIdInstrument
    elif T is Song:
        blockIdSong
    else:   # Waveform
        blockIdWave

template deserializeImpl[T: ModulePiece](p: var T, stream: Stream): FormatResult =
    try:
        var header: BasicHeader
        stream.read(header)
        if header.signature != signature:
            return frInvalidSignature
        if header.revMajor != 1: # only rev 1 supports single block files
            return frInvalidRevision

        readBlock blockIdOfType(T.typeOf), stream:
            errorCheck: deserialize(p, ib, 1)

    except IOError, OSError:
        return frReadError
    frNone

proc deserialize*(i: var Instrument, stream: Stream): FormatResult {.raises: [].} =
    deserializeImpl(i, stream)

proc deserialize*(s: var Song, stream: Stream): FormatResult {.raises: [].} =
    deserializeImpl(s, stream)

proc deserialize*(w: var Waveform, stream: Stream): FormatResult {.raises: [].} =
    deserializeImpl(w, stream)

template writeBlock(id: BlockId, stream: Stream, body: untyped): untyped =
    block:
        var ob {.inject.} = initOutputBlock(stream)
        ob.begin(id)
        body
        ob.finish()

proc serialize*(m: Module, stream: Stream): FormatResult {.raises: [].} =
    # header
    try:
        block:
            let header = Header(
                bh: currentVersionHeader(),
                title: m.title,
                artist: m.artist,
                copyright: m.copyright,
                icount: m.instruments.size.uint8,
                scount: m.songs.len.uint8,
                wcount: m.waveforms.size.uint8,
                system: ord(m.system).uint8,
                customFramerate: toLE(m.customFramerate.uint16)
            )
            
            stream.write(header)

        # payload
        writeBlock blockIdComment, stream:
            ob.write(m.comments)

        for i in 0..<m.songs.len:
            writeBlock blockIdSong, stream:
                serialize(m.songs[i][], ob)

        template processTableBlock(table: SomeTable, blockId: BlockId) =
            for id in table:
                writeBlock blockId, stream:
                    ob.write(id)
                    serialize(table[id][], ob)

        processTableBlock(m.instruments, blockIdInstrument)
        processTableBlock(m.waveforms, blockIdWave)

        # terminator
        stream.write(terminator)
    except IOError, OSError:
        return frWriteError

template serializeImpl[T: ModulePiece](p: T, stream: Stream): FormatResult =
    try:
        stream.write(currentVersionHeader())
        writeBlock blockIdOfType(T.type), stream:
            serialize(p, ob)
    except IOError, OSError:
        return frWriteError
    frNone

proc serialize*(i: Instrument, stream: Stream): FormatResult {.raises: [].} =
    serializeImpl(i, stream)

proc serialize*(s: Song, stream: Stream): FormatResult {.raises: [].} =
    serializeImpl(s, stream)

proc serialize*(w: Waveform, stream: Stream): FormatResult {.raises: [].} =
    serializeImpl(w, stream)
