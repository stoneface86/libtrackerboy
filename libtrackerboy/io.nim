##[

Module I/O. Allows for the deserialization/serialization of Module and
ModulePiece types.

]##

import
  ./data,
  ./version,
  ./private/endian,
  ./private/ioblocks,
  ./private/utils
import ./private/data as dataPrivate

import std/[options]

const
  headerSize = 160
    ## Size of the file header
  revOffset = 24
    ## File revision is located at this offset in the header

type
  FormatResult* = enum
    frNone = 0
      ## No error, format is acceptable
    frInvalidSignature = 1
      ## File has an invalid signature
    frInvalidRevision = 2
      ## File has an unrecognized revision, possibly from a newer version of the format
    frCannotUpgrade = 3
      ## An older revision file could not be upgraded to current revision
    frInvalidSize = 4
      ## Attempted to read past the size of a payload block, block data
      ## is ill-formed
    frInvalidCount = 5
      ## The icount or wcount field in the header is too big
    frInvalidBlock = 6
      ## An invalid/unknown block id was used in a payload block
    frInvalidChannel = 7
      ## An invalid/unknown channel was used in a payload block
    frInvalidSpeed = 8
      ## The format contains an invalid speed, outside of Speed.low..Speed.high
    frInvalidRowCount = 9
      ## A TrackFormat's rows field in a SONG block exceeds the Song's
      ## track size
    frInvalidRowNumber = 10
      ## A RowFormat's rowno field exceeds the Song's track size
    frInvalidId = 11
      ## An instrument or waveform has an invalid id
    frInvalidDuplicateId = 12
      ## Two instruments or two waveforms have the same id
    frInvalidTerminator = 13
      ## The terminator is invalid.
    frReadError = 14
      ## A read error occurred during processing
    frWriteError = 15
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
  
  Header2 {.packed.} = object
    bh: BasicHeader
    reserved: uint16
    title: InfoString
    artist: InfoString
    copyright: InfoString
    icount: uint8
    scount: BiasedUint8
    wcount: uint8
    system: uint8
    customFramerate: LittleEndian[float32]
    reserved1: array[28, byte]

  Header = Header2

  HeaderBuf = array[headerSize, byte]

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

  SongFormatEx1 {.packed.} = object
    numberOfEffects: PackedEffects
  
  SongFormatEx2 {.packed.} = object
    systemOverride: uint8
    customFramerateOverride: LittleEndian[float32]
  
  TrackFormat {.packed.} = object
    channel: uint8
    trackId: uint8
    rows: BiasedUint8
  
  RowFormat {.packed.} = object
    rowno: uint8
    rowdata: TrackRow


static:
  assert Header0.sizeof == headerSize
  assert Header1.sizeof == headerSize
  assert Header2.sizeof == headerSize
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

type BiasRange = range[1..256]

func unbias(val: BiasedUint8): BiasRange {.inline.} =
  val.int + 1

func bias(val: BiasRange): BiasedUint8 {.inline.} =
  (val.int - 1).BiasedUint8

func `==`(l, r: BiasedUint8): bool {.borrow.}
func `$`(b: BiasedUint8): string {.borrow.}

static:
  assert 1.bias == 0.BiasedUint8
  assert 256.bias == 0xFF.BiasedUint8
  assert 0.BiasedUint8.unbias == 1
  assert 0xFF.BiasedUint8.unbias == 256
  assert 23.bias.unbias == 23

func currentVersionHeader(): BasicHeader =
  BasicHeader(
    signature: signature,
    versionMajor: toLE(currentVersion.major.uint32),
    versionMinor: toLE(currentVersion.minor.uint32),
    versionPatch: toLE(currentVersion.patch.uint32),
    revMajor: currentFileMajor,
    revMinor: currentFileMinor,
  )

template errorCheck(body: untyped): untyped =
  ## template for returning the FormatResult of body if it is not equal to
  ## frNone
  block:
    let error = body
    if error != frNone:
      return error

template invalidWhen(cond: bool; res = frInvalidSize): untyped =
  ## template to return res when cond is true
  if cond:
    return res

