
import
  ./common,
  ./notes,
  ./private/data,
  ./private/utils,
  ./version

import std/[
  hashes,
  math,
  options,
  strutils,
  strformat,
  tables
]

export common
export options

const tableCapacity = 64u8

type
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
    ## * `system`: Specifies a predefined system's tick rate
    ## * `customFramerate`: Custom tick rate to use for `systemCustom`.
    ##
    system*: System = systemDmg
    customFramerate*: float32 = 30

  Speed* = distinct uint8
    ## Value that indicates the playback speed of a [Song]. This value is in
    ## units of ticks per row, and is in fixed-point format Q4.4.
    ##

  LoopPoint* = object
    ## Object that indicates a loop index in a sequence. If enabled, the
    ## sequence will loop to the specified index.
    ## * `enabled`: determines if the sequence will loop
    ## * `index`: the index to loop back to
    ##
    enabled*: bool
    index*: uint8

  SequenceKind* = enum
    ## Enumeration for the kinds of parameters a sequence can operate on.
    ## An `Instrument` has a `Sequence` for each one of these kinds.
    ##
    skArp       ## Channel note or arpeggio sequence
    skPanning   ## Channel panning
    skPitch     ## Channel frequency or pitch
    skTimbre    ## Channel timbre
    skEnvelope  ## Channel envelope

  Sequence* = object
    ## A sequence is a sequence of parameter changes with looping capability.
    ## (Not to be confused with a Nim sequence, `seq[T]`).
    ## * `loop`: The sequence's loop point.
    ## * `data`: The sequence's data, a list of bytes.
    ##
    loop*: LoopPoint
    data*: seq[uint8]
  
  SequenceLen* = range[0..255]
    ## Range of valid lengths for a [Sequence]'s data.
    ##

  Instrument* = object
    ## Container for a Trackerboy instrument. An instrument provides frame
    ## level control of a channel's parameters and is activated on each
    ## note trigger.
    ## * `name`: Optional name of the instrument.
    ## * `channel`: The channel to preview this instrument on. Note that
    ##              instruments can be used on any channel, so this field is
    ##              purely informational.
    ## * `sequences`: A [Sequence] for each [SequenceKind].
    ##
    name*: string
    channel*: ChannelId
    sequences*: array[SequenceKind, Sequence]

  WaveData* = array[16, uint8]
    ## Waveform data. A waveform consists of 16 bytes, with each byte
    ## containing 2 4-bit PCM samples. The first sample is the upper nibble
    ## of the byte, with the second being the lower nibble.
    ##
  
  Waveform* = object
    ## Container for a waveform to use on CH3.
    ## * `name`: An optional name for the waveform.
    ## * `data`: The waveform's data.
    ##
    name*: string
    data*: WaveData

  TableId* = range[0u8..(tableCapacity - 1)]
    ## Integer ID type for items in an InstrumentTable or WaveformTable.
    ##

  SomeData* = Instrument|Waveform
    ## Type class for data stored in a module data table.
    ##

  TableMeta = object
    ids: set[TableId]
    nextFree: TableId
    len: uint8

  Table[T] = object
    meta: TableMeta
    data: array[TableId, EqRef[T]]

  IdBuf = FixedSeq[int(tableCapacity), TableId]

  InstrumentTable* = Table[Instrument]
    ## Container for [Instrument]. Up to 64 Instruments can be stored in this
    ## table and is addressable via a [TableId].
    ##
  
  WaveformTable* = Table[Waveform]
    ## Container for [Waveform]. Up to 64 Waveforms can be stored in this
    ## table and is addressable via a [TableId].
    ##

  SomeTable* = InstrumentTable|WaveformTable
    ## Type class for a module data table.
    ##

  Column = distinct uint8
    # Column value in a TrackRow, as a biased uint8. An unset column is 0, and
    # a column with a value of 0 is 1, value of 1 is 2, etc

  NoteColumn* = distinct Column
    ## Column in a [TrackRow] that contains the an optional note value.
    ##

  InstrumentColumn* = distinct Column
    ## Column in a [TrackRow] that contains an optional instrument to use.
    ##

  EffectCmd* = enum
    ## Enumeration for all available effects.
    ##
    ecNoEffect = 0          ## No effect, this effect column is unset.
    ecPatternGoto           ## Bxx begin playing given pattern immediately
    ecPatternHalt           ## C00 stop playing
    ecPatternSkip           ## D00 begin playing next pattern immediately
    ecSetTempo              ## Fxx set the tempo
    ecSfx                   ## Txx play sound effect
    ecSetEnvelope           ## Exx set the persistent envelope/wave id setting
    ecSetTimbre             ## Vxx set persistent duty/wave volume setting
    ecSetPanning            ## Ixy set channel panning setting
    ecSetSweep              ## Hxx set the persistent sweep setting (CH1 only)
    ecDelayedCut            ## Sxx note cut delayed by xx frames
    ecDelayedNote           ## Gxx note trigger delayed by xx frames
    ecLock                  ## L00 (lock) stop the sound effect on the current channel
    ecArpeggio              ## 0xy arpeggio with semi tones x and y
    ecPitchUp               ## 1xx pitch slide up
    ecPitchDown             ## 2xx pitch slide down
    ecAutoPortamento        ## 3xx automatic portamento
    ecVibrato               ## 4xy vibrato
    ecVibratoDelay          ## 5xx delay vibrato xx frames on note trigger
    ecTuning                ## Pxx fine tuning
    ecNoteSlideUp           ## Qxy note slide up
    ecNoteSlideDown         ## Rxy note slide down
    ecSetGlobalVolume       ## Jxy set global volume scale

  Effect* {.packed.} = object
    ## Effect column. An effect has a type and a parameter.
    ## * `cmd`: Effect command, should be in range of the [EffectCmd]
    ##          enum, unknown commands are to be ignored.
    ## * `param`: Effect parameter byte, only needed for certain effects.
    ##
    cmd*: uint8
    param*: uint8

  TrackRow* {.packed.} = object
    ## A single row of data in a Track. Guaranteed to be 8 bytes.
    ## * `note`: The note column, specifies an optional note value.
    ## * `instrument`: The instrument column, specifies which instrument to use.
    ## * `effects`: 3 available [Effect] columns.
    ##
    note*: NoteColumn
    instrument*: InstrumentColumn
    effects*: array[3, Effect]
  
  PatternRow* = array[ChannelId, TrackRow]
    ## A full row in a pattern is a [TrackRow] for each track/channel.
    ##
  
  TrackId* = uint8
    ## Integer ID type that refers a [Track] in an [OrderRow].
    ##

  OrderRow* = array[ChannelId, TrackId]
    ## An OrderRow is a set of TrackIds, one for each channel.
    ##

  Order* = seq[OrderRow]
    ## An Order is a sequence of OrderRows, that determine the layout of
    ## a Song. Each Order must have at least 1 row and have no more than
    ## 256 rows.
    ##
  
  OrderLen* = range[1..256]
    ## Subrange of valid lengths, or number of order rows, for an [Order].
    ##

  TrackLen* = range[1..256]
    ## Subrange of valid lengths, or number of track rows, for a [Track].
    ##
  
  TrackData = seq[TrackRow]

  Track* = object
    ## Pattern data for a single track. A track can store up to 256 rows.
    ## The data is stored using ref semantics, so assigning a track from
    ## another track will result in a shallow copy. Use the initTrack proc to
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
  
  TrackView* = object
    ## Same as [Track], but only provides immutable access to the track data.
    ## Mutable access can be acquired by converting the view to a Track via
    ## the initTrack overload, while making a deep copy of the data.
    ##
    src: Track
  
  SomeTrack* = Track | TrackView
    ## Type class of all track types
    ##

  Pattern* = array[ChannelId, Track]
    ## A pattern is a composition of multiple [Track]s, one for each channel.
    ## Patterns are mutable. For immutable patterns use [PatternView].
    ##

  PatternView* = array[ChannelId, TrackView]
    ## View-only version of [Pattern].
    ##

  SomePattern* = Pattern | PatternView
    ## Type class for all pattern types.
    ##

  TrackKey {.packed.} = object
    # Key type used by TrackMap's table
    ch: ChannelId
    id: TrackId

  TrackMap = object
    # used internally by Song, a map container for all of the song's tracks.
    # maps a `TrackKey` -> `ref TrackData`
    table: tables.Table[TrackKey, EqRef[TrackData]]
    # the length, in rows, of every track
    rows: int

  EffectCounts* = array[ChannelId, uint8]
    ## Array containing an amount for each channel, that determines how many
    ## effect columns should be shown to the user.
    ##

