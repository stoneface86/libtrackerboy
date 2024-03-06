##[

Module for the data model. This module contains data types used in the library.

]##

import
  ./common,
  ./notes,
  ./version,
  ./private/data,
  ./private/utils

import std/[hashes, math, options, sequtils, strutils, tables]

export common, options

const
  speedFractionBits = 4
  unitSpeed* = 1 shl speedFractionBits
    ## Constant for a speed value that is exactly 1 frame/row
    ##

type
  TableId* = range[0u8..63u8]
    ## Integer ID type for items in an InstrumentTable or WaveformTable.
    ##

  SequenceSize* = range[0..high(uint8).int]
    ## Size range a sequence's data can be.
    ##

  OrderSize* = PositiveByte
    ## Size range of a song order.
    ##
  
  TrackLen* = PositiveByte
    ## Size range of a Track
    ##
  
  TrackId* = uint8
    ## Integer ID type for a Track in a Song.
    ##
  
  OrderId* = uint8
    ## Integer ID type for an OrderRow in an Order.
    ##

  Speed* = range[unitSpeed.uint8..(high(uint8)+1-unitSpeed).uint8]
    ## Range of a Song's speed setting. Note that speed is in units of
    ## frames/row and is in fixed point format (Q4.4)
    ##

  EffectIndex* = range[0..2]
    ## Index type for an Effect in a TrackRow.
    ##
  
  EffectColumns* = range[1u8..3u8]
    ## Range for the number of columns that are visible for a track.
    ##
  
  EffectCounts* = array[4, EffectColumns]
    ## Number of effects to display for each channel.
    ##

  WaveData* = array[16, uint8]
    ## Waveform data. A waveform consists of 16 bytes, with each byte
    ## containing 2 4-bit PCM samples. The first sample is the upper nibble
    ## of the byte, with the second being the lower nibble.
    ##

  SequenceKind* = enum
    ## Enumeration for the kinds of parameters a sequence can operate on.
    ## An `Instrument` has a `Sequence` for each one of these kinds.
    ##
    skArp
    skPanning
    skPitch
    skTimbre
    skEnvelope

  Sequence* = object
    ## A sequence is a sequence of parameter changes with looping capability.
    ## (Not to be confused with a Nim sequence, `seq[T]`).
    ##
    loopIndex*: Option[ByteIndex]
      ## If set, the sequence will loop to this index at the end. If unset
      ## or the index exceeds the bounds of the sequence data, the sequence
      ## will stop at the end instead.
      ##
    data: seq[uint8]

  Instrument* = object
    ## Container for a Trackerboy instrument. An instrument provides frame
    ## level control of a channel's parameters and is activated on each
    ## note trigger.
    ##
    name*: string
      ## Optional name of the instrument.
      ##
    channel*: ChannelId
      ## Channel this instrument is to be previewed on. Note that instruments
      ## can be used on any channel, so this field is purely informational.
      ##
    sequences*: array[SequenceKind, Sequence]
      ## Sequence data for this instrument.
      ##

  Waveform* = object
    ## Container for a waveform to use on CH3.
    ##
    name*: string
      ## Optional name of the waveform.
      ##
    data*: WaveData
      ## The waveform data.
      ##

  SomeData* = Instrument|Waveform
    ## Type class matching data that is contained in a Table.
    ##

  Table[T: SomeData] = object
    nextId: TableId
    len: int
    data: array[TableId, EqRef[T]]

  InstrumentTable* = Table[Instrument]
    ## Container for Instruments. Up to 64 Instruments can be stored in this
    ## table and is addressable via a TableId.
    ##
  
  WaveformTable* = Table[Waveform]
    ## Container for Waveforms. Up to 64 Waveforms can be stored in this
    ## table and is addressable via a TableId.
    ##

  SomeTable* = InstrumentTable|WaveformTable
    ## Type class for a Table type.
    ##

  # song order

  OrderRow* = array[ChannelId, TrackId]
    ## An OrderRow is a set of TrackIds, one for each channel.
    ##
  
  Order* = object
    ## An Order is a sequence of OrderRows, that determine the layout of
    ## a Song. Each Order must have at least 1 OrderRow and no more than
    ## 256 rows.
    ##
    data*: seq[OrderRow]

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
    ##
    effectType*: uint8
      ## Type of the effect, should be in range of the EffectType enum,
      ## unknown types are ignored.
      ##
    param*: uint8
      ## Effect parameter byte, only needed for certain types.
      ##

  Column = distinct uint8
    ## Column value in a TrackRow, as a biased uint8. An unset column is 0, and
    ## a column with a value of 0 is 1, value of 1 is 2, etc

  NoteColumn* = distinct Column
    ## Column in a [TrackRow] that contains the an optional note value.
    ##

  InstrumentColumn* = distinct Column
    ## Column in a [TrackRow] that contains an optional instrument to use.
    ##

  TrackRow* {.packed.} = object
    ## A single row of data in a Track. Guaranteed to be 8 bytes.
    ##
    note*: NoteColumn
      ## The note index to trigger with a bias of 1 (0 means unset).
      ##
    instrument*: InstrumentColumn
      ## The index of the instrument to set with a bias of 1 (0 means unset).
      ##
    effects*: array[EffectIndex, Effect]
      ## 3 available effect columns
      ##

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

  TrackView* = object
    ## Same as track, but only provides immutable access to the track data.
    ## Mutable access can be acquired by converting the view to a Track via
    ## the Track.init overload, while making a deep copy of the data.
    ##
    track: Track

  SomeTrack* = Track | TrackView
    ## Type class for all Track types.
    ##


  TrackMap = object
    data: array[ChannelId, tables.Table[ByteIndex, EqRef[TrackData]]]
  
  PatternRow* = array[ChannelId, TrackRow]
    ## A full row in a pattern is a [TrackRow] for each track/channel.
    ##

  System* = enum
    ## Enumeration for types of systems the module is for. The system
    ## determines the vblank interval, or tick rate, of the engine.
    ##
    systemDmg       ## DMG/CGB system, 59.7 Hz
    systemSgb       ## SGB system, 61.1 Hz
    systemCustom    ## Custom tick rate

  Tickrate* = object
    ## Defines the tickrate, or interval in which a single tick or step of a
    ## song when playing back.
    ##
    system*: System
      ## Use a predefined system's tick rate
      ##
    customFramerate*: float32
      ## Custom tick rate when `system = systemCustom`
      ##

  # Song

  Song* {.requiresInit.} = object
    ## Song type. Contains track data for a single song.
    ##
    name*: string
      ## Name of the song.
      ##
    rowsPerBeat*: ByteIndex
      ## Number of rows that make up a beat. Used for tempo calculation
      ## and by the front end for row highlights.
      ##
    rowsPerMeasure*: ByteIndex
      ## Number of rows that make up a measure. Used only by the front
      ## end for row highlights.
      ##
    speed*: Speed
      ## Starting speed of the song when playing back, in frames/row.
      ##
    effectCounts*: array[4, EffectColumns]
      ## Effect columns visible counts. To be used by the front end for
      ## the number of effect columns shown for each channel.
      ##
    order*: Order
      ## The song's Order
      ##
    trackLen*: TrackLen
      ## The number of rows each track in the song is.
      ##
    tracks: TrackMap
    tickrate*: Option[Tickrate]
      ## Tickrate override for this song. If set to none, the module's tickrate
      ## should be used instead.
      ##

  SongPos* = object
    ## Song position. This object contains the starting position of a song.
    ## By default the starting position is the first pattern and first row,
    ## which are both 0.
    ## * `pattern` - The index in the song's order of the pattern.
    ## * `row` - The index of the row to start at.
    ##
    pattern*: int
    row*: int 

  SongSpan* = object
    ## References a span in a song, or a range of rows within a pattern in
    ## a song.
    ## * `pos` - The starting position of the span.
    ## * `rows` - The amount of rows from `pos` included in the span.
    ##
    pos*: SongPos
    rows*: int

  SongList* {.requiresInit.} = object
    ## Container for songs. Songs stored in this container are references,
    ## like InstrumentTable and WaveformTable. A SongList can contain 1-256
    ## songs.
    ##
    data: seq[EqRef[Song]]

  InfoString* = array[32, char]
    ## Fixed-length string of 32 characters, used for artist information.
    ##

  ModulePiece* = Instrument|Song|Waveform
    ## Type class for an individual component of a module.
    ##

  # Module
  Module* {.requiresInit.} = object
    ## A module is a container for songs, instruments and waveforms.
    ## Each module can store up to 256 songs, 64 instruments and 64
    ## waveforms. Instruments and Waveforms are shared between all songs.
    ##
    songs*: SongList
      ## The list of songs for this module.
      ##
    instruments*: InstrumentTable
      ## The module's instrument table, shared with all songs
      ##
    waveforms*: WaveformTable
      ## The module's waveform table, shared with all songs
      ##

    title*, artist*, copyright*: InfoString
      ## Optional information about the module
      ##

    comments*: string
      ## Optional comment information about the module
      ##
    tickrate*: Tickrate
      ## Tickrate used by all songs in the module.
      ##

    private*: ModulePrivate
      ## Internal details only accessible to the library, do not use!
      ##

