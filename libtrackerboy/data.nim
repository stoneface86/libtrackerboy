##[

Module for the data model. This module contains data types used in the library.

]##

import common, private/[data, utils], version 
export common

import std/[math, options, parseutils, sequtils, tables]
export options

const
  speedFractionBits = 4
  unitSpeed* = 1 shl speedFractionBits
    ## Constant for a speed value that is exactly 1 frame/row

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
    ## Range of a Song's speed setting. Note that speed is in units of
    ## frames/row and is in fixed point format (Q4.4)

  EffectIndex* = range[0..2]
    ## Index type for an Effect in a TrackRow.
  
  EffectColumns* = range[1u8..3u8]
    ## Range for the number of columns that are visible for a track.
  
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
    ## (Not to be confused with a Nim sequence, `seq[T]`).
    loopIndex*: Option[ByteIndex]
      ## If set, the sequence will loop to this index at the end. If unset
      ## or the index exceeds the bounds of the sequence data, the sequence
      ## will stop at the end instead.
    data: seq[uint8]

  Instrument* = object
    ## Container for a Trackerboy instrument. An instrument provides frame
    ## level control of a channel's parameters and is activated on each
    ## note trigger.
    name*: string
      ## Optional name of the instrument
    channel*: ChannelId
      ## Channel this instrument is to be previewed on. Note that instruments
      ## can be used on any channel, so this field is purely informational.
    initEnvelope*: bool
      ## If true, the envelope setting will be written on note trigger
    envelope*: uint8
      ## Channel envelope to set if initEnvelope is true
    sequences*: array[SequenceKind, Sequence]
      ## Sequence data for this instrument

  Waveform* = object
    ## Container for a waveform to use on CH3.
    name*: string
      ## Optional name of the waveform
    data*: WaveData
      ## The waveform data

  SomeData* = Instrument|Waveform
    ## Type class matching data that is contained in a Table

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
    ## Type class for a Table type

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
    etPatternGoto,          ## Bxx begin playing given pattern immediately
    etPatternHalt,          ## C00 stop playing
    etPatternSkip,          ## D00 begin playing next pattern immediately
    etSetTempo,             ## Fxx set the tempo
    etSfx,                  ## Txx play sound effect
    etSetEnvelope,          ## Exx set the persistent envelope/wave id setting
    etSetTimbre,            ## Vxx set persistent duty/wave volume setting
    etSetPanning,           ## Ixy set channel panning setting
    etSetSweep,             ## Hxx set the persistent sweep setting (CH1 only)
    etDelayedCut,           ## Sxx note cut delayed by xx frames
    etDelayedNote,          ## Gxx note trigger delayed by xx frames
    etLock,                 ## L00 (lock) stop the sound effect on the current channel
    etArpeggio,             ## 0xy arpeggio with semi tones x and y
    etPitchUp,              ## 1xx pitch slide up
    etPitchDown,            ## 2xx pitch slide down
    etAutoPortamento,       ## 3xx automatic portamento
    etVibrato,              ## 4xy vibrato
    etVibratoDelay,         ## 5xx delay vibrato xx frames on note trigger
    etTuning,               ## Pxx fine tuning
    etNoteSlideUp,          ## Qxy note slide up
    etNoteSlideDown,        ## Rxy note slide down
    etSetGlobalVolume       ## Jxy set global volume scale

  Effect* {.packed.} = object
    ## Effect column. An effect has a type and a parameter.
    effectType*: uint8
      ## Type of the effect, should be in range of the EffectType enum,
      ## unknown types are ignored.
    param*: uint8
      ## Effect parameter byte, only needed for certain types.

  TrackRow* {.packed.} = object
    ## A single row of data in a Track. Guaranteed to be 8 bytes.
    note*: uint8
      ## The note index to trigger with a bias of 1 (0 means unset)
    instrument*: uint8
      ## The index of the instrument to set with a bias of 1 (0 means unset)
    effects*: array[EffectIndex, Effect]
      ## 3 available effect columns

  TrackData = array[ByteIndex, TrackRow]

  Track* = object
    ## Pattern data for a single track. A track can store up to 256 rows.
    ## The data is stored using ref semantics, so assigning a track from
    ## another track will result in a shallow copy. Use the init proc to
    ## deep copy a track if needed. A Track is invalid if it was default
    ## initialized, or if its internal data ref is `nil`. Use isValid() to
    ## check for validity.
    ## 
    ## Regarding mutability, all `Track` objects are mutable. If you need
    ## immutable access, use `TrackView`. A `Track` can be converted to a
    ## `TrackView` at no cost, but the opposite is not true. Converting a
    ## `TrackView` to a `Track` will result in a deep copy of the `TrackView`'s
    ## data being made.
    ## 
    data: ref TrackData
    when NimMajor >= 2:
      len*: TrackLen = TrackLen.low
    else:
      len*: TrackLen

  TrackView* {.borrow: `.`.} = distinct Track
    ## Same as track, but only provides immutable access to the track data.
    ## Mutable access can be acquired by converting the view to a Track via
    ## the Track.init overload, while making a deep copy of the data.

  SomeTrack* = Track | TrackView
    ## Type class for all Track types.


  TrackMap = object
    data: array[ChannelId, tables.Table[ByteIndex, EqRef[TrackData]]]

  # Song

  Song* {.requiresInit.} = object
    ## Song type. Contains track data for a single song.
    ##
    name*: string
      ## Name of the song.
    rowsPerBeat*: ByteIndex
      ## Number of rows that make up a beat. Used for tempo calculation
      ## and by the front end for row highlights
    rowsPerMeasure*: ByteIndex
      ## Number of rows that make up a measure. Used only by the front
      ## end for row highlights.
    speed*: Speed
      ## Starting speed of the song when playing back, in frames/row.
    effectCounts*: array[4, EffectColumns]
      ## Effect columns visible counts. To be used by the front end for
      ## the number of effect columns shown for each channel.
    order*: Order
      ## The song's Order
    trackLen*: TrackLen
    tracks: TrackMap

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
    ## Type class for an individual component of a module.

  # Module
  Module* {.requiresInit.} = object
    ## A module is a container for songs, instruments and waveforms.
    ## Each module can store up to 256 songs, 64 instruments and 64
    ## waveforms. Instruments and Waveforms are shared between all songs.
    ##
    songs*: SongList
      ## The list of songs for this module.
    instruments*: InstrumentTable
      ## The module's instrument table, shared with all songs
    waveforms*: WaveformTable
      ## The module's waveform table, shared with all songs

    title*, artist*, copyright*: InfoString
      ## Optional information about the module

    comments*: string
      ## Optional comment information about the module
    system*: System
      ## System framerate setting
    customFramerate*: Framerate
      ## The custom framerate used when system == systemCustom

    private*: ModulePrivate
      ## Internal details only accessible to the library, do not use!