const
  defaultRpb* = 4
    ## Default rowsPerBeat setting for new [Song]s.
    ##
  
  defaultRpm* = 16
    ## Default rowsPerMeasure setting for new [Song]s.
    ##
  
  defaultSpeed* = Speed(0x60)
    ## Default speed setting for new [Song]s.
    ##
  
  defaultTrackLen* = 64
    ## Default trackLen setting for new [Song]s.
    ##

type
  Song* = object
    ## A Song is a collection of [Track]s and an [Order] in which they are
    ## played out.
    ## * `name`: Optional name of the song.
    ## * `rowsPerBeat`: Number of rows that make up a beat. Used for tempo
    ##                  calculation and by the front end for row highlights.
    ## * `rowsPerMeasure`: Number of rows that make up a measure. Informational
    ##                     field used by the front end for row highlights.
    ## * `speed`: Starting speed of the song.
    ## * `effectCounts`: Effect columns visible counts. Used by the front end
    ##                   for the number of effect columns shown for each
    ##                   channel.
    ## * `order`: The playback order of the song.
    ## * `trackLen`: The number of rows each track in the song is.
    ## * `tickrate`: Tickrate override for this song. If not set, then the
    ##               module's tickrate should be used instead.
    ##
    name*: string
    rowsPerBeat* = defaultRpb
    rowsPerMeasure* = defaultRpm
    speed* = defaultSpeed
    effectCounts*: EffectCounts = [2u8, 2, 2, 2]
    order*: Order
    tracks: TrackMap
    tickrate*: Option[Tickrate]

  SongPos* = object
    ## Song position. This object contains a position in a song.
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

  SongList* = object
    ## Container for songs. Songs stored in this container are references,
    ## like [InstrumentTable] and [WaveformTable]. A valid SongList contains
    ## 1-256 songs.
    ##
    data: seq[ref Song]

  InfoString* = array[32, char]
    ## Fixed-length string of 32 characters, used for artist information.
    ##

  ModulePiece* = Instrument|Song|Waveform
    ## Type class for an individual component of a module.
    ##

  Module* = object
    ## A module is a container for songs, instruments and waveforms.
    ## Each module can store up to 256 songs, 64 instruments and 64
    ## waveforms. Instruments and Waveforms are shared between all songs.
    ##  * `songs`: The list of all songs in this module.
    ##  * `instruments`: The module's instrument table, shared with all songs.
    ##  * `waveforms`: The module's waveform table, shared with all songs.
    ##  * `title`: Optional title information for the module.
    ##  * `artist`: Optional artist information for the module.
    ##  * `copyright`: Optional copyright information for the module.
    ##  * `comments`: Addition comment information about the module.
    ##  * `tickrate`: The [Tickrate] used by all songs in the module.
    ##
    songs*: SongList
    instruments*: InstrumentTable
    waveforms*: WaveformTable
    title*, artist*, copyright*: InfoString
    comments*: string
    tickrate*: Tickrate
    private*: ModulePrivate