template checkChannel(channel: int): untyped =
  if channel notin ChannelId:
    return frInvalidChannel

func packEffectCounts(ec: EffectCounts): PackedEffects =
  PackedEffects(ec[ch1] or (ec[ch2] shl 2) or (ec[ch3] shl 4) or (ec[ch4] shl 6))

func unpackEffectCounts(ec: PackedEffects): EffectCounts =
  result = [ 
    ec.uint8 and 0x3,
    (ec.uint8 shr 2) and 0x3,
    (ec.uint8 shr 4) and 0x3,
    (ec.uint8 shr 6) and 0x3
  ]

func `$`(p: PackedEffects): string =
  $p.unpackEffectCounts

proc upgradeHeader0to1(h: var HeaderBuf): bool =
  template h0(): Header0 = cast[Header0](h)
  template h1(): var Header1 = cast[ptr Header1](h.addr)[]
  let
    icount = toNE(h0.numberOfInstruments)
    wcount = toNE(h0.numberOfWaveforms)
    system = h0.system
    customFramerate = h0.customFramerate
  if icount > high(uint8) or wcount > high(uint8):
    result = false
  else:
    # Was Header0's system field
    h1.bh.revMinor = 0
    # Was Header0's customFramerate field
    h1.reserved = 0
    # Was Header0's numberOfInstruments and numberOfWaveforms fields
    h1.icount = uint8(icount)
    h1.scount = bias(1)
    h1.wcount = uint8(wcount)
    h1.system = system
    # overwrites 2 bytes of Header0's reserved
    h1.customFramerate = customFramerate
    result = true

proc upgradeHeader1to2(h: var HeaderBuf) =
  template h1(): Header1 = cast[Header1](h)
  template h2(): var Header2 = cast[ptr Header2](h.addr)[]
  # customFramerate field is now a float32
  # convert existing value from uint16 to float32
  let customFramerateFloat = float32(toNE(h1.customFramerate))
  # store it back as a little endian uint32
  h2.customFramerate = toLE(customFramerateFloat)

proc deserialize(str: var string; ib: var InputBlock): FormatResult =
  str.setLen(block:
    # get the 2-byte length prefix
    var len: LittleEndian[uint16]
    invalidWhen ib.read(len)
    int(toNE(len))
  )
  invalidWhen ib.read(str)
  result = frNone
  
proc deserialize(s: var Sequence; ib: var InputBlock): FormatResult =
  var format: SequenceFormat
  invalidWhen ib.read(format)
  let seqlen = int(toNE(format.length))
  invalidWhen seqlen notin SequenceLen
  if format.loopEnabled:
    s.loop = initLoopPoint(format.loopIndex)
  else:
    s.loop = noLoopPoint

  var seqdata = newSeq[uint8](seqlen)
  invalidWhen ib.read(seqdata)
  s.data = seqdata
  result = frNone