const
  defaultRpb* = 4
    ## Default `rowsPerBeat` setting for new `Songs <#Song>`_
    ##
  
  defaultRpm* = 16
    ## Default `rowsPerMeasure` setting for new `Songs <#Song>`_
    ##
  
  defaultSpeed*: Speed = 0x60
    ## Default `speed` setting for new `Songs <#Song>`_. The
    ## default is 6.0 frames/row or approximately 160 BPM.
    ##
  
  defaultTrackSize*: TrackLen = 64
    ## Default length of a Track for new `Songs <#Song>`_.
    ##
  
  defaultTickrate* = Tickrate(
    system: systemDmg,
    customFramerate: 30
  )
    ## Default tickrate setting for new Modules.
    ##

  effectCharMap*: array[EffectType, char] = [
    '?', # etNoEffect
    'B', # etPatternGoto
    'C', # etPatternHalt
    'D', # etPatternSkip
    'F', # etSetTempo
    'T', # etSfx
    'E', # etSetEnvelope
    'V', # etSetTimbre
    'I', # etSetPanning
    'H', # etSetSweep
    'S', # etDelayedCut
    'G', # etDelayedNote
    'L', # etLock
    '0', # etArpeggio
    '1', # etPitchUp
    '2', # etPitchDown
    '3', # etAutoPortamento
    '4', # etVibrato
    '5', # etVibratoDelay
    'P', # etTuning
    'Q', # etNoteSlideUp
    'R', # etNoteSlideDown
    'J'  # etSetGlobalVolume
  ]
    ## Array that maps an [EffectType] to a `char`. Each effect is represented
    ## by a letter or number as its type when displayed in a tracker.
    ##

{. push raises: [] .}

func hertz*(t: Tickrate): float =
  ## Converts the given tickrate to a rate in hertz.
  ## 
  case t.system
  of systemDmg:
    result = 59.7
  of systemSgb:
    result = 61.1
  of systemCustom:
    result = t.customFramerate

func init*(T: typedesc[Effect]; et = etNoEffect; param = 0u8): Effect =
  ## Initialize an Effect column with the given type and parameter.
  ##
  result = Effect(effectType: uint8(ord(et)), param: param)