const
  defaultTickrate* = default(Tickrate)
    ## Default tickrate setting for a [Module].
    ##

  unitSpeed* = Speed(0x10)
    ## Unit speed, or a [Speed] that is 1.0 ticks per row.
    ##

  rangeSpeed* = unitSpeed .. Speed(0xF0)
    ## Valid range of [Speed] values.
    ##

  noLoopPoint* = LoopPoint()
    ## Indicates that a sequence ends at the last value, or does not loop.
    ## 

  noteNone* = NoteColumn(0)
    ## Note column value for an unset column. Same as `default(NoteColumn)`.
    ##
  instrumentNone* = InstrumentColumn(0)
    ## Instrument column value for an unset column. Same as
    ## `default(InstrumentColumn)`.
    ##
  effectNone* = default(Effect)
    ## Effect column value for an unset effect. Same as `default(Effect)`.
    ##

  effectCharMap*: array[EffectCmd, char] = [
    '?', # ecNoEffect
    'B', # ecPatternGoto
    'C', # ecPatternHalt
    'D', # ecPatternSkip
    'F', # ecSetTempo
    'T', # ecSfx
    'E', # ecSetEnvelope
    'V', # ecSetTimbre
    'I', # ecSetPanning
    'H', # ecSetSweep
    'S', # ecDelayedCut
    'G', # ecDelayedNote
    'L', # ecLock
    '0', # ecArpeggio
    '1', # ecPitchUp
    '2', # ecPitchDown
    '3', # ecAutoPortamento
    '4', # ecVibrato
    '5', # ecVibratoDelay
    'P', # ecTuning
    'Q', # ecNoteSlideUp
    'R', # ecNoteSlideDown
    'J'  # ecSetGlobalVolume
  ]
    ## Array that maps an [EffectCmd] to a `char`. Each effect is represented
    ## by a letter or number as its type when displayed in a tracker.
    ##



# Tickrate ====================================================================

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

# Speed =======================================================================

func `$`*(s: Speed): string =
  ## Stringify a [Speed]. The string returned is the speed's value in
  ## hexadecimal prefixed with '$'. Since the value is in Q4.4 format, the
  ## first hex is the integral part and the second is the fractional part.
  ##
  result.add('$')
  result.add(toHex(uint8(s)))

func `==`*(x, y: Speed; ): bool {.borrow.}
func `<`*(x, y: Speed; ): bool {.borrow.}
func `<=`*(x, y: Speed; ): bool {.borrow.}

func isValid*(s: Speed): bool =
  ## Determine if the speed is valid. Valid speeds are within the range of
  ## [rangeSpeed].
  ##
  result = s in rangeSpeed

func toFloat*(speed: Speed): float =
  ## Converts a fixed point speed to floating point.
  ##
  result = float(speed) / float(unitSpeed)

func toSpeed*(speed: float): Speed =
  ## Converts a floating point speed value to fixed point. The result is
  ## clamped within the bounds of valid speed values.
  ##
  let tmp = speed * float(unitSpeed)
  result = Speed(clamp(int(round(tmp)), int(rangeSpeed.a), int(rangeSpeed.b)))

func tempo*(speed: float; rowsPerBeat: PositiveByte; framerate: float): float =
  ## Calculates the tempo, in beats per minute, from a speed, in ticks per row.
  ## `rowsPerBeat` is the number of rows in the pattern that make a single beat.
  ## `framerate` is the update rate of music playback, in hertz.
  ##
  result = (framerate * 60.0) / (speed * float(rowsPerBeat))

func tempo*(speed: Speed; rowsPerBeat: PositiveByte; framerate: float): float =
  ## Convenience overload for converting a [Speed] to a tempo.
  ##
  result = tempo(toFloat(speed), rowsPerBeat, framerate)

# Sequences ===================================================================

func initLoopPoint*(index: uint8): LoopPoint =
  ## Creates a [LoopPoint] that defines a loop to the given index.
  ##
  result = LoopPoint(enabled: true, index: index)

func initLoopPoint*(): LoopPoint =
  ## Creates an empty [LoopPoint], or one that indicates there is no loop.
  ##
  defaultInit(result)

func initSequence*(data: openArray[uint8]; loop = noLoopPoint): Sequence =
  ## Creates a sequence with an optional loop point and data. `data.len` must
  ## be <= 256!
  ##
  rangeCheck(data.len in SequenceLen)
  result = Sequence(loop: loop, data: @data)

func isValid*(s: Sequence): bool =
  ## Determine if the sequence is valid. Valid sequences have no more than 256
  ## elements.
  ##
  result = s.data.len <= 256

func `[]`*(s: Sequence; i: ByteIndex): uint8 {.inline.} =
  ## Gets the `i`th element in the sequence. Same as `s.data[i]`
  ##
  result = s.data[i]

proc `[]=`*(s: var Sequence; i: ByteIndex; val: uint8) {.inline.} =
  ## Sets the `i`th element in the sequence to the given `val`. Same as
  ## `s.data[i] = val`.
  ##
  s.data[i] = val

proc setLen*(s: var Sequence; len: SequenceLen) {.inline.} =
  ## Sets the length of the Sequence `s` to the given `len`. Same as
  ## `s.data.setLen(len)`.
  ##
  s.data.setLen(len)

func len*(s: Sequence): int {.inline.} =
  ## Gets the length of the sequence. Same as `s.data.len`.
  ##
  result = s.data.len

# Instruments =================================================================

func initInstrument*(): Instrument =
  ## Initialize an [Instrument]. Default initialization is used, so
  ## the instrument's channel is ch1, and all its sequences are empty.
  ##
  defaultInit(result)

func hash*(i: Instrument): Hash =
  ## Calculate a hash code for an instrument.
  ##
  result = hash(i.sequences)

func `==`*(a, b: Instrument; ): bool =
  ## Determine if two instruments are **functionally** equivalent.
  ## Informational data of the instruments are not tested.
  ##
  result = a.sequences == b.sequences