const
  defaultRpb* = 4
    ## Default `rowsPerBeat` setting for new `Songs <#Song>`_
  defaultRpm* = 16
    ## Default `rowsPerMeasure` setting for new `Songs <#Song>`_
  defaultSpeed*: Speed = 0x60
    ## Default `speed` setting for new `Songs <#Song>`_. The
    ## default is 6.0 frames/row or approximately 160 BPM.
  defaultTrackSize*: TrackLen = 64
    ## Default length of a Track for new `Songs <#Song>`_.
  defaultFramerate*: Framerate = 30
    ## Default `customFramerate` setting for new `Modules <#Module>`_.

func effectTypeShortensPattern*(et: EffectType): bool =
  ## Determines if the given effect type will shorten the runtime length of
  ## a pattern by either halting the song or jumping to a new pattern.
  result = et == etPatternHalt or
       et == etPatternSkip or
       et == etPatternGoto

func toEffectType*(x: uint8): EffectType =
  ## Converts a uint8 to an EffectType enum safely. etNoEffect is returned if
  ## x is not in the range of EffectType.
  if x.int in EffectType.low.ord..EffectType.high.ord:
    x.EffectType
  else:
    etNoEffect

# Sequence

proc `[]`*(s: Sequence, i: ByteIndex): uint8 =
  ## Gets the `i`th element in the sequence
  s.data[i]

proc `[]=`*(s: var Sequence, i: ByteIndex, val: uint8) =
  ## Sets the `i`th element in the sequence to the given `val`
  s.data[i] = val

proc setLen*(s: var Sequence, len: SequenceSize) =
  ## Sets the length of the Sequence `s` to the given `len`.
  s.data.setLen(len)

func len*(s: Sequence): int =
  ## Gets the length of the sequence
  s.data.len

func data*(s: Sequence): lent seq[uint8] =
  ## Gets the sequence's data
  s.data

proc `data=`*(s: var Sequence, data: sink seq[uint8]) =
  ## Assigns the sequence's data to the given uint8 sequence. `data.len` must
  ## not exceed 256 or an `AssertionDefect` will be raised.
  doAssert data.len <= 256, "cannot set data: sequence is too big"
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