func effectTypeShortensPattern*(et: EffectType): bool =
  ## Determines if the given effect type will shorten the runtime length of
  ## a pattern by either halting the song or jumping to a new pattern.
  ## 
  result = et == etPatternHalt or
       et == etPatternSkip or
       et == etPatternGoto

func toEffectType*(x: uint8): EffectType =
  ## Converts a uint8 to an EffectType enum safely. etNoEffect is returned if
  ## x is not in the range of EffectType.
  ## 
  if x.int in EffectType.low.ord..EffectType.high.ord:
    x.EffectType
  else:
    etNoEffect

func effectTypeToChar*(et: uint8): char =
  ## Get a `char` representation for the given effect type value. For any
  ## unrecognized effect, `?` is returned.
  ##
  result = effectCharMap[toEffectType(et)]

func `$`*(e: Effect): string =
  ## Stringify an [Effect]. The string returned is the canonical representation
  ## of the effect in a tracker column.
  ##
  result.add(effectTypeToChar(e.effectType))
  result.add(toHex(e.param))

# Sequence

func init*(T: typedesc[Sequence]; data: openArray[uint8]; 
           loopIndex = none(ByteIndex)
          ): Sequence =
  ## Creates a sequence with an optional loop index and data. `data.len` must
  ## be <= 256!
  ##
  doAssert data.len <= 256, "cannot init Sequence: data is too big"
  result.loopIndex = loopIndex
  result.data = @data

func `[]`*(s: Sequence; i: ByteIndex): uint8 =
  ## Gets the `i`th element in the sequence
  ## 
  s.data[i]

proc `[]=`*(s: var Sequence; i: ByteIndex; val: uint8) =
  ## Sets the `i`th element in the sequence to the given `val`
  ## 
  s.data[i] = val

proc setLen*(s: var Sequence; len: SequenceSize) =
  ## Sets the length of the Sequence `s` to the given `len`.
  ## 
  s.data.setLen(len)

func len*(s: Sequence): int =
  ## Gets the length of the sequence
  ## 
  s.data.len

func data*(s: Sequence): lent seq[uint8] =
  ## Gets the sequence's data
  s.data

proc `data=`*(s: var Sequence; data: sink seq[uint8]) =
  ## Assigns the sequence's data to the given uint8 sequence. `data.len` must
  ## not exceed 256 or an `AssertionDefect` will be raised.
  ##
  doAssert data.len <= 256, "cannot set data: sequence is too big"
  s.data = data

# Instrument

func init*(T: typedesc[Instrument]): Instrument =
  ## Value constructor for an Instrument. Default initialization is used, so
  ## the instrument's channel is ch1, and all its sequences are empty.
  ## 
  defaultInit()

func new*(T: typedesc[Instrument]): ref Instrument =
  ## Ref constructor for an Instrument. Same behavior as `init`.
  ## 
  new(result)

func hash*(i: Instrument): Hash =
  ## Calculate a hash code for an instrument.
  ##
  result = hash(i.sequences)

func `==`*(a, b: Instrument; ): bool =
  ## Determine if two instruments are **functionally** equivalent.
  ## Informational data of the instruments are not tested.
  ##
  result = a.sequences == b.sequences

# Waveform

func init*(T: typedesc[Waveform]): Waveform =
  ## Value constructor for a Waveform. The returned Waveform's wave data is
  ## cleared.
  ## 
  defaultInit()

func new*(T: typedesc[Waveform]): ref Waveform =
  ## Ref contructor for a Waveform. Same behavior as `init`
  ## 
  new(result)

func hash*(x: Waveform): Hash =
  ## Calculates a hash code for a Waveform. Only the waveform's wave data is
  ## used when calculating the hash.
  ##
  template data(i: int): uint64 =
    cast[array[2, uint64]](x.data)[i]
  result = !$(hash(data(0)) !& hash(data(1)))

func `==`*(a, b: Waveform; ): bool =
  ## Determines if two waveforms are **functionally** equivalent, or if they
  ## have the same wave data.
  ##
  result = a.data == b.data

# Table

func init*(T: typedesc[SomeTable]): T.typeOf =
  ## Value constructor for a new table. The returned table is empty.
  ## 
  defaultInit()

func contains*[T: SomeData](t: Table[T]; id: TableId): bool =
  ## Determines if the table contains an item with the `id`
  ## 
  t.data[id].src != nil

proc updateNextId[T: SomeData](t: var Table[T]) =
  for i in t.nextId..high(TableId):
    if i notin t:
      t.nextId = i
      break

proc capacity*[T: SomeData](t: Table[T]): static[int] =
  ## Maximum number of items that can be stored in a Table.
  ## 
  high(TableId).int + 1

proc `[]`*[T: SomeData](t: var Table[T]; id: TableId): ref T =
  ## Gets a ref of the item with the given id or `nil` if there is no item
  ## with that id.
  ## 
  t.data[id].src

func `[]`*[T: SomeData](t: Table[T]; id: TableId): Immutable[ref T] =
  ## Gets an immutable ref of the item with the given id or `nil` if there
  ## is no item with that id.
  ## 
  t.data[id].src.toImmutable

iterator items*[T: SomeData](t: Table[T]): TableId {.noSideEffect.} =
  ## Iterates all items in the table, via their id, in ascending order.
  ## 
  for id in low(TableId)..high(TableId):
    if id in t:
      yield id

proc insert[T: SomeData](t: var Table[T]; id: TableId) =
  t.data[id].src = T.new
  inc t.len