# Waveform ====================================================================

func initWaveform*(): Waveform =
  ## Initialize a [Waveform]. The returned Waveform's wave data is
  ## cleared, or each sample is set to 0.
  ##
  defaultInit(result)

func `==`*(a, b: Waveform; ): bool =
  ## Determines if two waveforms are **functionally** equivalent, or if they
  ## have the same wave data.
  ##
  result = a.data == b.data

func hash*(w: Waveform): Hash =
  ## Calculates a hash code for a Waveform. Only the waveform's wave data is
  ## used when calculating the hash.
  ##
  template data(i: int): uint64 =
    cast[array[2, uint64]](w.data)[i]
  result = !$(hash(data(0)) !& hash(data(1)))

# Table =======================================================================

func contains(m: TableMeta; id: TableId): bool =
  result = id in m.ids

proc updateNextFree(m: var TableMeta) =
  for i in m.nextFree..high(TableId):
    if i notin m:
      m.nextFree = i
      break

proc addNext(m: var TableMeta): TableId =
  doAssert m.len < tableCapacity, "cannot add: table is full"
  result = m.nextFree
  m.ids.incl(result)
  inc m.len
  m.updateNextFree()

proc add(m: var TableMeta; id: TableId) =
  doAssert id notin m, "cannot add id: already in table"
  m.ids.incl(id)
  inc m.len
  if m.nextFree == id:
    m.updateNextFree()

proc del(m: var TableMeta; id: TableId) =
  doAssert id in m, "cannot remove id: id not in table"
  if id < m.nextFree:
    m.nextFree = id
  m.ids.excl(id)

proc duplicate(m: var TableMeta; id: TableId): TableId =
  doAssert m.len < tableCapacity and id in m, "cannot duplicate: table is full or id does not exist"
  result = m.addNext()

func getNextId(m: TableMeta; startAt: TableId): Option[TableId] =
  for id in startAt..high(TableId):
    if id in m:
      return some(id)
  defaultInit(result)

func initInstrumentTable*(): InstrumentTable =
  ## Initialize an empty [InstrumentTable].
  ##
  defaultInit(result)

func initWaveformTable*(): WaveformTable =
  ## Initialize an empty [WaveformTable].
  ##
  defaultInit(result)

func contains*(t: SomeTable; id: TableId): bool =
  ## Determines if the table contains an item with the `id`
  ##
  result = contains(t.meta, id)

proc capacity*(t: SomeTable): static[int] =
  ## Maximum number of items that can be stored in a Table.
  ##
  result = tableCapacity

func `[]`*[T: SomeData](t: Table[T]; id: TableId): Immutable[ref T] =
  ## Gets an immutable ref of the item with the given id or `nil` if there
  ## is no item with that id.
  ##
  result = toImmutable(t.data[id].src)

func `[]`*[T: SomeData](t: var Table[T]; id: TableId): ref T =
  result = t.data[id].src

iterator items*[T: SomeData](t: Table[T]): TableId {.noSideEffect.} =
  ## Iterates all items in the table, via their id, in ascending order.
  ##
  for id in low(TableId)..high(TableId):
    if id in t:
      yield id

proc putNew[T: SomeData](t: var Table[T]; id: TableId) =
  t.data[id].src = new(T)

proc add*[T: SomeData](t: var Table[T]): TableId =
  ## Adds a new item to the table using the next available id. If the table
  ## is at capacity, an `AssertionDefect` will be raised.
  ##
  result = t.meta.addNext()
  putNew(t, result)

proc add*[T: SomeData](t: var Table[T]; id: TableId) =
  ## Adds a new item using the given id. An `AssertionDefect` will be raised
  ## if the table is at capacity, or if the id is already in use.
  ##
  t.meta.add(id)
  putNew(t, id)

proc duplicate*[T: SomeData](t: var Table[T]; id: TableId): TableId =
  ## Adds a copy of the item with the given id, using the next available id.
  ## An `AssertionDefect` is raised if the item to copy does not exist, or if
  ## the table is at capacity.
  ##
  result = t.meta.duplicate(id)
  putNew(t, result)
  # duplicate the newly added item
  t.data[result].src[] = t.data[id].src[]

proc remove*[T: SomeData](t: var Table[T]; id: TableId) =
  ## Removes the item at the given id. An `AssertionDefect` is raised if the
  ## item does not exist.
  ##
  t.meta.del(id)
  t.data[id].src = nil

proc len*[T: SomeData](t: Table[T]): int =
  ## Gets the len, or number of items present in the table.
  ##
  result = int(t.meta.len)

func nextAvailableId*[T: SomeData](t: Table[T]): TableId =
  ## Gets the id that will be used next by the `add` and `duplicate` procs
  ## This id is always the lowest one available, so removing an item may
  ## lower it.
  ##
  result = t.meta.nextFree

func next*[T: SomeData](t: Table[T]; startAt = TableId(0)): Option[TableId] =
  ## Queries the next available id using a starting position. If no available
  ## id was found, `none(TableId)` is returned.
  ##
  result = t.meta.getNextId(startAt)

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

func `==`*(a, b: SomeTable; ): bool =
  ## Equality test for two tables. Uses deep equality checking.
  ##
  bind utils.`==`, deepEquals
  system.`==`(a, b)

# Column ======================================================================

func initEffect*(cmd = ecNoEffect; param = 0u8): Effect =
  ## Initialize an Effect column with the given command and parameter.
  ##
  result = Effect(cmd: uint8(ord(cmd)), param: param)

func shortensPattern*(cmd: EffectCmd): bool =
  ## Determines if the given effect command will shorten the runtime length of
  ## a pattern by either halting the song or jumping to a new pattern.
  ##
  result = cmd in { ecPatternHalt, ecPatternSkip, ecPatternGoto }