func init*(T: typedesc[Instrument]): Instrument =
  ## Value constructor for an Instrument. Default initialization is used, so
  ## the instrument's channel is ch1, and all its sequences are empty.
  defaultInit()

func new*(T: typedesc[Instrument]): ref Instrument =
  ## Ref constructor for an Instrument. Same behavior as `init`.
  new(result)

# Waveform

func init*(T: typedesc[Waveform]): Waveform =
  ## Value constructor for a Waveform. The returned Waveform's wave data is
  ## cleared.
  defaultInit()

func new*(T: typedesc[Waveform]): ref Waveform =
  ## Ref contructor for a Waveform. Same behavior as `init`
  new(result)

func `$`*(wave: WaveData): string =
  ## Stringify operator for `WaveData <#WaveData>`_. The data is represented
  ## as a string of 32 uppercase hex characters, with the first character
  ## being the first sample in the wave data.
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
  ## Parses the string as a WaveData string. The given string should be exactly
  ## 32 characters, and each character should be a hexadecimal digit.
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
  ## Value constructor for a new table. The returned table is empty.
  defaultInit()

func contains*[T: SomeData](t: Table[T], id: TableId): bool =
  ## Determines if the table contains an item with the `id`
  t.data[id].src != nil

proc updateNextId[T: SomeData](t: var Table[T]) =
  for i in t.nextId..high(TableId):
    if i notin t:
      t.nextId = i
      break

proc capacity*[T: SomeData](t: Table[T]): static[int] =
  ## Maximum number of items that can be stored in a Table.
  high(TableId).int + 1

proc `[]`*[T: SomeData](t: var Table[T], id: TableId): ref T =
  ## Gets a ref of the item with the given id or `nil` if there is no item
  ## with that id.
  t.data[id].src

func `[]`*[T: SomeData](t: Table[T], id: TableId): Immutable[ref T] =
  ## Gets an immutable ref of the item with the given id or `nil` if there
  ## is no item with that id.
  t.data[id].src.toImmutable

iterator items*[T: SomeData](t: Table[T]): TableId {.noSideEffect.} =
  ## Iterates all items in the table, via their id, in ascending order.
  for id in low(TableId)..high(TableId):
    if id in t:
      yield id

proc insert[T: SomeData](t: var Table[T], id: TableId) =
  t.data[id].src = T.new
  inc t.len

proc add*[T: SomeData](t: var Table[T]): TableId =
  ## Adds a new item to the table using the next available id. If the table
  ## is at capacity, an `AssertionDefect` will be raised.
  doAssert t.len < t.capacity, "cannot add: table is full"
  t.insert(t.nextId)
  result = t.nextId
  t.updateNextId()

proc add*[T: SomeData](t: var Table[T], id: TableId) =
  ## Adds a new item using the given id. An `AssertionDefect` will be raised
  ## if the table is at capacity, or if the id is already in use.
  doAssert t.len < t.capacity and id notin t, "cannot add: table is full or slot is taken"
  t.insert(id)
  if t.nextId == id:
    t.updateNextId()

proc duplicate*[T: SomeData](t: var Table[T], id: TableId): TableId =
  ## Adds a copy of the item with the given id, using the next available id.
  ## An `AssertionDefect` is raised if the item to copy does not exist, or if
  ## the table is at capacity.
  doAssert id in t, "cannot duplicate: item does not exist"
  result = t.add()
  # duplicate the newly added item
  t.data[result].src[] = t.data[id].src[]

proc remove*[T: SomeData](t: var Table[T], id: TableId) =
  ## Removes the item at the given id. An `AssertionDefect` is raised if the
  ## item does not exist.
  doAssert id in t, "cannot remove: item does not exist"
  t.data[id].src = nil
  dec t.len
  if t.nextId > id:
    t.nextId = id

proc len*[T: SomeData](t: Table[T]): int =
  ## Gets the len, or number of items present in the table.
  t.len

func nextAvailableId*[T: SomeData](t: Table[T]): TableId =
  ## Gets the id that will be used next by the `add` and `duplicate` procs
  ## This id is always the lowest one available, so removing an item may
  ## lower it.
  t.nextId

func next*[T: SomeData](t: Table[T], start: TableId = 0): Option[TableId] =
  ## Queries the next available id using a starting position. If no available
  ## id was found, `none(TableId)` is returned.
  for id in start..high(TableId):
    if id in t:
      return some(id)
  none(TableId)