proc add*[T: SomeData](t: var Table[T]): TableId =
  ## Adds a new item to the table using the next available id. If the table
  ## is at capacity, an `AssertionDefect` will be raised.
  ## 
  doAssert t.len < t.capacity, "cannot add: table is full"
  t.insert(t.nextId)
  result = t.nextId
  t.updateNextId()

proc add*[T: SomeData](t: var Table[T]; id: TableId) =
  ## Adds a new item using the given id. An `AssertionDefect` will be raised
  ## if the table is at capacity, or if the id is already in use.
  ## 
  doAssert t.len < t.capacity and id notin t, "cannot add: table is full or slot is taken"
  t.insert(id)
  if t.nextId == id:
    t.updateNextId()

proc duplicate*[T: SomeData](t: var Table[T]; id: TableId): TableId =
  ## Adds a copy of the item with the given id, using the next available id.
  ## An `AssertionDefect` is raised if the item to copy does not exist, or if
  ## the table is at capacity.
  ## 
  doAssert id in t, "cannot duplicate: item does not exist"
  result = t.add()
  # duplicate the newly added item
  t.data[result].src[] = t.data[id].src[]

proc remove*[T: SomeData](t: var Table[T]; id: TableId) =
  ## Removes the item at the given id. An `AssertionDefect` is raised if the
  ## item does not exist.
  ## 
  doAssert id in t, "cannot remove: item does not exist"
  t.data[id].src = nil
  dec t.len
  if t.nextId > id:
    t.nextId = id

proc len*[T: SomeData](t: Table[T]): int =
  ## Gets the len, or number of items present in the table.
  ##
  t.len

func nextAvailableId*[T: SomeData](t: Table[T]): TableId =
  ## Gets the id that will be used next by the `add` and `duplicate` procs
  ## This id is always the lowest one available, so removing an item may
  ## lower it.
  ##
  t.nextId

func next*[T: SomeData](t: Table[T]; start = TableId(0)): Option[TableId] =
  ## Queries the next available id using a starting position. If no available
  ## id was found, `none(TableId)` is returned.
  ##
  for id in start..high(TableId):
    if id in t:
      return some(id)
  none(TableId)

func wavedata*(t: WaveformTable; id: TableId): WaveData =
  ## Shortcut for getting the waveform's wavedata via id. The waveform must
  ## exist in the table, otherwise an `AssertionDefect` will be raised.
  ##
  doAssert id in t, "item does not exist"
  t.data[id].src.data

type
  IdBuf = FixedSeq[int(TableId.high - TableId.low + 1), TableId]

func hashOf[T: SomeData](t: Table[T]; id: TableId): Hash =
  hash(t[id][])

func uniqueIds*[T: SomeData](t: Table[T]): set[TableId] =
  ## Gets a set of Ids that refer to unique data. This proc can be used to
  ## deduplicate the table's data when exporting the module. The Id chosen in
  ## the result for any set of duplicates encountered is the lowest one in the
  ## set. Ie, a Table with data set for Ids 0, 1 and 2 with equivalent data,
  ## has a uniqueIds set of `{ 0.TableId }`.
  ##
  var buf: IdBuf
  for id in t:
    buf.add(id)
  
  while buf.len > 0:
    let 
      currId = buf[0]
      currHc = hashOf(t, currId)
    
    # add this unique id
    result.incl(currId)
    
    # filter the buf in-place by removing duplicates
    let oldLen = buf.len
    buf.len = 0 # "clear" the buf, then re-add non-duplicates
    for id in 1..<oldLen:
      let nextId = buf[id]
      if currHc != hashOf(t, nextId) or t[currId][] != t[nextId][]:
        # these ids are not the same, add to buf
        buf.add(nextId)

# Order

func initOrder*(): Order =
  ## Initializes a default Order. The default Order contains one row with all
  ## track ids set to 0.
  ##
  result = Order(data: newSeq[OrderRow](1))

func init*(T: typedesc[Order]): Order {.deprecated: "use initOrder instead".} =
  result = initOrder()

func initOrder*(data: openArray[OrderRow]): Order =
  ## Initializes an Order with the given array of rows.
  ## 
  result = Order(data: @data)

func isValid*(o: Order): bool =
  result = o.data.len in low(OrderSize)..high(OrderSize)

proc `[]`*(o: Order; index: Natural): OrderRow {.inline.} =
  ## Access the order via row index. `index` must be in range of `0..o.len-1`
  ##
  o.data[index]

proc `[]=`*(o: var Order; index: Natural; val: OrderRow) {.inline.} =
  ## Modifies the order row via a row index. `index` must be in range of
  ## `0..o.len-1`
  ##
  o.data[index] = val

proc len*(o: Order): int {.inline.} =
  ## Gets the len, or number of rows in the order.
  ##
  o.data.len

proc nextUnused*(o: Order): OrderRow =
  ## Finds an OrderRow with each of its track ids being the lowest one that
  ## has not been used in the entire order.
  ##
  result = [0u8, 0u8, 0u8, 0u8]
  for track in ChannelId:
    var idmap: set[uint8]
    for row in o.data:
      idmap.incl(row[track])
    for id in low(uint8)..high(uint8):
      if not idmap.contains(id):
        result[track] = id
        break

proc setData*(o: var Order; data: openArray[OrderRow]) =
  doAssert data.len in low(OrderSize)..high(OrderSize), "cannot set data: invalid size"
  o.data.setLen(data.len)
  for i in 0..<data.len:
    o.data[i] = data[i]

proc add*(o: var Order; row: OrderRow) =
  doAssert o.data.len < OrderSize.high, "cannot add: Order is full"
  o.data.add(row)

proc insert*(o: var Order; row: OrderRow; before = ByteIndex(0)) =
  ## Inserts a row into the order before the given index. An `AssertionDefect`
  ## will be thrown if the order is at max capacity.
  ##
  doAssert o.data.len < OrderSize.high, "cannot insert: Order is full"
  o.data.insert(row, before)