proc deserialize[T: ModulePiece](p: var T; ib: var InputBlock; major: int
                                ): FormatResult =
  # all pieces start with a name for major > 0
  if major > 0:
    var name: string
    errorCheck: deserialize(name, ib)
    p.name = name
  when T is Instrument:
    if major < 2:
      var format: InstrumentFormat
      invalidWhen ib.read(format)
      checkChannel int(format.channel)
      p.channel = ChannelId(format.channel)
      if format.envelopeEnabled:
        p.sequences[skEnvelope].setLen(1)
        p.sequences[skEnvelope][0] = format.envelope
    else:
      # 2.0 replaces InstrumentFormat with a uint8 channel
      var channel: uint8
      invalidWhen ib.read(channel)
      checkChannel int(channel)
      p.channel = ChannelId(channel)
    # deserialize sequences
    for kind in skArp..skTimbre:
      errorCheck: p.sequences[kind].deserialize(ib)
    # new in 2.0, envelope sequences
    if major >= 2:
      errorCheck: p.sequences[skEnvelope].deserialize(ib)

  elif T is Song:
    var format: SongFormat
    invalidWhen ib.read(format)
    p.rowsPerBeat = int(format.rowsPerBeat)
    p.rowsPerMeasure = int(format.rowsPerMeasure)
    invalidWhen not isValid(Speed(format.speed)), frInvalidSpeed
    p.speed = Speed(format.speed)
    if major > 0:
      var ex1: SongFormatEx1
      invalidWhen ib.read(ex1)
      p.effectCounts = unpackEffectCounts(ex1.numberOfEffects)
      if major > 1:
        # new in 2.0, per-song timing option
        var ex2: SongFormatEx2
        invalidWhen ib.read(ex2)
        case ex2.systemOverride
        of 1:
          p.tickrate = some(Tickrate(system: systemDmg))
        of 2:
          p.tickrate = some(Tickrate(system: systemSgb))
        of 3:
          let framerate = toNE(ex2.customFramerateOverride)
          p.tickrate = some(Tickrate(
            system: systemCustom, 
            customFramerate: (
              if framerate > 0.0f:
                framerate
              else:
                defaultTickrate.customFramerate
            )
          ))
        else:
          p.tickrate = none(Tickrate)
    # Order
    block:
      var order = newSeq[OrderRow](unbias(format.patternCount))
      invalidWhen ib.read(order)
      p.order = order
    # Track data
    p.removeAllTracks()
    let trackSize = unbias(format.rowsPerTrack)
    p.trackLen = trackSize
    for i in 0..<int(toNE(format.numberOfTracks)):
      var trackFormat: TrackFormat
      invalidWhen ib.read(trackFormat)
      checkChannel int(trackFormat.channel)
      p.editTrack(ChannelId(trackFormat.channel), trackFormat.trackId, track):
        let rowcount = unbias(trackFormat.rows)
        invalidWhen rowcount > trackSize, frInvalidRowCount
        for j in 0..<rowcount:
          var rowFormat: RowFormat
          invalidWhen ib.read(rowFormat)
          invalidWhen int(rowFormat.rowno) >= int(trackSize), frInvalidRowNumber
          track[rowFormat.rowno] = rowFormat.rowdata
  else:   # Waveform
    invalidWhen ib.read(p.data)
  result = frNone

proc serialize(str: string; ob: var OutputBlock) =
  ob.write(toLE(uint16(str.len)))
  ob.write(str)

proc serialize[T: ModulePiece](p: T; ob: var OutputBlock) =
  serialize(p.name, ob)
  when T is Instrument:
    ob.write(uint8(p.channel))
    for sequence in p.sequences:
      ob.write(SequenceFormat(
        length: toLE(uint16(sequence.len)),
        loopEnabled: sequence.loop.enabled,
        loopIndex: sequence.loop.index
      ))
      ob.write(sequence.data)
  elif T is Song:
    ob.write(SongFormat(
      rowsPerBeat: uint8(p.rowsPerBeat),
      rowsPerMeasure: uint8(p.rowsPerMeasure),
      speed: uint8(p.speed),
      patternCount: bias(p.patternLen()),
      rowsPerTrack: bias(p.trackLen()),
      numberOfTracks: toLE(uint16(p.totalTracks()))
    ))
    ob.write(SongFormatEx1(
      numberOfEffects: packEffectCounts(p.effectCounts)
    ))
    block:
      var f: SongFormatEx2
      if p.tickrate.isSome():
        let tickrate = p.tickrate.get()
        f.systemOverride = uint8(tickrate.system) + 1
        f.customFramerateOverride = toLE(tickrate.customFramerate)
      ob.write(f)
    # write the song order
    ob.write(p.order)
    # write out all tracks
    for chno in ChannelId:
      for trackid in p.trackIds(chno):
        p.viewTrack(chno, trackid, track):
          let rowcount = track.totalRows()
          if rowcount > 0:
            # only save non-empty tracks
            ob.write(TrackFormat(
              channel: uint8(chno),
              trackId: trackid,
              rows: bias(rowcount)
            ))
            for rowno in 0..<track.len:
              let row = track[rowno]
              if not row.isEmpty():
                ob.write(RowFormat(
                  rowno: uint8(rowno),
                  rowdata: row
                ))

  else:   # Waveform
    ob.write(p.data)