func toEffectCmd*(x: uint8): EffectCmd =
  ## Converts a uint8 to an EffectCmd enum safely. etNoEffect is returned if
  ## x is not in the range of EffectCmd.
  ## 
  result = block:
    if x in EffectCmd:
      EffectCmd(x)
    else:
      ecNoEffect

func effectCmdToChar*(cmd: uint8): char =
  ## Get a `char` representation for the given effect command value. For any
  ## unrecognized effect, `?` is returned.
  ##
  result = effectCharMap[toEffectCmd(cmd)]

func has(x: Column): bool {.inline.} =
  result = uint8(x) != 0

func value(x: Column): uint8 {.inline.} =
  result = uint8(x) - 1

func column(x: range[0u8..254u8]): Column {.inline.} =
  result = Column(x + 1)

func toOption(col: Column): Option[uint8] =
  if col.has():
    some(col.value())
  else:
    none(uint8)

func `==`(x, y: Column; ): bool {.borrow.}

func toString(c: Column; name: string): string =
  result = name
  result.add('(')
  if c.has():
    result.add($(c.value()))
  result.add(')')

func toString(c: NoteColumn; name: string): string {.borrow.}
func toString(c: InstrumentColumn; name: string): string {.borrow.}

func `$`*(c: NoteColumn): string =
  ## Stringify a note column.
  ##
  result = toString(c, "note")

func `$`*(c: InstrumentColumn): string =
  ## Stringify an instrument column.
  ##
  result = toString(c, "instrument")

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
  result = noteColumn(toNote(note, octave))

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

func toOption*(n: NoteColumn): Option[uint8] {.borrow.}
  ## Convert the note column to an Option.
  ##

func toOption*(n: InstrumentColumn): Option[uint8] {.borrow.}
  ## Convert the instrument column to an Option.
  ##

# TrackRow ====================================================================

func initTrackRow*(note = noteNone; instrument = instrumentNone;
                   e1 = effectNone; e2 = effectNone; e3 = effectNone
                   ): TrackRow =
  ## Initialize a [TrackRow] with the given columns.
  ##
  result = TrackRow(
    note: note,
    instrument: instrument,
    effects: [e1, e2, e3]
  )

template trow*(note = noteNone; instrument = instrumentNone;
               e1 = effectNone; e2 = effectNone; e3 = effectNone
               ): TrackRow =
  ## Sugar for [initTrackRow]
  ##
  initTrackRow(note, instrument, e1, e2, e3)

func isEmpty*(row: TrackRow): bool =
  ## Determine if the row is empty, or has all columns unset. Prefer this
  ## function over `row == default(TrackRow)` for performance.
  ##
  static: assert sizeof(uint64) == sizeof(TrackRow)
  cast[uint64](row) == 0u64

# Order =======================================================================

func initOrderRow*(id1 = 0u8; id2 = 0u8; id3 = 0u8; id4 = 0u8): OrderRow =
  ## Initialize an [OrderRow] with the given track ids for each channel.
  ##
  result = [id1, id2, id3, id4]

template orow*(id1 = 0u8; id2 = 0u8; id3 = 0u8; id4 = 0u8): OrderRow =
  ## Sugar for [initOrderRow]
  ##
  initOrderRow(id1, id2, id3, id4)

func initOrder*(): Order =
  ## Initializes a default Order. The default Order contains one row with all
  ## track ids set to 0.
  ##
  result = newSeq[OrderRow](1)

func isValid*(o: Order): bool =
  ## Determines if the order is valid. A valid order only has `1..256` rows.
  ##
  result = o.len in OrderLen

proc nextUnused*(o: Order): OrderRow =
  ## Finds an OrderRow with each of its track ids being the lowest one that
  ## has not been used in the entire order.
  ##
  defaultInit(result)
  for track in ChannelId:
    var idmap: set[TrackId]
    for row in o:
      idmap.incl(row[track])
    # set the track id with the lowest id not encountered
    for id in low(TrackId)..high(TrackId):
      if id notin idmap:
        result[track] = id
        break

# Track, TrackView ============================================================

func newTrackData(len: TrackLen): ref TrackData =
  new(result)
  result[].setLen(len)

template assertValid(t: Track) =
  doAssert t.isValid(), "track is invalid, or has no data"

func `==`*(x, y: Track; ): bool =
  ## Equality test two [Track]s. The tracks are equal if they have same len and
  ## data.
  ##
  result = deepEquals(x.data, y.data)

proc initTrack*(len: TrackLen): Track =
  ## Initialize a [Track] with the given length. All rows in the
  ## returned Track are empty.
  ##
  result = Track(data: newTrackData(len))

func initTrack*(view: TrackView): Track =
  ## Initialize a [Track] by deep copying the [TrackView]. The track
  ## returned has the same data as the view, but can now be mutated.
  ##
  if view.src.data != nil:
    result.data = new(TrackData)
    result.data[] = view.src.data[]

func isValid*(t: Track): bool {.inline.} =
  ## Determines if the track is valid, or if the track has a reference to
  ## the track data.
  ##
  result = t.data != nil

func data*(t: Track): lent seq[TrackRow] {.inline.} =
  ## Access the track's data, as a `seq[TrackRow]`. Track must be valid!
  ##
  assertValid(t)
  result = t.data[]

template get(t: Track; i: ByteIndex): auto =
  t.data[][i]

func `[]`*(t: Track; i: ByteIndex): TrackRow =
  ## Gets the `i`th row in the track.
  ##
  if t.isValid():
    result = get(t, i)

func `[]`*(t: var Track; i: ByteIndex): var TrackRow =
  ## Gets the `i`th row in the track, allowing mutations.
  ##
  assertValid(t)
  result = get(t, i)

proc `[]=`*(t: var Track; i: ByteIndex; v: TrackRow) =
  ## Replaces the `i`th row in the track with the given one.
  ##
  assertValid(t)
  get(t, i) = v