proc insert*(o: var Order; data: openarray[OrderRow]; before: ByteIndex) =
  ## Inserts multiple rows before the given index. An `AssertionDefect` will
  ## be thrown if the order does not have the capacity for `data`.
  ##
  doAssert o.data.len + data.len <= OrderSize.high, "cannot insert: not enough room in Order"
  o.data.insert(data, before)

proc remove*(o: var Order; index: ByteIndex; count = OrderSize(1)) =
  ## Removes a given number of rows at the given index. An `AssertionDefect`
  ## will be raised if this operation results in the order having 0 rows.
  ##
  doAssert o.data.len > count, "cannot remove: Order must always have 1 row"
  o.data.delete(index.int..(index + count - 1))

proc setLen*(o: var Order; len: OrderSize) =
  ## Resizes the order to the given size
  ##
  o.data.setLen(len)

proc swap*(o: var Order; i1, i2: ByteIndex;) =
  ## Swaps the rows at the given indices
  ##
  swap(o.data[i1], o.data[i2])

# TrackRow ====================================================================

const
  noteNone* = NoteColumn(0)
    ## Note column value for an unset column. Same as `default(NoteColumn)`.
    ##
  instrumentNone* = InstrumentColumn(0)
    ## Instrument column value for an unset column. Same as 
    ## `default(InstrumentColumn)`.
    ##
  effectNone* = Effect.init()
    ## Effect column value for an unset effect. Same as `default(Effect)`.
    ##

func has(x: Column): bool {.inline.} =
  result = uint8(x) != 0

func value(x: Column): uint8 {.inline.} =
  result = uint8(x) - 1

func column(x: range[0u8..254u8]): Column {.inline.} =
  result = Column(x + 1)

func asOption(col: Column): Option[uint8] =
  if col.has():
    some(col.value())
  else:
    none(uint8)

func `==`(x, y: Column; ): bool {.borrow.}

func `$`(c: Column): string =
  result = "Column("
  if c.has():
    result.add($c.value())
  result.add(')')

func `$`*(c: NoteColumn): string {.borrow.}

func `$`*(c: InstrumentColumn): string {.borrow.}

func `==`*(x, y: NoteColumn; ): bool {.borrow.}
  ## Test if two note columns are equivalent.
  ##

func `==`*(x, y: InstrumentColumn; ): bool {.borrow.}
  ## Test if two instrument columns are equivalent.
  ##

func noteColumn*(index: NoteRange; ): NoteColumn =
  ## Initialize a note column with the given note index.
  ##
  result = NoteColumn(column(uint8(index)))

func noteColumn*(note: Letter; octave: Octave): NoteColumn =
  ## Initialize a note column using a note and octave pair.
  ##
  result = noteColumn((octave * 12) + note)

func instrumentColumn*(id: TableId): InstrumentColumn {.inline.} =
  ## Initialize an instrument column with the given instrument id.
  ##
  result = InstrumentColumn(column(id))

func has*(n: NoteColumn): bool {.borrow.}
  ## Test if the note column is set, or has a value.
  ##

func has*(i: InstrumentColumn): bool {.borrow.}
  ## Test if the instrument column is set, or has a value.
  ##

func value*(n: NoteColumn): uint8 {.borrow.}
  ## Get the value of the set note column. Do not use for unset columns!
  ##

func value*(i: InstrumentColumn): uint8 {.borrow.}
  ## Get the value of the set instrument column. Do not use for unset columns!
  ##

func asOption*(n: NoteColumn): Option[uint8] {.borrow.}
  ## Convert the note column to an Option.
  ##

func asOption*(n: InstrumentColumn): Option[uint8] {.borrow.}
  ## Convert the instrument column to an Option.
  ##

func init*(T: typedesc[TrackRow]; note = noteNone; instrument = instrumentNone;
           effects = [effectNone, effectNone, effectNone]
           ): TrackRow =
  ## Initialize a [TrackRow] with the given columns.
  ##
  result = TrackRow(
    note: note,
    instrument: instrument,
    effects: effects
  )

func init*(T: typedesc[TrackRow]; note = noteNone; instrument = instrumentNone;
           e1 = effectNone; e2 = effectNone; e3 = effectNone
           ): TrackRow =
  ## Initialize a [TrackRow], with each effect as a parameter.
  ##
  result = TrackRow.init(note, instrument, [e1, e2, e3])

template clearNote*(row: var TrackRow)
   {.deprecated: "set the note field directly instead" .} =
  ## Clears the note column for this row.
  ##
  row.note = noteNone

template clearInstrument*(row: var TrackRow)
  {.deprecated: "set the instrument field directly instead" .} =
  ## Clears the instrument column for this row.
  ##
  row.instrument = instrumentNone

template hasNote*(row: TrackRow): bool
 {.deprecated: "use the note field directly instead" .} =
  row.note != noteNone

template hasInstrument*(row: TrackRow): bool
  {.deprecated: "use the instrument field directly instead" .} = 
  row.instrument != instrumentNone

proc setNote*(row: var TrackRow; note: uint8) 
  {.deprecated: "set the note field directly instead" .} =
  ## Sets the note column to the given note value.
  ##
  row.note = noteColumn(note)

proc setInstrument*(row: var TrackRow; instrument: TableId) 
  {.deprecated: "set row.instrument directly instead" .} =
  ## Sets the instrument column to the given instrument id.
  ##
  row.instrument = instrumentColumn(instrument)

func queryNote*(row: TrackRow): Option[uint8]
  {.deprecated: "use row.note.asOption() instead" .} =
  ## Gets the note index of the row if set, otherwise `none` is returned.
  ##
  asOption(row.note)