func wavedata*(t: WaveformTable, id: TableId): WaveData =
  ## Shortcut for getting the waveform's wavedata via id. The waveform must
  ## exist in the table, otherwise an `AssertionDefect` will be raised.
  doAssert id in t, "item does not exist"
  t.data[id].src.data

# Order

func init*(T: typedesc[Order]): Order =
  ## Value constructor for an Order. The Order is initialized with a single
  ## row all having a track id of 0.
  Order(
    data: @[[0u8, 0, 0, 0]]
  )

proc `[]`*(o: Order, index: Natural): OrderRow =
  ## Access the order via row index. `index` must be in range of `0..o.len-1`
  o.data[index]

proc `[]=`*(o: var Order, index: Natural, val: OrderRow) =
  ## Modifies the order row via a row index. `index` must be in range of
  ## `0..o.len-1`
  o.data[index] = val

proc data*(o: Order): lent seq[OrderRow] =
  ## Gets the Order's data, a sequence of OrderRows
  o.data

proc `data=`*(o: var Order, data: sink seq[OrderRow]) =
  ## Assigns the Order's data to the given sequence. `data.len` must be in
  ## the range of a `PositiveByte<#PositiveByte>`_, otherwise an
  ## `AssertionDefect` will be raised.
  doAssert data.len in PositiveByte.low..PositiveByte.high, "cannot assign data, len must be in 1..256"
  o.data = data

proc len*(o: Order): int =
  ## Gets the len, or number of rows in the order.
  o.data.len

proc nextUnused*(o: Order): OrderRow =
  ## Finds an OrderRow with each of its track ids being the lowest one that
  ## has not been used in the entire order.
  result = [0u8, 0u8, 0u8, 0u8]
  for track in ChannelId:
    var idmap: set[uint8]
    for row in o.data:
      idmap.incl(row[track])
    for id in low(uint8)..high(uint8):
      if not idmap.contains(id):
        result[track] = id
        break

proc insert*(o: var Order, row: OrderRow, before: ByteIndex = 0) =
  ## Inserts a row into the order before the given index. An `AssertionDefect`
  ## will be thrown if the order is at max capacity.
  doAssert o.data.len < OrderSize.high, "cannot insert: Order is full"
  o.data.insert(row, before)

proc insert*(o: var Order, data: openarray[OrderRow], before: ByteIndex) =
  ## Inserts multiple rows before the given index. An `AssertionDefect` will
  ## be thrown if the order does not have the capacity for `data`.
  doAssert o.data.len + data.len <= OrderSize.high, "cannot insert: not enough room in Order"
  o.data.insert(data, before)

proc remove*(o: var Order, index: ByteIndex, count: OrderSize = 1) =
  ## Removes a given number of rows at the given index. An `AssertionDefect`
  ## will be raised if this operation results in the order having 0 rows.
  doAssert o.data.len > count, "cannot remove: Order must always have 1 row"
  o.data.delete(index.int..(index + count - 1))

proc setLen*(o: var Order, len: OrderSize) =
  ## Resizes the order to the given size
  o.data.setLen(len)

proc swap*(o: var Order, i1, i2: ByteIndex) =
  ## Swaps the rows at the given indices
  swap(o.data[i1], o.data[i2])

# TrackRow

func queryNote*(row: TrackRow): Option[uint8] =
  ## Gets the note index of the row if set, otherwise `none` is returned.
  if row.note > 0:
    return some(row.note - 1)
  else:
    return none(uint8)

func queryInstrument*(row: TrackRow): Option[uint8] =
  ## Gets the instrument index of the row if set, otherwise `none` is returned.
  if row.instrument > 0:
    return some(row.instrument - 1)
  else:
    return none(uint8)

func isEmpty*(row: TrackRow): bool =
  ## Determine if the row is empty, or has all columns unset.
  #cast[uint64](row) == 0u64
  row == default(TrackRow)

# Track

func `==`*(lhs, rhs: Track): bool =
  lhs.len == rhs.len and deepEquals(lhs.data, rhs.data)

func `==`*(lhs, rhs: TrackView): bool {.borrow.}

proc init*(T: typedesc[Track], len: TrackLen): Track =
  ## Value constructor for a Track with the given length. All rows in the
  ## returned Track are empty.
  Track(
    data: TrackData.new,
    len: len
  )

func init*(T: typedesc[Track], view: TrackView): Track =
  ## Value constructor for a Track by deep copying the TrackView. The track
  ## returned has the same data as the view, but can now be mutated.
  if view.data != nil:
    result.data = TrackData.new
    result.data[] = view.data[]
    result.len = view.len