# Payload processing
# A payload is composed of blocks

proc processIndx(m: var Module; ib: var InputBlock; icount, wcount: int;
                 ): FormatResult =
  # Index block, only present in legacy modules

  proc legacyDeserialize(str: var string; ib: var InputBlock): bool =
    # legacy string deserializer, uses a 1-byte length prefix
    var len: uint8
    if ib.read(len):
      return true
    str.setLen(int(len))
    ib.read(str)

  invalidWhen legacyDeserialize(m.songs.mget(0).name, ib)
  
  template readListIndex(count: int; table: untyped): untyped =
    for i in 0..<count:
      var id: uint8
      invalidWhen ib.read(id)
      table.add(id)
      var name: string
      invalidWhen legacyDeserialize(name, ib)
      table[id][].name = name
  
  readListIndex(icount, m.instruments)
  readListIndex(wcount, m.waveforms)

template readBlock(id: BlockId; stream: Stream; body: untyped): untyped =
  block:
    var ib {.inject.} = initInputBlock(stream)
    invalidWhen ib.begin() != id, frInvalidBlock
    body
    invalidWhen not ib.isFinished()

proc deserialize*(m: var Module; stream: Stream): FormatResult {.raises: [].} =
  
  proc readHeader(stream: Stream; header: var Header): FormatResult =
    var headerBuf: HeaderBuf
    stream.read(headerBuf)
    let rev = headerBuf[revOffset]
    case rev
    of 0:
      if not upgradeHeader0to1(headerBuf):
        return frCannotUpgrade
      upgradeHeader1to2(headerBuf)
    of 1:
      upgradeHeader1to2(headerBuf)
    of 2:
      discard
    else:
      return frInvalidRevision
    header = cast[Header](headerBuf)
    result = frNone

  proc processComm(m: var Module; ib: var InputBlock): FormatResult =
    var comments: string
    if ib.size > 0:
      comments.setLen(ib.size)
      invalidWhen ib.read(comments)
    m.comments = comments
    frNone

  try:
    var header: Header
    errorCheck: readHeader(stream, header)

    if header.bh.signature != signature:
      return frInvalidSignature

    if header.system in System:
      m.tickrate.system = System(header.system)
      if m.tickrate.system == systemCustom:
        let framerate = cast[float32](toNE(header.customFramerate))
        m.tickrate.customFramerate = block:
          if framerate > 0.0f:
            framerate
          else:
            defaultTickrate.customFramerate
    else:
      m.tickrate = defaultTickrate
    
    invalidWhen header.icount > high(TableId)+1 or 
                header.wcount > high(TableId)+1, frInvalidCount

    m.private.revisionMajor = int(header.bh.revMajor)
    m.private.revisionMinor = int(header.bh.revMinor)
    m.private.version.major = int(toNE(header.bh.versionMajor))
    m.private.version.minor = int(toNE(header.bh.versionMinor))
    m.private.version.patch = int(toNE(header.bh.versionPatch))

    m.title = header.title
    m.artist = header.artist
    m.copyright = header.copyright

    m.instruments = initInstrumentTable()
    m.waveforms = initWaveformTable()
    m.songs = initSongList(unbias(header.scount))

    # read the payload
    let major = int(header.bh.revMajor)
    case major:
    of 0: # Rev A module
      readBlock blockIdIndex, stream:
        errorCheck: processIndx(m, ib, int(header.icount), int(header.wcount))
      readBlock blockIdComment, stream:
        errorCheck: processComm(m, ib)
      readBlock blockIdSong, stream:
        errorCheck: deserialize(m.songs[0][], ib, major)

      template processTableBlock(table: var SomeTable; blockId: BlockId) =
        readBlock blockId, stream:
          for id in table:
            errorCheck: deserialize(table[id][], ib, major)
      
      processTableBlock(m.instruments, blockIdInstrument)
      processTableBlock(m.waveforms, blockIdWave)

    else: # Rev B and up
      readBlock blockIdComment, stream:
        errorCheck: processComm(m, ib)
      
      for i in 0..<unbias(header.scount):
        readBlock blockIdSong, stream:
          errorCheck: deserialize(m.songs[i][], ib, major)

      template processTableBlock(table: var SomeTable; count: int;
                                 blockId: BlockId) =
        for i in 0..<count:
          readBlock blockId, stream:
            var id: TableId
            invalidWhen ib.read(id)
            invalidWhen id notin TableId, frInvalidId
            invalidWhen table[id] != nil, frInvalidDuplicateId
            table.add(id)
            errorCheck: deserialize(table[id][], ib, major)

      processTableBlock(m.instruments, int(header.icount), blockIdInstrument)
      processTableBlock(m.waveforms, int(header.wcount), blockIdWave)


    # check the terminator (rev B and up)
    if m.private.revisionMajor > 0:
      var term: Signature
      stream.read(term)
      if term != terminator:
        return frInvalidTerminator
  except IOError, OSError:
    return frWriteError