func queryInstrument*(row: TrackRow): Option[uint8]
  {.deprecated: "use row.instrument.asOption() instead" .} =
  ## Gets the instrument index of the row if set, otherwise `none` is returned.
  ##
  asOption(row.instrument)

func isEmpty*(row: TrackRow): bool =
  ## Determine if the row is empty, or has all columns unset. Prefer this
  ## function over `row == default(TrackRow)` for performance.
  ##
  static: assert sizeof(uint64) == sizeof(TrackRow)
  cast[uint64](row) == 0u64

# Track =======================================================================

func `==`*(lhs, rhs: Track): bool =
  lhs.len == rhs.len and deepEquals(lhs.data, rhs.data)

proc init*(T: typedesc[Track]; len: TrackLen): Track =
  ## Value constructor for a Track with the given length. All rows in the
  ## returned Track are empty.
  ##
  Track(
    data: TrackData.new,
    len: len
  )

func init*(T: typedesc[Track]; view: TrackView): Track =
  ## Value constructor for a Track by deep copying the TrackView. The track
  ## returned has the same data as the view, but can now be mutated.
  ##
  if view.data != nil:
    result.data = TrackData.new
    result.data[] = view.data[]
    result.len = view.len

func init(T: typedesc[Track]; data: ref TrackData; len: TrackLen): Track =
  Track(
    data: data,
    len: if data == nil: TrackLen.low else: len
  )

template get(t: Track | var Track; i: ByteIndex): untyped =
  t.data[][i]

func `[]`*(t: Track; i: ByteIndex): TrackRow =
  ## Gets the `i`th row in the track.
  ##
  t.get(i)

proc `[]`*(t: var Track; i: ByteIndex): var TrackRow =
  ## Gets the `i`th row in the track, allowing mutations.
  ##
  t.get(i)

proc `[]=`*(t: var Track; i: ByteIndex; v: TrackRow) =
  ## Replaces the `i`th row in the track with the given one.
  ##
  t.get(i) = v

func isValid*(t: Track): bool =
  ## Determines if the track is valid, or if the track has a reference to
  ## the track data.
  ##
  t.data != nil

template itemsImpl(t: Track | var Track): untyped =
  for i in 0..<t.len:
    yield t.get(i)

iterator items*(t: Track): TrackRow =
  ## Convenience iterator for iterating every row in the track.
  ##
  itemsImpl(t)

iterator mitems*(t: var Track): var TrackRow =
  ## Convenience iterator for iterating every row in the track,
  ## allowing mutations.
  ##
  itemsImpl(t)

proc setNote*(t: var Track; i: ByteIndex; note: uint8) 
  {. deprecated: "Use NoteColumn overload instead" .} =
  ## Sets the note index at the `i`th row to the given note index
  ##
  t.get(i).note = noteColumn(note)

proc setNote*(t: var Track; i: ByteIndex; note: NoteColumn) =
  ## Sets the note column at the `i`th row to the given note column value.
  ##
  t.get(i).note = note

proc setInstrument*(t: var Track; i: ByteIndex; instrument: TableId) 
  {. deprecated: "Use InstrumentColumn overload instead" .} =
  ## Sets the instrument index at the `i`th row to the given instrument
  ##
  t.get(i).instrument = instrumentColumn(instrument)

proc setInstrument*(t: var Track; i: ByteIndex; instrument: InstrumentColumn) =
  ## Sets the instrument column at the `i`th row to the given instrument column
  ## value.
  ##
  t.get(i).instrument = instrument

proc setEffect*(t: var Track; i: ByteIndex; effectNo: EffectIndex;
                et: EffectType; param = 0u8) =
  ## Sets the effect type and parameter at the `i`th row and `effectNo` column.
  ##
  t.get(i).effects[effectNo] = Effect(effectType: et.uint8, param: param)

proc setEffectType*(t: var Track; i: ByteIndex; effectNo: EffectIndex;
                    et: EffectType) =
  ## Sets the effect type at the `i`th row and `effectNo` column.
  ##
  t.get(i).effects[effectNo].effectType = et.uint8

proc setEffectParam*(t: var Track; i: ByteIndex; effectNo: EffectIndex;
                     param: uint8) =
  ## Sets the effect parameter at the `i`th row and `effectNo` column.
  ##
  t.get(i).effects[effectNo].param = param

func totalRows*(t: Track): int =
  ## Gets the total number of rows that are non-empty.
  ##
  for row in t:
    if not row.isEmpty():
      inc result

# TrackView ===================================================================

converter toView*(t: sink Track): TrackView =
  ## Convert a Track to a TrackView. This is a converter so that you can pass
  ## `Track` objects to any proc taking a `TrackView`.
  ##
  result.track = t

template init*(T: typedesc[TrackView]; track: sink Track): TrackView =
  ## Value constructor for a TrackView by shallow copying the given Track.
  ## While the returned TrackView is immutable, its data can be mutated if
  ## a Track still refers to this data.
  ##
  toView(track)

template `==`*(lhs, rhs: TrackView): bool =
  ## Equality operator for two track views. The two views are equal if their
  ## source tracks are equivalent (see `==` for Tracks)
  ##
  lhs.track == rhs.track

template `[]`*(t: TrackView; i: ByteIndex): TrackRow =
  ## Gets the `i`th row in the view's track.
  ##
  t.track[i]

iterator items*(t: TrackView): TrackRow =
  ## Iterates all rows in the view's track.
  ##
  for i in t.track:
    yield i

template isValid*(t: TrackView): bool =
  ## Checks if this view's track is valid.
  ##
  t.track.isValid()