func init(T: typedesc[Track], data: ref TrackData, len: TrackLen): Track =
  Track(
    data: data,
    len: if data == nil: TrackLen.low else: len
  )

template init(T: typedesc[TrackView], data: ref TrackData, len: TrackLen): TrackView =
  cast[TrackView](Track.init(data, len))

func init*(T: typedesc[TrackView], track: sink Track): TrackView =
  ## Value constructor for a TrackView by shallow copying the given Track.
  ## While the returned TrackView is immutable, its data can be mutated if
  ## a Track still refers to this data.
  result.data = track.data
  result.len = track.len

template get(t: Track | var Track, i: ByteIndex): untyped =
  t.data[][i]

func `[]`*(t: Track, i: ByteIndex): TrackRow =
  ## Gets the `i`th row in the track.
  t.get(i)

func `[]`*(t: TrackView, i: ByteIndex): TrackRow {.borrow.}

proc `[]`*(t: var Track, i: ByteIndex): var TrackRow =
  ## Gets the `i`th row in the track, allowing mutations.
  t.get(i)

proc `[]=`*(t: var Track, i: ByteIndex, v: TrackRow) =
  ## Replaces the `i`th row in the track with the given one.
  t.get(i) = v

func isValid*(t: Track): bool =
  ## Determines if the track is valid, or if the track has a reference to
  ## the track data.
  t.data != nil

func isValid*(t: TrackView): bool {.borrow.}

template itemsImpl(t: Track | var Track): untyped =
  for i in 0..<t.len:
    yield t.get(i)

iterator items*(t: Track): TrackRow =
  ## Convenience iterator for iterating every row in the track.
  itemsImpl(t)

iterator items*(t: TrackView): TrackRow {.borrow.}

iterator mitems*(t: var Track): var TrackRow =
  ## Convenience iterator for iterating every row in the track,
  ## allowing mutations.
  itemsImpl(t)

proc setNote*(t: var Track, i: ByteIndex, note: uint8) =
  ## Sets the note index at the `i`th row to the given note index
  t.get(i).note = note + 1

proc setInstrument*(t: var Track, i: ByteIndex, instrument: TableId) =
  ## Sets the instrument index at the `i`th row to the given instrument
  t.get(i).instrument = instrument + 1

proc setEffect*(t: var Track, i: ByteIndex, effectNo: EffectIndex, et: EffectType, param = 0u8) =
  ## Sets the effect type and parameter at the `i`th row and `effectNo` column.
  t.get(i).effects[effectNo] = Effect(effectType: et.uint8, param: param)

proc setEffectType*(t: var Track, i: ByteIndex, effectNo: EffectIndex, et: EffectType) =
  ## Sets the effect type at the `i`th row and `effectNo` column.
  t.get(i).effects[effectNo].effectType = et.uint8

proc setEffectParam*(t: var Track, i: ByteIndex, effectNo: EffectIndex, param: uint8) =
  ## Sets the effect parameter at the `i`th row and `effectNo` column.
  t.get(i).effects[effectNo].param = param

func totalRows*(t: Track): int =
  ## Gets the total number of rows that are non-empty.
  for row in t:
    if not row.isEmpty():
      inc result

func totalRows*(t: TrackView): int {.borrow.}

# TrackMap

proc clear(m: var TrackMap) =
  for table in m.data.mitems:
    table.clear()

proc put(m: var TrackMap, ch: ChannelId, order: ByteIndex, val: sink ref TrackData) =
  m.data[ch][order] = EqRef[TrackData](src: val)

func get(m: TrackMap, ch: ChannelId, order: ByteIndex): ref TrackData =
  m.data[ch].getOrDefault(order).src

proc getAlways(m: var TrackMap, ch: ChannelId, order: ByteIndex): ref TrackData =
  result = m.get(ch, order)
  if result == nil:
    result = TrackData.new
    m.put(ch, order, result)

func len(m: TrackMap): int =
  for t in m.data:
    result += t.len

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

func init*(T: typedesc[Song]): Song =
  ## Value constructor for a new Song. The returned song is initialized with
  ## default settings.
  Song.construct

func new*(T: typedesc[Song]): ref Song =
  ## Ref constructor for a new Song. Same initialization logic as `init`.
  (ref Song).construct