template itemsImpl(t: Track | var Track; iter: untyped): untyped =
  if t.isValid():
    for i in iter(t.data[]):
      yield i

iterator items*(t: Track): TrackRow =
  ## Convenience iterator for iterating every row in the track.
  ##
  itemsImpl(t, items)

iterator mitems*(t: var Track): var TrackRow =
  ## Convenience iterator for iterating every row in the track,
  ## allowing mutations.
  ##
  itemsImpl(t, mitems)

func len*(t: Track): int =
  ## Gets the length, or number of rows contained in this Track.
  ##
  if t.isValid():
    result = t.data[].len

proc setLen*(t: var Track; len: TrackLen) =
  ## Sets the length of the Track to a new value.
  ##
  assertValid(t)
  t.data[].setLen(len)

func totalRows*(t: Track): int =
  ## Gets the total number of rows that are non-empty.
  ##
  for row in t:
    if not row.isEmpty():
      inc result

converter toView*(t: sink Track): TrackView {.inline.} =
  ## Convert a Track to a TrackView. This is a converter so that you can pass
  ## `Track` objects to any proc taking a `TrackView`.
  ##
  result = TrackView(src: t)

func initTrackView*(track: sink Track): TrackView {.inline.} =
  ## Initialize a [TrackView] from the given [Track]. Same as [toView].
  ##
  result = toView(track)

template `[]`*(t: TrackView; i: ByteIndex): TrackRow =
  ## Gets the `i`th row in the view's track.
  ##
  t.src[i]

iterator items*(t: TrackView): TrackRow =
  ## Iterates all rows in the view's track.
  ##
  for i in t.src:
    yield i

template isValid*(t: TrackView): bool =
  ## Checks if this view's track is valid.
  ##
  t.src.isValid()

template len*(t: TrackView): int =
  ## Get the len, or number of rows, for this view's track.
  ##
  t.src.len

template totalRows*(t: TrackView): int =
  ## Counts the total number of rows that are non-empty for this view's track.
  ##
  t.src.totalRows()

# Pattern, PatternView ========================================================

converter toView*(p: Pattern): PatternView =
  ## Converts a [Pattern] to a [PatternView].
  ##
  for ch, t in pairs(p):
    result[ch] = toView(t)

func all*(p: SomePattern; i: ByteIndex): PatternRow =
  ## Gets a [PatternRow] at the given index, using all tracks in the pattern.
  ##
  for ch, t in pairs(p):
    result[ch] = t[i]

# Song ========================================================================

template trackKey(pch: ChannelId; pid: TrackId): TrackKey =
  TrackKey(ch: pch, id: pid)

func hash(key: TrackKey): Hash =
  # hash the key by treating it as a uint16
  static: assert sizeof(TrackKey) == sizeof(uint16)
  result = hash(cast[uint16](key))

proc `=copy`*(dest: var TrackMap; src: TrackMap) =
  # override assignment to deep copy tracks.
  dest.rows = src.rows
  for key, value in pairs(src.table):
    dest.table[key].src = clone(value.src)

func initTrackMap(len: TrackLen): TrackMap =
  # initialize a TrackMap with the given track len
  defaultInit(result.table)
  result.rows = len

proc allocate(m: var TrackMap; ch: ChannelId; id: TrackId): ref TrackData =
  # allocate a new track for the given channel and id if needed. If already
  # allocated, return that track.
  #
  let key = trackKey(ch, id)
  m.table.withValue(key, value):
    result = value.src
  do:
    result = newTrackData(m.rows)
    m.table[key] = toEqRef(result)

func get(m: TrackMap; ch: ChannelId; id: TrackId): TrackView =
  # get a view of the track data for the given channel and id, an invalid view
  # will be returned if the data was not allocated beforehand.
  #
  result = initTrackView(Track(data: m.table.getOrDefault(trackKey(ch, id)).src))

proc getAlways(m: var TrackMap; ch: ChannelId; id: TrackId): Track =
  # gets either a new track or a previously allocated one for the given channel
  # and id. A valid track is always returned.
  #
  result = Track(data: m.allocate(ch, id))

proc initSong(song: var Song) =
  song = Song(
    order: initOrder(),
    tracks: initTrackMap(defaultTrackLen)
  )

func initSong*(): Song =
  ## Initialize a new [Song]. The returned song is set with default settings.
  ##
  initSong(result)

func newSong*(): ref Song =
  ## Create a ref to a new [Song].
  ##
  new(result)
  initSong(result[])

func `==`*(a, b: Song; ): bool =
  ## Equality test two [Song]s.
  ##
  for fieldA, fieldB in fields(a, b):
    if fieldA != fieldB:
      return false
  result = true

func `$`*(s: Song): string =
  ## Stringify a song for debug purposes.
  ##
  result = &"Song(name: \"{s.name}\", ...)"

func isValid*(song: Song): bool =
  ## Determine if `song` was properly initialized.
  ##
  result = isValid(song.order) and song.tracks.rows in TrackLen

proc removeAllTracks*(s: var Song) =
  ## Removes all tracks for each channel in the song.
  ##
  s.tracks.table.clear()

proc removeUnusedTracks*(s: var Song) =
  ## Removes all tracks whose IDs are not listed in the song's order.
  ##
  var allocated: array[ChannelId, set[TrackId]]
  for key in keys(s.tracks.table):
    allocated[key.ch].incl(key.id)
  # filter from order
  for row in s.order:
    for ch in ChannelId:
      allocated[ch].excl(row[ch])
  # remove
  for ch, allocatedInChannel in pairs(allocated):
    for track in allocatedInChannel:
      s.tracks.table.del(trackKey(ch, track))

proc allocateTracks*(s: var Song) =
  ## Adds a new track for each track id in the song's order, if it has not
  ## been added yet. After calling this proc, [getTrackView] will always return
  ## a valid [TrackView].
  ##
  for row in s.order:
    for ch, track in pairs(row):
      discard s.tracks.allocate(ch, track)