template len*(t: TrackView): int =
  ## Get the len, or number of rows, for this view's track.
  ##
  t.track.len

template totalRows*(t: TrackView): int =
  ## Counts the total number of rows that are non-empty for this view's track.
  ##
  t.track.totalRows()

# TrackMap ====================================================================

proc clear(m: var TrackMap) =
  for table in m.data.mitems:
    table.clear()

proc put(m: var TrackMap; ch: ChannelId; order: ByteIndex;
         val: sink ref TrackData) =
  m.data[ch][order] = EqRef[TrackData](src: val)

func get(m: TrackMap; ch: ChannelId; order: ByteIndex): ref TrackData =
  m.data[ch].getOrDefault(order).src

proc getAlways(m: var TrackMap; ch: ChannelId; order: ByteIndex
              ): ref TrackData =
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
    order: initOrder(),
    trackLen: defaultTrackSize,
    tracks: default(Song.tracks.typeOf),
    tickrate: none(Tickrate)
  )

func init*(T: typedesc[Song]): Song =
  ## Value constructor for a new Song. The returned song is initialized with
  ## default settings.
  ##
  Song.construct

func new*(T: typedesc[Song]): ref Song =
  ## Ref constructor for a new Song. Same initialization logic as `init`.
  ##
  (ref Song).construct

func new*(T: typedesc[Song]; song: Song): ref Song =
  ## Ref constructor for a new song, copying the given `song`.
  ##
  (ref Song)(
    name: song.name,
    rowsPerBeat: song.rowsPerBeat,
    rowsPerMeasure: song.rowsPerMeasure,
    speed: song.speed,
    effectCounts: song.effectCounts,
    order: song.order,
    trackLen: song.trackLen,
    tracks: song.tracks,
    tickrate: song.tickrate
  )

proc removeAllTracks*(s: var Song) =
  ## Removes all tracks for each channel in the song.
  ##
  s.tracks.clear()

proc speedToFloat*(speed: Speed): float =
  ## Converts a fixed point speed to floating point.
  ##
  speed.float * (1.0 / (1 shl speedFractionBits))

proc speedToTempo*(speed: float; rowsPerBeat: PositiveByte; framerate: float
                  ): float =
  ## Calculates the tempo, in beats per minute, from a speed. `rowsPerBeat` is
  ## the number of rows in the pattern that make a single beat. `framerate`
  ## is the update rate of music playback, in hertz.
  ##
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

func getTrackView*(s: Song; ch: ChannelId; order: ByteIndex): TrackView =
  ## Gets a copy of the track for the given channel and track id. If there is
  ## no track for this address, an invalid Track is returned. Note that this
  ## proc returns a copy! For non-copying access use the viewTrack template.
  ##
  TrackView(track: Track.init(s.tracks.get(ch, order), s.trackLen))

func getTrack*(s: var Song; ch: ChannelId; order: ByteIndex): Track =
  Track.init(s.tracks.getAlways(ch, order), s.trackLen)

iterator trackIds*(s: Song; ch: ChannelId): ByteIndex =
  ## Iterates all of tracks contained in this song, yielding their id.
  ## 
  for id in s.tracks.data[ch].keys:
    yield id

proc getRow*(s: var Song; ch: ChannelId; order, row: ByteIndex;
            ): var TrackRow =
  ## same as `getRow<#getRow,Song,ChannelId,ByteIndex,ByteIndex_2>`_ but
  ## allows the returned row to be mutated. As a result of this if the track
  ## did not exist beforehand, it will be added.
  ##
  s.tracks.getAlways(ch, order)[][row]

proc getRow*(s: Song; ch: ChannelId; order, row: ByteIndex;): TrackRow =
  ## Gets the track row for the channel, order row (pattern id), and row in the
  ## pattern. If there was no such row, an empty row is returned.
  ##
  let data = s.tracks.get(ch, order)
  if data != nil:
    data[][row]
  else:
    TrackRow()

func getRow*(s: Song; order, row: ByteIndex; ): PatternRow =
  result = [
    s.getRow(ch1, order, row),
    s.getRow(ch2, order, row),
    s.getRow(ch3, order, row),
    s.getRow(ch4, order, row)
  ]

func totalTracks*(s: Song): int =
  ## Gets the total number of tracks from all channels in this song.
  ##
  s.tracks.len

proc setTrack*(s: var Song; ch: ChannelId; order: ByteIndex; track: sink Track
              ) =
  ## Puts the given track into the song for the given channel and order.
  ##
  if track.isValid():
    s.tracks.put(ch, order, track.data)

proc estimateSpeed*(s: Song; tempo, framerate: float;): Speed =
  ## Calculate the closest speed value for the given `tempo`, in beats per
  ## minute, and `framerate` in hertz.
  ##
  let speedFloat = speedToTempo(tempo, s.rowsPerBeat, framerate)
  let speed = round(speedFloat * (1 shl speedFractionBits).float).uint8
  result = clamp(speed, low(Speed), high(Speed))

proc tempo*(s: Song; framerate: float): float =
  ## Gets the tempo, in beats per minute, for the song using the given
  ## `framerate`, in hertz.
  ##
  result = speedToTempo(speedToFloat(s.speed), s.rowsPerBeat, framerate)

template editTrack*(s: var Song; ch: ChannelId; trackId: ByteIndex;
                    value, body: untyped;): untyped =
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

template viewTrack*(s: Song; ch: ChannelId; trackId: ByteIndex;
                    value, body: untyped;): untyped =
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

template editPattern*(s: var Song; orderNo: ByteIndex; value, body: untyped;
                     ): untyped =
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

template viewPattern*(s: Song; orderNo: ByteIndex; value, body: untyped;
                     ): untyped =
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