func new*(T: typedesc[Song], song: Song): ref Song =
  ## Ref constructor for a new song, copying the given `song`.
  (ref Song)(
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
  ## Removes all tracks for each channel in the song.
  s.tracks.clear()

proc speedToFloat*(speed: Speed): float =
  ## Converts a fixed point speed to floating point.
  speed.float * (1.0 / (1 shl speedFractionBits))

proc speedToTempo*(speed: float, rowsPerBeat: PositiveByte, framerate: float): float =
  ## Calculates the tempo, in beats per minute, from a speed. `rowsPerBeat` is
  ## the number of rows in the pattern that make a single beat. `framerate`
  ## is the update rate of music playback, in hertz.
  (framerate * 60.0) / (speed * rowsPerBeat.float)

# proc getTrack(s: var Song, ch: ChannelId, order: ByteIndex): ptr Track =
#     if order notin s.tracks[ch]:
#         s.tracks[ch][order] = Track.init(s.trackLen).toShallow
#     s.tracks[ch].withValue(order, t):
#         # pointer return and not var since we cannot prove result will be initialized
#         # nil should never be returned though
#         result = t.src.addr

# template getShallowTrack(s: Song, ch: ChannelId, order: ByteIndex): Shallow[Track] =
#     s.tracks[ch].getOrDefault(order)

func getTrackView*(s: Song, ch: ChannelId, order: ByteIndex): TrackView =
  ## Gets a copy of the track for the given channel and track id. If there is
  ## no track for this address, an invalid Track is returned. Note that this
  ## proc returns a copy! For non-copying access use the viewTrack template.
  result.data = s.tracks.get(ch, order)
  result.len = s.trackLen

func getTrack*(s: var Song, ch: ChannelId, order: ByteIndex): Track =
  Track.init(s.tracks.getAlways(ch, order), s.trackLen)

iterator trackIds*(s: Song, ch: ChannelId): ByteIndex =
  ## Iterates all of tracks contained in this song, yielding their id.
  for id in s.tracks.data[ch].keys:
    yield id

proc getRow*(s: var Song, ch: ChannelId, order, row: ByteIndex): var TrackRow =
  ## same as `getRow<#getRow,Song,ChannelId,ByteIndex,ByteIndex_2>`_ but
  ## allows the returned row to be mutated. As a result of this if the track
  ## did not exist beforehand, it will be added.
  s.tracks.getAlways(ch, order)[][row]

proc getRow*(s: Song, ch: ChannelId, order, row: ByteIndex): TrackRow =
  ## Gets the track row for the channel, order row (pattern id), and row in the
  ## pattern. If there was no such row, an empty row is returned.
  let data = s.tracks.get(ch, order)
  if data != nil:
    data[][row]
  else:
    TrackRow()

func totalTracks*(s: Song): int =
  ## Gets the total number of tracks from all channels in this song.
  s.tracks.len

proc setTrack*(s: var Song, ch: ChannelId, order: ByteIndex, track: sink Track) =
  ## Puts the given track into the song for the given channel and order.
  if track.isValid():
    s.tracks.put(ch, order, track.data)

proc estimateSpeed*(s: Song, tempo, framerate: float): Speed =
  ## Calculate the closest speed value for the given `tempo`, in beats per
  ## minute, and `framerate` in hertz.
  let speedFloat = speedToTempo(tempo, s.rowsPerBeat, framerate)
  let speed = round(speedFloat * (1 shl speedFractionBits).float).uint8
  result = clamp(speed, low(Speed), high(Speed))

proc tempo*(s: Song, framerate: float): float =
  ## Gets the tempo, in beats per minute, for the song using the given
  ## `framerate`, in hertz.
  result = speedToTempo(speedToFloat(s.speed), s.rowsPerBeat, framerate)

template editTrack*(s: var Song, ch: ChannelId, trackId: ByteIndex, value, body: untyped): untyped =
  ## Edit a channel's track in place via its track id. `value` is the
  ## name of the template that returns a `var Track` of the track to edit
  ## that is accessible in `body`.
  ## 
  runnableExamples:
    var song = Song.init()
    song.editTrack(ch3, 0, track):
      track.setNote(1, 10)
      track.setInstrument(4, 0)
    song.viewTrack(ch3, 0, track):
      doAssert track[1].note == 11
      doAssert track[4].instrument == 1
  block:
    var track = s.getTrack(ch, trackId)
    template value(): var Track {.inject, used.} = track
    body

template viewTrack*(s: Song, ch: ChannelId, trackId: ByteIndex, value, body: untyped): untyped =
  ## Similar to `editTrack<#editTrack.t,Song,ChannelId,ByteIndex,untyped,untyped>`_
  ## but instead only provides read-only access to a track, in place.
  ## `value` is the name of the template that returns a `lent Track` of the
  ## track to view that is accessible in `body`.
  ## 
  ## If the track does not exist, then `value` will refer to an invalid track,
  ## or a track with 0 rows.
  ## 
  ## See the example in `editTrack<#editTrack.t,Song,ChannelId,ByteIndex,untyped,untyped>`_
  ## for example usage.
  ## 
  block:
    let track = s.getTrackView(ch, trackId)
    template value(): lent TrackView {.inject, used.} = track
    body

template editPattern*(s: var Song, orderNo: ByteIndex, value, body: untyped): untyped =
  ## Edits an entire pattern in place for the given `orderNo` or index in the
  ## song order. `value` is the name of the template that returns a `var Track`
  ## in the pattern for a given `ChannelId`, which is accessible in `body`.
  ## 
  runnableExamples:
    var song = Song.init()
    # edit the first pattern such that:
    #  - the first row in ch1's track has the note set to D#2
    #  - the first row in ch2's track has effect#2 set to etTuning with a param of 0x82
    song.editPattern(0, pattern):
      pattern(ch1).setNote(0, 3)
      pattern(ch2).setEffect(0, 1, etTuning, 0x82)
    song.viewPattern(0, pattern):
      doAssert pattern(ch1)[0] == TrackRow(note: 0x4u8)
      const expected = block:
        var row: TrackRow
        row.effects[1] = Effect(effectType: etTuning.ord.uint8, param: 0x82)
        row
      doAssert pattern(ch2)[0] == expected
  block:
    var pattern: array[ChannelId, Track] = block:
      let orderRow = s.order[orderNo]
      [
        s.getTrack(ch1, orderRow[ch1]),
        s.getTrack(ch2, orderRow[ch2]),
        s.getTrack(ch3, orderRow[ch3]),
        s.getTrack(ch4, orderRow[ch4])
      ]
    template value(ch: ChannelId): var Track {.inject, used.} = pattern[ch]
    body

template viewPattern*(s: Song, orderNo: ByteIndex, value, body: untyped): untyped =
  ## Similar to `editPattern<#editPattern.t,Song,ByteIndex,untyped,untyped>`_
  ## but instead only provides read-only access to all tracks in the pattern.
  ## `value` is the name of the template that returns a `lent Track` in the
  ## pattern for a given `ChannelId`, which is accessible in `body`.
  ## 
  ## Same as `viewTrack<#viewTrack.t,Song,ChannelId,ByteIndex,untyped,untyped>`_, if
  ## any track in the pattern does not exist, an invalid one will take its
  ## place.
  ## 
  ## See the example in `editPattern<#editPattern.t,Song,ByteIndex,untyped,untyped>`_
  ## for example usage.
  ## 
  block:
    let pattern: array[ChannelId, TrackView] = block:
      let orderRow = s.order[orderNo]
      [
        s.getTrackView(ch1, orderRow[ch1]),
        s.getTrackView(ch2, orderRow[ch2]),
        s.getTrackView(ch3, orderRow[ch3]),
        s.getTrackView(ch4, orderRow[ch4])
      ]
    template value(ch: ChannelId): lent TrackView {.inject, used.} = pattern[ch]
    body

func patternLen*(s: Song, order: ByteIndex): Natural =
  ## Gets the length, in rows, of a pattern taking effects into consideration.
  ## If no pattern jump/halt effect is used then the track length is returned.
  ## 
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

func init*(T: typedesc[SongList], len: PositiveByte = 1): SongList =
  ## Value constructor for a new SongList. `len` is the number of new songs
  ## to initialize the list with.
  ## 
  result = SongList(
    data: newSeq[EqRef[Song]](len)
  )
  for songref in result.data.mitems:
    songref.src = Song.new

proc `[]`*(l: var SongList, i: ByteIndex): ref Song =
  ## Gets a mutable reference to the song at the `i`th index in the list.
  ## 
  l.data[i].src

func `[]`*(l: SongList, i: ByteIndex): Immutable[ref Song] =
  ## Gets an immutable reference to the song at the `i`th index in the list.
  ## 
  l.data[i].src.toImmutable

proc `[]=`*(l: var SongList, i: ByteIndex, s: ref Song) =
  ## Replaces the song at the `i`th index in the list with `s`. An
  ## `AssertionDefect` will be raised if `s` was `nil`.
  ##
  doAssert s != nil, "cannot replace the song with nil!"
  l.data[i].src = s

proc canAdd(l: SongList) =
  doAssert l.data.len < 256, "SongList cannot have more than 256 songs"

proc add*(l: var SongList) =
  ## Adds a new song to the end of the list. An `AssertionDefect` will be
  ## raised if the list is at maximum capacity.
  ## 
  l.canAdd()
  l.data.add(Song.new.toEqRef)

proc add*(l: var SongList, song: ref Song) =
  ## Adds `song` to the end of the list. An `AssertionDefect` will be raised
  ## if the list is at maximum capacity or if `song` was `nil`.
  ## 
  doAssert song != nil, "cannot add a nil song!"
  l.canAdd()
  l.data.add(song.toEqRef)

proc duplicate*(l: var SongList, i: ByteIndex) =
  ## Duplicates the song at the `i`th index in the list and adds it to the
  ## end of the list. An `AssertionDefect` is raised if the list is at
  ## maximum capacity.
  ## 
  l.canAdd()
  l.data.add( Song.new( l.data[i].src[] ).toEqRef )

proc remove*(l: var SongList, i: ByteIndex) =
  ## Removes the song at the `i`th index in the list. An `AssertionDefect` is
  ## raised if removing the song will result in an empty list.
  ## 
  doAssert l.data.len > 1, "SongList must have at least 1 song"
  l.data.delete(i)

proc moveUp*(l: var SongList, i: ByteIndex) =
  ## Moves the song at the `i`th index in the list up one. Or, swaps the
  ## locations of the songs at `i` and `i-1` in the list. An `IndexDefect` is
  ## raised if `i` is 0, or the topmost item.
  ## 
  if i == 0:
    raise newException(IndexDefect, "cannot move topmost item up")
  swap(l.data[i], l.data[i - 1])

proc moveDown*(l: var SongList, i: ByteIndex) =
  ## Moves the song at the `i`th index in the list down one. Or, swaps the
  ## locations of the songs at indices `i` and `i+1` in the list. An
  ## `IndexDefect` is raised if `i` is the last index in the list, or the
  ## bottommost item.
  ## 
  if i == l.data.len - 1:
    raise newException(IndexDefect, "cannot move bottomost item down")
  swap(l.data[i], l.data[i + 1])

proc len*(l: SongList): Natural =
  ## Gets the length of the list, or number of songs it contains.
  ##
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
      version: currentVersion,
      revisionMajor: currentFileMajor,
      revisionMinor: currentFileMinor
    )
  )