func getTrackView*(s: Song; ch: ChannelId; track: TrackId): TrackView =
  ## Gets a view of the track for the given channel and track id. An invalid
  ## view will be returned if the requested track does not exist.
  ##
  result = s.tracks.get(ch, track)

proc getTrack*(s: var Song; ch: ChannelId; track: TrackId): Track =
  ## Gets the track for the given channel and track id. If no such track
  ## existed, an empty one is added to the song. The returned track can
  ## be edited and its changes will persist in the song.
  ##
  result = s.tracks.getAlways(ch, track)

func getPatternView*(s: Song; orderNo: ByteIndex): PatternView =
  ## Gets a view of the pattern data for the given order index.
  ##
  let order = s.order[orderNo]
  for ch in ChannelId:
    result[ch] = s.getTrackView(ch, order[ch])

proc getPattern*(s: var Song; orderNo: ByteIndex): Pattern =
  ## Gets a [Pattern], or an array of [Track]s for each channel in the pattern
  ## at the given index in the song's order.
  ##
  let order = s.order[orderNo]
  for ch in ChannelId:
    result[ch] = s.getTrack(ch, order[ch])

func getRow*(s: Song; orderNo: ByteIndex; row: ByteIndex): PatternRow =
  ## Gets a row of data from the pattern specified by `orderNo`.
  ##
  result = s.getPatternView(orderNo).all(row)

func getRow*(s: Song; ch: ChannelId; track: TrackId; row: ByteIndex): TrackRow =
  ## Gets a row of data from the specified track. If the track does not exist,
  ## an empty row is returned.
  ##
  result = s.getTrackView(ch, track)[row]

iterator trackIds*(s: Song; ch: ChannelId): TrackId =
  ## Iterates all of tracks contained in this song for a channel, yielding
  ## their id.
  ## 
  for key in keys(s.tracks.table):
    if key.ch == ch:
      yield key.id

func totalTracks*(s: Song): int =
  ## Gets the total number of tracks from all channels in this song.
  ##
  result = s.tracks.table.len()

func effectiveTickrate*(s: Song; defaultRate: Tickrate): Tickrate =
  ## Gets the [Tickrate] to be used for performance of this song. If a tickrate
  ## was set for this song, that one is returned, otherwise, `defaultRate` is.
  ## 
  result = s.tickrate.get(defaultRate)

func estimateSpeed*(s: Song; tempo, framerate: float; ): Speed =
  ## Calculate the closest speed value for the given `tempo`, in beats per
  ## minute, and `framerate` in hertz.
  ##
  result = toSpeed( (60 * framerate) / (tempo * float(s.rowsPerBeat)) )

func tempo*(s: Song; framerate: float): float =
  ## Calculate the tempo, in beats per minute, of the song when performing at
  ## the given framerate.
  ##
  result = tempo(s.speed, s.rowsPerBeat, framerate)

func trackLen*(s: Song): int {.inline.} =
  ## Gets the track length, or the number of rows each [Track] in this song
  ## has.
  ##
  result = s.tracks.rows

proc `trackLen=`*(s: var Song; len: TrackLen) =
  ## Sets the track length for all existing [Track]s in this song.
  ##
  if s.tracks.rows != len:
    for value in values(s.tracks.table):
      value.src[].setLen(len)
    s.tracks.rows = len

func patternLen*(s: Song): int =
  ## Gets the number of patterns in the song, or `s.order.data.len`.
  ##
  result = s.order.len()

template editTrack*(s: var Song; ch: ChannelId; trackId: TrackId;
                    trackVar, body: untyped; ) =
  ## Edit a channel's track in place via its track id. `trackVar` is the
  ## name of the variable that contains the requested track that is accessible
  ## in `body`.
  ## 
  runnableExamples:
    var song = initSong()
    song.editTrack(ch3, 0, track):
      track[1].note = noteColumn(10)
      track[4].instrument = instrumentColumn(0)
    song.viewTrack(ch3, 0, track):
      doAssert track[1].note == noteColumn(10)
      doAssert track[4].instrument == instrumentColumn(0)
  block:
    var trackVar {.inject, used.} = s.getTrack(ch, trackId)
    body

template viewTrack*(s: Song; ch: ChannelId; trackId: TrackId;
                    trackVar, body: untyped; ) =
  ## Similar to [editTrack], but instead only provides read-only access to a
  ## track, in place. `trackVar` is the name of the variable that contains a
  ## [TrackView] of the requested track that is accessible in `body`.
  ## 
  ## If the track does not exist, then `value` will refer to an invalid track,
  ## or a track with 0 rows.
  ## 
  ## See the example in [editTrack] for example usage.
  ##
  block:
    var trackVar {.inject.} = s.getTrackView(ch, trackId)
    body

template editPattern*(s: var Song; orderNo: ByteIndex;
                      patternVar, body: untyped; ) =
  ## Edits an entire pattern in place for the given `orderNo` or index in the
  ## song order. `patternVar` is the name of the [Pattern] variable that is
  ## accessible in `body`.
  ## 
  runnableExamples:
    var song = initSong()
    # edit the first pattern such that:
    #  - the first row in ch1's track has the note set to D#2
    #  - the first row in ch2's track has effect#2 set to etTuning with a param of 0x82
    song.editPattern(0, pattern):
      pattern[ch1][0].note = noteColumn(3)
      pattern[ch2][0].effects[1] = initEffect(ecTuning, 0x82)
    song.viewPattern(0, pattern):
      doAssert pattern[ch1][0].note == noteColumn(3)
      doAssert pattern[ch2][0].effects[1] == initEffect(ecTuning, 0x82)
  block:
    var patternVar {.inject, used.} = s.getPattern(orderNo)
    body