func patternLen*(s: Song; order: ByteIndex): Natural =
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

func songPos*(pattern = ByteIndex(0); row = ByteIndex(0)): SongPos =
  ## Constructs a song position
  ##
  SongPos(pattern: pattern, row: row)

func songSpan*(pos: SongPos; rows = 0): SongSpan =
  ## Create a span from a position, with optional amount of rows to specify the
  ## span's range.
  ## 
  result = SongSpan(pos: pos, rows: rows)

func songSpan*(pattern: ByteIndex; rowStart, rowEnd: ByteIndex;): SongSpan =
  ## Create a span with the given pattern and range of rows.
  ##
  result = SongSpan(
    pos: songPos(pattern, rowStart),
    rows: rowEnd - rowStart + 1
  )

func asSlice*(span: SongSpan): Slice[int] =
  ## Get the span's range of rows as a slice
  ##
  result = span.pos.row..(span.pos.row + span.rows - 1)

func isValid*(song: Song; pos: SongPos; ): bool =
  ## Determines if `pos` is a valid position in the song.
  ##
  result = pos.pattern >= 0 and
           pos.pattern < song.order.len and
           pos.row >= 0 and
           pos.row < song.trackLen

func isValid*(song: Song; span: SongSpan): bool =
  ## Determines if `span` is a valid span in the song. A span is valid if its
  ## starting position is valid and if its range of rows is within 
  ## `0..(song.trackLen-1)`.
  ##
  let lastRow = span.pos.row + span.rows
  result = isValid(song, span.pos) and
           span.rows > 0 and
           lastRow >= 0 and
           lastRow < song.trackLen

func `$`*(pos: SongPos): string =
  ## Stringify a position, formated as `pattern:row`
  ##
  result = $pos.pattern
  result.add(':')
  result.add($pos.row)

func `$`*(span: SongSpan): string =
  ## Stringify a span, formatted as `pattern:row+rows`
  result = $span.pos
  result.add('+')
  result.add($span.rows)

# SongList

func init*(T: typedesc[SongList]; len = PositiveByte(1)): SongList =
  ## Value constructor for a new SongList. `len` is the number of new songs
  ## to initialize the list with.
  ## 
  result = SongList(
    data: newSeq[EqRef[Song]](len)
  )
  for songref in result.data.mitems:
    songref.src = Song.new

iterator items*(l: SongList): Immutable[ref Song] =
  ## Iterates all songs in the SongList
  ## 
  for s in l.data:
    yield s.src.toImmutable

iterator mitems*(l: var SongList): ref Song =
  ## Iterators all songs in the SongList, allowing for mutations.
  ## 
  for s in l.data:
    yield s.src

proc `[]`*(l: var SongList; i: ByteIndex): ref Song =
  ## Gets a mutable reference to the song at the `i`th index in the list.
  ## 
  l.data[i].src

func `[]`*(l: SongList; i: ByteIndex): Immutable[ref Song] =
  ## Gets an immutable reference to the song at the `i`th index in the list.
  ## 
  l.data[i].src.toImmutable

proc `[]=`*(l: var SongList; i: ByteIndex; s: ref Song) =
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

proc add*(l: var SongList; song: ref Song) =
  ## Adds `song` to the end of the list. An `AssertionDefect` will be raised
  ## if the list is at maximum capacity or if `song` was `nil`.
  ## 
  doAssert song != nil, "cannot add a nil song!"
  l.canAdd()
  l.data.add(song.toEqRef)

proc duplicate*(l: var SongList; i: ByteIndex) =
  ## Duplicates the song at the `i`th index in the list and adds it to the
  ## end of the list. An `AssertionDefect` is raised if the list is at
  ## maximum capacity.
  ## 
  l.canAdd()
  l.data.add( Song.new( l.data[i].src[] ).toEqRef )

proc remove*(l: var SongList; i: ByteIndex) =
  ## Removes the song at the `i`th index in the list. An `AssertionDefect` is
  ## raised if removing the song will result in an empty list.
  ## 
  doAssert l.data.len > 1, "SongList must have at least 1 song"
  l.data.delete(i)

proc moveUp*(l: var SongList; i: ByteIndex) =
  ## Moves the song at the `i`th index in the list up one. Or, swaps the
  ## locations of the songs at `i` and `i-1` in the list. An `IndexDefect` is
  ## raised if `i` is 0, or the topmost item.
  ## 
  if i == 0:
    raise newException(IndexDefect, "cannot move topmost item up")
  swap(l.data[i], l.data[i - 1])

proc moveDown*(l: var SongList; i: ByteIndex) =
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
    tickrate: defaultTickrate,
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
  ## - tickrate set to defaultTickrate (59.7 Hz)
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

func getTickrate*(m: Module; song: ByteIndex): Tickrate =
  ## Gets the tickrate for the given song id. The tickrate returned will be the
  ## song's tickrate override if set, otherwise it will be the module's
  ## tickrate.
  ## 
  if song < m.songs.len:
    let s = m.songs[song]
    if s[].tickrate.isSome():
      return s[].tickrate.unsafeGet()
  result = m.tickrate

converter toInfoString*(str: string): InfoString =
  ## Implicit conversion of a `string` to an `InfoString`. Only the first
  ## 32 characters of `str` are copied if `str.len` is greater than 32.
  ##
  for i in 0..<min(str.len, result.len):
    result[i] = str[i]

func `==`*(a, b: SongList;): bool =
  ## Equality test for two song lists. Uses deep equality checking.
  ##
  a.data == b.data

func `==`*(a, b: SomeTable;): bool =
  ## Equality test for two tables. Uses deep equality checking.
  ##
  bind utils.`==`, deepEquals
  system.`==`(a, b)

{. pop .}