func init*(T: typedesc[Module]): Module =
  ## Value constructor for a new module. The returned module has:
  ##  
  ## - 1 empty song
  ## - an empty instrument and waveform table
  ## - empty comments and artist information
  ## - system set to `systemDmg`
  ## - version information with the current application version and file revision
  ## 
  Module.construct

func new*(T: typedesc[Module]): ref Module =
  ## Ref constructor for a new module. Same behavior as `init`.
  ##
  (ref Module).construct

func version*(m: Module): Version =
  ## Gets the version information that created this module. Modules
  ## initialized from `init` or `new` will have this set to `appVersion`.
  ## 
  m.private.version

func revisionMajor*(m: Module): int =
  ## Gets the file revision major the module was deserialized from. Modules
  ## initialized from `init` or `new` will have this set to `fileMajor`.
  ## 
  m.private.revisionMajor

func revisionMinor*(m: Module): int = 
  ## Gets the file revision minor the module was deserialized from. Modules
  ## initialized from `init` or `new` will have this set to `fileMinor`.
  ## 
  m.private.revisionMinor

func framerate*(m: Module): float =
  ## Gets the framerate, in hertz, as a floating point.
  ##
  case m.system:
  of systemDmg:
    result = 59.7f
  of systemSgb:
    result = 61.1f
  of systemCustom:
    result = m.customFramerate.float

converter toInfoString*(str: string): InfoString =
  ## Implicit conversion of a `string` to an `InfoString`. Only the first
  ## 32 characters of `str` are copied if `str.len` is greater than 32.
  ##
  for i in 0..<min(str.len, result.len):
    result[i] = str[i]

func `==`*(a, b: SongList): bool =
  ## Equality test for two song lists. Uses deep equality checking.
  a.data == b.data

func `==`*(a, b: SomeTable): bool =
  ## Equality test for two tables. Uses deep equality checking.
  bind utils.`==`, deepEquals
  system.`==`(a, b)