template viewPattern*(s: Song; orderNo: ByteIndex;
                      patternVar, body: untyped; ) =
  ## Similar to [editPattern], but instead only provides read-only access to
  ## all tracks in the pattern, by using a [PatternView]. `patternVar` is the
  ## name of the [PatternView] variable that is accessible in `body`.
  ## 
  ## Same as [viewTrack] if any track in the pattern does not exist, an invalid
  ## one will take its place.
  ## 
  ## See the example in [editPattern] for example usage.
  ## 
  block:
    var patternVar {.inject.} = s.getPatternView(orderNo)
    body

func patternLen*(s: Song; order: ByteIndex): int =
  ## Gets the length, in rows, of a pattern taking effects into consideration.
  ## If no pattern jump/halt effect is used then the track length is returned.
  ## 
  s.viewPattern(order, pattern):
    for i in 0..<s.trackLen:
      inc result
      for row in pattern.all(i):
        for effect in row.effects:
          if shortensPattern(EffectCmd(effect.cmd)):
            return

# SongPos =====================================================================

func songPos*(pattern = ByteIndex(0); row = ByteIndex(0)): SongPos =
  ## Creates a song position with the given coordinates.
  ##
  SongPos(pattern: pattern, row: row)

func isValid*(song: Song; pos: SongPos; ): bool =
  ## Determines if `pos` is a valid position in the song.
  ##
  result = pos.pattern >= 0 and
           pos.pattern < song.order.len and
           pos.row >= 0 and
           pos.row < song.trackLen

func `$`*(pos: SongPos): string =
  ## Stringify a position, formated as `pattern:row`
  ##
  result = $pos.pattern
  result.add(':')
  result.add($pos.row)

# SongSpan ====================================================================

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

func `$`*(span: SongSpan): string =
  ## Stringify a span, formatted as `pattern:row+rows`
  ##
  result = $span.pos
  result.add('+')
  result.add($span.rows)

# SongList ====================================================================

func `==`*(x, y: SongList): bool =
  ## Equality test for [SongList]. Each song in both lists are checked for deep
  ## equality.
  ##
  if x.data.len == y.data.len:
    for i in 0..<x.data.len:
      if not deepEquals(x.data[i], y.data[i]):
        return false
    result = true

func initSongList*(len = PositiveByte(1)): SongList =
  ## Create a [SongList] with the given number of songs.
  ##
  result.data = newSeq[ref Song](len)
  for song in mitems(result.data):
    new(song)
    song[] = initSong()

func isValid*(l: SongList): bool =
  ## Determines if the song list is valid, or contains 1-256 songs.
  ##
  result = l.data.len in 1..256

func get*(l: SongList; i: ByteIndex): Immutable[ref Song] =
  ## Gets an immutable reference to the song at the `i`th index in the list.
  ##
  result = toImmutable(l.data[i])

proc mget*(l: var SongList; i: ByteIndex): ref Song =
  ## Gets a mutable reference to the song at the `i`th index in the list.
  ##
  result = l.data[i]

func len*(l: SongList): int {.inline.} =
  ## Gets the length of the song list, or the number of songs it contains.
  ##
  result = l.data.len

template `[]`*(l: SongList; i: ByteIndex): Immutable[ref Song] =
  ## Sugar for `l.get(i)`.
  ##
  get(l, i)

iterator items*(l: SongList): Immutable[ref Song] =
  ## Iterate all songs in the list, as immutable references.
  ##
  for s in l.data:
    yield toImmutable(s)

iterator mitems*(l: var SongList): ref Song =
  ## Iterate all songs in the list, allowing mutations to song data.
  ##
  for s in l.data:
    yield s

proc data*(l: var SongList): var seq[ref Song] {.inline.} =
  ## Access the song list's data for manipulation.
  ##
  result = l.data

# Module ======================================================================

proc initModule(m: var Module) =
  m = Module(
    songs: initSongList(),
    instruments: initInstrumentTable(),
    waveforms: initWaveformTable(),
    tickrate: defaultTickrate,
    private: ModulePrivate(
      version: currentVersion,
      revisionMajor: currentFileMajor,
      revisionMinor: currentFileMinor
    )
  )

func initModule*(): Module =
  ## Creates an new [Module]. The returned module has:
  ##
  ## - 1 empty song
  ## - an empty instrument and waveform table
  ## - empty comments and artist information
  ## - tickrate set to [defaultTickrate] (59.7 Hz)
  ## - version information with the current application version and file
  ##   revision.
  ##
  initModule(result)

func newModule*(): ref Module =
  ## Creates a ref of a new [Module]. The returned module has the same
  ## initialization procedure as [initModule].
  ##
  new(result)
  initModule(result[])

func isValid*(m: Module): bool =
  ## Determines if the module is valid.
  ##
  result = m.songs.isValid()

func version*(m: Module): Version =
  ## Gets the version information that created this module. Initialized modules
  ## will have this set to `appVersion`.
  ## 
  m.private.version

func revisionMajor*(m: Module): int =
  ## Gets the file revision major the module was deserialized from. Initialized
  ## modules will have this set to `fileMajor`.
  ## 
  m.private.revisionMajor

func revisionMinor*(m: Module): int = 
  ## Gets the file revision minor the module was deserialized from. Initialized
  ## modules will have this set to `fileMinor`.
  ## 
  m.private.revisionMinor

func getTickrate*(m: Module; song: ByteIndex): Tickrate =
  ## Gets the tickrate for the given song id. The tickrate returned will be the
  ## song's tickrate override if set, otherwise it will be the module's
  ## tickrate.
  ## 
  if song < m.songs.len:
    return m.songs[song][].effectiveTickrate(m.tickrate)
  result = m.tickrate

converter toInfoString*(str: string): InfoString =
  ## Implicit conversion of a `string` to an `InfoString`. Only the first
  ## 32 characters of `str` are copied if `str.len` is greater than 32.
  ##
  for i in 0..<min(str.len, result.len):
    result[i] = str[i]