template blockIdOfType(T: typedesc[ModulePiece]): BlockId =
  when T is Instrument:
    blockIdInstrument
  elif T is Song:
    blockIdSong
  else:   # Waveform
    blockIdWave

template deserializeImpl[T: ModulePiece](p: var T; stream: Stream
                                         ): FormatResult =
  try:
    var header: BasicHeader
    stream.read(header)
    if header.signature != signature:
      return frInvalidSignature
    let major = int(header.revMajor)
    if major notin 1..currentFileMajor: # only rev 1 and up supports single block files
      return frInvalidRevision

    readBlock blockIdOfType(T.typeOf), stream:
      errorCheck: deserialize(p, ib, major)

  except IOError, OSError:
    return frReadError
  frNone

proc deserialize*(i: var Instrument; stream: Stream
                  ): FormatResult {.raises: [].} =
  deserializeImpl(i, stream)

proc deserialize*(s: var Song; stream: Stream
                  ): FormatResult {.raises: [].} =
  deserializeImpl(s, stream)

proc deserialize*(w: var Waveform; stream: Stream
                  ): FormatResult {.raises: [].} =
  deserializeImpl(w, stream)

template writeBlock(id: BlockId; stream: Stream; body: untyped): untyped =
  block:
    var ob {.inject.} = initOutputBlock(stream)
    ob.begin(id)
    body
    ob.finish()

proc serialize*(m: Module; stream: Stream): FormatResult {.raises: [].} =
  # header
  try:
    block:
      let header = Header(
        bh: currentVersionHeader(),
        title: m.title,
        artist: m.artist,
        copyright: m.copyright,
        icount: uint8(m.instruments.len()),
        scount: bias(m.songs.len()),
        wcount: uint8(m.waveforms.len()),
        system: uint8(m.tickrate.system),
        customFramerate: toLE(m.tickrate.customFramerate)
      )
      
      stream.write(header)

    # payload
    writeBlock blockIdComment, stream:
      ob.write(m.comments)

    for i in 0..<m.songs.len():
      writeBlock blockIdSong, stream:
        serialize(m.songs[i][], ob)

    template processTableBlock(table: SomeTable; blockId: BlockId) =
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

template serializeImpl[T: ModulePiece](p: T; stream: Stream): FormatResult =
  try:
    stream.write(currentVersionHeader())
    writeBlock blockIdOfType(typeOf(T)), stream:
      serialize(p, ob)
  except IOError, OSError:
    return frWriteError
  frNone

proc serialize*(i: Instrument; stream: Stream): FormatResult {.raises: [].} =
  serializeImpl(i, stream)

proc serialize*(s: Song; stream: Stream): FormatResult {.raises: [].} =
  serializeImpl(s, stream)

proc serialize*(w: Waveform; stream: Stream): FormatResult {.raises: [].} =
  serializeImpl(w, stream)
