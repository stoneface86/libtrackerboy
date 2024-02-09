##[

Conversion of libtrackerboy data types to textual format.

]##

import
  ./data,
  ./notes

import std/[algorithm, options, parseutils, strutils]

type
  FixedString*[N: static int] = array[N, char]
    ## Type for a fixed-length string implemented as an array of characters.
    ## Since most of the strings in this module are a fixed length, this
    ## type is used instead of `string` for optimization purposes. If a
    ## `string` is needed, use the [$] overload.
    ##
  
  NoteString* = FixedString[3]
    ## Fixed string type that contains the textual version of a note column.
    ## This string will always contain 3 characters.
    ## 
    ## The format of this string is one of the following:
    ## * `...` : an unset column or no note.
    ## * `NSO` : a set note where `N` is the note letter from A to G. `S` is
    ##           a separator that indicates if the note is a natural, sharp or
    ##           a flat. `-` is used for naturals, `#` is used for sharps and
    ##           `b` is used for flats. `O` is the octave from 2 to 8.
    ## * `---` : a set note containing a note cut.
    ## 
    ## Examples:
    ## * `...` represents `noteNone`
    ## * `E-3` represents `noteColumn(5, 3)`
    ## * `D#3`, `Eb3` represents `noteColumn(4, 3)`
    ## * `---` represents `noteColumn(noteCut)`
    ##
  
  InstrumentString* = FixedString[2]
    ## Fixed string type that contains the textual version of an instrument
    ## column. This string will always contain 2 characters.
    ## 
    ## The format of this string is one of the following:
    ## * `..`: no instrument set
    ## * `XX`: a set instrument where `XX` is the instrument id in hexadecimal.
    ## 
    ## Examples:
    ## * `..` represents `instrumentNone`
    ## * `00` represents `instrumentColumn(0)`
    ## * `12` represents `instrumentColumn(18)`
    ##
  
  EffectString* = FixedString[3]
    ## Fixed string type that contains the textual version of an `Effect`.
    ## This string will always contain 3 characters.
    ## 
    ## The format of this string is one of the following:
    ## * `...`: no effect is set
    ## * `EPP`: a set effect where E is a character the determines the effect
    ##          type, and PP is the effect's parameter in hexadecimal.
    ## 
    ## Examples:
    ## * `...` represents `effectNone`
    ## * `V03` represents `Effect.init(etSetTimbre, 3)`
    ## * `C00` represents `Effect.init(etPatternHalt, 0)`
    ##
  
  TrackRowString* = FixedString[18]
    ## Fixed string type that contains the textual version of a `TrackRow`.
    ## This string will always contain 18 characters.
    ## 
    ## The format of this string is `NNN II EEE EEE EEE` where
    ## * `NNN` is a [NoteString] of the row's note field
    ## * `II` is an [InstrumentString] of the row's instrument field
    ## * `EEE` is an [EffectString] for each effect in the row's effects array.
    ## 
    ## Effects are ordered from left to right, so the first effect is located
    ## after `II` and before the second `EEE`.
    ## 
  
  OrderRowString* = FixedString[11]
    ## Fixed string type that contains the textual version of an `OrderRow`.
    ## This string will always contain 11 characters.
    ##
    ## The format of this string is `T1 T2 T3 T4` where
    ## * `T1` is the track id for channel 1, in hexadecimal
    ## * `T2` is the track id for channel 2, in hexadecimal
    ## * `T3` is the track id for channel 3, in hexadecimal
    ## * `T4` is the track id for channel 4, in hexadecimal
    ##
  
  WaveDataString* = FixedString[32]
    ## Fixed string type that contains the textual version of a `WaveData`.
    ## This string will always contain 32 characters.
    ## 
    ## The format of this string is 32 hexadecimal literals, where each literal
    ## is a single sample of the wave data.
    ## 
    ## Examples:
    ## * `00000000000000000000000000000000` is an empty waveform
    ## * `0123456789ABCDEFFEDCBA9876543210` is a triangular waveform
    ##

const
  hexCharMap = [ 
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
  ]
  noteMap: array[bool, string] = [
    "C-C#D-D#E-F-F#G-G#A-A#B-", # sharps
    "C-DbD-EbE-F-GbG-AbA-BbB-"  # flats
  ]
  # uint8 is used to save on program size
  charNoteToIndex: array['A' .. 'G', uint8] = [ 
    A.uint8, B.uint8, C.uint8, D.uint8, E.uint8, F.uint8, G.uint8 
  ]
  trackRowSpaces = [3u8, 6, 10, 14]

  noValueChar* = '.'
    ## A repeating character that is used to represent a column not having a
    ## value.
    ##


{. push raises: [] .}

func `$`*[N](str: FixedString[N]): string =
  ## Convert a fixed string to a regular string.
  ##
  result = newString(N)
  for i in 0..<N:
    result[i] = str[i]

func toHex(num: uint8): array[2, char] =
  result[0] = hexCharMap[num shr 4]
  result[1] = hexCharMap[num and 0xF]

proc overwrite(dest: var openArray[char]; src: openArray[char]; at: int) =
  var cursor = at
  for ch in src:
    dest[cursor] = ch
    inc cursor

# text conversion =============================================================

func noteText*(note: NoteColumn; useFlats = false): NoteString =
  ## Converts a note column to textual representation. See [NoteString] for
  ## details on the format of the text. 
  ## 
  ## Sharps are used by default, set `useFlats` to `true` if flats are desired.
  ## 
  if note.has():
    let noteValue = note.value()
    if noteValue == noteCut:
      result.fill('-')
    else:
      let 
        note = toPair(NoteIndex(noteValue))
        start = note.letter * 2
      result.overwrite(toOpenArray(noteMap[useFlats], start, start + 1), 0)
      result[2] = chr(ord('0') + note.octave) 
  else:
    result.fill(noValueChar)

func instrumentText*(instrument: InstrumentColumn): InstrumentString =
  ## Converts an instrument column to textual representation. See
  ## [InstrumentString] for details on the format of the text.
  ##
  if instrument.has():
    result = toHex(instrument.value())
  else:
    result.fill(noValueChar)

func effectText*(effect: Effect): EffectString =
  ## Converts an Effect to textual representation. See [EffectString] for
  ## details on the format of the text.
  ##
  if effect.effectType == etNoEffect.uint8:
    result.fill(noValueChar)
  else:
    result[0] = effectTypeToChar(effect.effectType)
    let param = toHex(effect.param)
    result[1] = param[0]
    result[2] = param[1]

func orderRowText*(row: OrderRow): OrderRowString =
  ## Converts an OrderRow to textual representation. See [OrderRowString] for
  ## details on the format of the text.
  ##
  proc setColumn(str: var OrderRowString; val: uint8; at: int) =
    let hex = toHex(val)
    str[at] = hex[0]
    str[at + 1] = hex[1]
  
  setColumn(result, row[ch1], 0)
  var cursor = 2
  for ch in ch2..ch4:
    result[cursor] = ' '
    inc cursor
    setColumn(result, row[ch], cursor)
    cursor += 2
  

func trackRowText*(row: TrackRow; useFlats = false): TrackRowString =
  ## Converts a `TrackRow` to textual representation. See [TrackRowString] for
  ## details on the format of the text.
  ##
  result.overwrite(noteText(row.note, useFlats), 0)
  result.overwrite(instrumentText(row.instrument), 4)
  var cursor = 7
  for e in row.effects:
    result.overwrite(effectText(e), cursor)
    cursor += 4
  for i in trackRowSpaces:
    result[i] = ' '

func sequenceText*(s: Sequence): string =
  ## Converts a `Sequence` to textual representation. Since sequences vary in
  ## length, a regular `string` is returned.
  ## 
  ## The format of the string returned is each element in the sequence as an
  ## integer separated by spaces. A `|` is used to indicate the location of
  ## the loop index, if present, and is placed before the element it refers to.
  ## 
  ## Examples:
  ## * `1 2 3` is a sequence with no loop index and has values 1, 2 and 3.
  ## * `-1 | 3` is a sequence with a loop index of 1 and has values -1 and 3.
  ## 
  proc addItem(str: var string; data: openArray[uint8]; index: int; loop: int) =
    if loop == index:
      str.add("| ")
    str.add($(cast[int8](data[index])))
  
  if s.data.len > 0:
    let loop = if s.loopIndex.isSome(): s.loopIndex.get().int else: -1
    addItem(result, s.data, 0, loop)
    for i in 1..<s.data.len:
      result.add(' ')
      addItem(result, s.data, i, loop)


func waveText*(wave: WaveData): WaveDataString =
  ## Converts a `WaveData` to textual representation. See [WaveDataString] for
  ## details on the format of the text.
  ##
  var i = 0
  for sample in wave:
    let hex = toHex(sample)
    result[i] = hex[0]
    inc i
    result[i] = hex[1]
    inc i

# parsing =====================================================================

func allSame(chars: openArray[char]): bool =
  result = true
  if chars.len > 0:
    let first = chars[0]
    for i in 1..<chars.len:
      if chars[i] != first:
        return false

template toOpenArray(str: string): openArray[char] =
  toOpenArray(str, 0, str.len - 1)

func parseNote*(str: openArray[char]): Option[NoteColumn] =
  ## Parse the character buffer containing the textual representation of a
  ## `NoteColumn`, and return it on success. See [NoteString] for details on
  ## the format that is expected.
  ## 
  ## Parsing will fail for any of the following:
  ## * `str.len` does not match the expected amount
  ## * the note letter was not a valid note
  ## * the separator was not a sharp `#`, flat `b` or natural `-`
  ## * the octave was not a valid digit
  ## * the octave was not in TrackerBoy's octave range
  ##
  if str.len != NoteString.len:
    return

  if allSame(str):
    case str[0]
    of '-':
      result = some(noteColumn(noteCut))
    of noValueChar:
      result = some(noteNone)
    else:
      discard    
  else:
    let letterCh = str[0].toUpperAscii()
    if letterCh notin 'A' .. 'G':
      return
    var letter = Letter(charNoteToIndex[letterCh])

    case str[1]
    of '#':
      inc letter
    of 'b':
      if letter == Letter.low:
        letter = Letter.high
      else:
        dec letter
    of '-':
      discard
    else: 
      return

    let octave = str[2].ord - '0'.ord
    if octave in Octave.low..Octave.high:
      result = some(noteColumn(toNote(letter, octave)))

func parseNote*(str: string): Option[NoteColumn] {.inline.} =
  ## Convenience overload that takes a `string`.
  ## See [parseNote(openArray[char])].
  ##
  result = parseNote(toOpenArray(str))

func hexCharToInt(ch: char): int =
  case ch
  of '0'..'9': ord(ch) - ord('0')
  of 'a'..'f': 10 + ord(ch) - ord('a')
  of 'A'..'F': 10 + ord(ch) - ord('A')
  else: -1

func parseHex(hi, lo: char; ): int =
  let
    hiInt = hexCharToInt(hi)
    loInt = hexCharToInt(lo)
  if hiInt != -1 and loInt != -1:
    result = (hiInt shl 4) or loInt
  else:
    result = -1

func parseInstrument*(str: openArray[char]): Option[InstrumentColumn] =
  ## Parse the character buffer containing the textual representation of an
  ## `InstrumentColumn`, and return it on success. See [InstrumentString] for
  ## details on the format that is expected.
  ## 
  ## Parsing will fail for any of the following:
  ## * `str.len` does not match the expected amount
  ## * an invalid hexadecimal number was given
  ## * the instrument id was outside the range of `TableId` (id >= 64)
  ##
  if str.len == InstrumentString.len:
    if str == [ noValueChar, noValueChar ]:
      result = some(instrumentNone)
    else:
      let instrument = parseHex(str[0], str[1])
      if instrument in TableId.low.int .. TableId.high.int:
        result = some(instrumentColumn(instrument.TableId))

func parseInstrument*(str: string): Option[InstrumentColumn] {.inline.} =
  ## Convenience overload that takes a `string`.
  ## See [parseInstrument(openArray[char])].
  ##
  result = parseInstrument(toOpenArray(str))

func parseEffectType*(ch: char): EffectType =
  ## Converts a character to the `EffectType` it represents. For any
  ## unrecognized character, `etNoEffect` is returned.
  ## 
  for et in (etNoEffect.succ)..(EffectType.high):
    if ch == effectCharMap[et]:
      return et
  result = etNoEffect

func parseEffect*(str: openArray[char]): Option[Effect] =
  ## Parse the character buffer containing the textual representation of an
  ## `Effect`, and return it on success. See [EffectString] for details on
  ## the format that is expected.
  ## 
  ## Parsing will fail for any of the following:
  ## * `str.len` does not match the expected amount
  ## * The effect type was not recognized
  ## * The effect parameter was not a valid hexadecimal number
  ##
  if str.len == EffectString.len:
    if str == [ noValueChar, noValueChar, noValueChar ]:
      result = some(effectNone)
    else:
      let et = parseEffectType(str[0])
      if et != etNoEffect:
        let ep = parseHex(str[1], str[2])
        if ep != -1:
          result = some(Effect.init(et, ep.uint8))

func parseEffect*(str: string): Option[Effect] {.inline.} =
  ## Convenience overload that takes a `string`.
  ## See [parseEffect(openArray[char])].
  ##
  result = parseEffect(toOpenArray(str))

func parseTrackRow*(str: openArray[char]): Option[TrackRow] =
  ## Parse the character buffer containing the textual representation of a
  ## `TrackRow`, and return it on success. See [TrackRowString] for details on
  ## the format that is expected.
  ## 
  ## Parsing will fail for any of the following:
  ## * `str.len` does not match the expected amount
  ## * The string did not contain the required space separators
  ## * The note column could not be parsed
  ## * The instrument column could not be parsed
  ## * One of the effect columns could not be parsed
  ##
  if str.len == TrackRowString.len:
    for i in trackRowSpaces:
      if str[i] != ' ':
        return
    
    var row: TrackRow
    let note = parseNote(toOpenArray(str, 0, 2))
    if note.isNone():
      return
    row.note = note.get()

    let instrument = parseInstrument(toOpenArray(str, 4, 5))
    if instrument.isNone():
      return
    row.instrument = instrument.get()

    var cursor = 7
    for e in mitems(row.effects):
      let effect = parseEffect(toOpenArray(str, cursor, cursor + 2))
      if effect.isNone():
        return
      e = effect.get()
      cursor += 4
    result = some(row)

func parseTrackRow*(str: string): Option[TrackRow] {.inline.} =
  ## Convenience overload that takes a `string`.
  ## See [parseTrackRow(openArray[char])].
  ##
  result = parseTrackRow(toOpenArray(str))

func parseOrderRow*(str: openArray[char]): Option[OrderRow] =
  ## Parse the character buffer containing the textual representation of an
  ## `OrderRow`, and return it on success. See [OrderRowString] for details on
  ## the format that is expected.
  ## 
  ## Parsing will fail for any of the following:
  ## * `str.len` does not match the expected amount
  ## * The string contained an invalid hexadecimal character
  ## * The string did not contain the required space separators
  ##
  if str.len == OrderRowString.len:
    if str[2] == ' ' and str[5] == ' ' and str[8] == ' ':  
      var
        cursor = 0
        row: OrderRow
      for track in mitems(row):
        let hex = parseHex(str[cursor], str[cursor + 1])
        if hex == -1:
          return
        track = uint8(hex)
        cursor += 3
      result = some(row)

func parseOrderRow*(str: string): Option[OrderRow] {.inline.} =
  ## Convenience overload that takes a `string`.
  ## See [parseOrderRow(openArray[char])].
  ##
  result = parseOrderRow(toOpenArray(str))

func parseWave*(str: openArray[char]): Option[WaveData] =
  ## Parse the character buffer containing the textual representation of a
  ## `WaveData`, and return it on success. See [WaveDataString] for details on
  ## the format that is expected.
  ## 
  ## Parsing will fail for any of the following:
  ## * `str.len` does not match the expected amount
  ## * The string contained an invalid hexadecimal character
  ##
  if str.len == WaveDataString.len:
    var
      wave: WaveData
      cursor = 0
    for sample in mitems(wave):
      let hex = parseHex(str[cursor], str[cursor + 1])
      if hex == -1:
        return
      sample = uint8(hex)
      cursor += 2
    result = some(wave)

func parseWave*(str: string): Option[WaveData] {.inline.} =
  ## Convenience overload that takes a `string`.
  ## See [parseWave(openArray[char])].
  ##
  result = parseWave(toOpenArray(str))

func parseSequence*(str: string; minVal = low(int8); maxVal = high(int8)
                   ): Option[Sequence] =
  ## Parse the string containing the textual representation of a Sequence, and
  ## return it on success. `minVal` and `maxVal` can be used to clamp the
  ## parsed values.
  ## 
  ## Parsing will fail for any of the following:
  ## * more than one loop index, '|', was encountered
  ## * the number of values parsed exceeded 256
  ## * a number could not be parsed as a decimal integer
  ##
  let lastPos = str.len - 1
  var 
    i = 0
    loopIndex: Option[ByteIndex]
    buf: FixedSeq[256, uint8]
  while true:
    i += skipWhitespace(toOpenArray(str, i, lastPos))
    if i > lastPos:
      break
    if str[i] == '|':
      if loopIndex.isSome():
        return # loop index already parsed
      else:
        loopIndex = some(buf.len.ByteIndex)
        inc i
    else:
      var num: int
      let chars = try: parseInt(toOpenArray(str, i, lastPos), num)
                  except ValueError: 0
      if chars == 0:
        return # bad number
      else:
        if buf.len == 256:
          return # sequence is too big
        i += chars
        buf.add(cast[uint8](clamp(num, int(minVal), int(maxVal))))
  result = some(Sequence.init(toOpenArray(buf.data, 0, buf.len - 1), loopIndex))

# literal functions, construct libtrackerboy data from text at compile time

template litImpl[T](input: Option[T]; error: string) =
  let parsed = input
  doAssert input.isSome(), error
  result = parsed.get()

func litNote*(str: string): NoteColumn {. compileTime .} =
  ## Construct a note column from its textual representation at compile time.
  ## An `AssertError` will be raised if `str` could not be parsed.
  ##
  litImpl(parseNote(str), "Invalid note string")

func litInstrument*(str: string): InstrumentColumn {. compileTime .} =
  ## Construct an instrument column from its textual representation at
  ## compile time. An `AssertError` will be raised if `str` could not be parsed.
  ##
  litImpl(parseInstrument(str), "Invalid instrument string")

func litEffect*(str: string): Effect {. compileTime .} =
  ## Construct an effect from its textual representation at compile time.
  ## An `AssertError` will be raised if `str` could not be parsed.
  ##
  litImpl(parseEffect(str), "Invalid effect string")

func litWave*(str: string): WaveData {. compileTime .} =
  ## Construct waveform data from its textual representation at compile time.
  ## An `AssertError` will be raised if `str` could not be parsed.
  ##
  litImpl(parseWave(str), "Invalid wave string")

func litSequence*(str: string; minVal = low(int8); maxVal = high(int8)
                 ): Sequence {. compileTime .} =
  ## Construct a sequence from its textual representation at compile time.
  ## An `AssertError` will be raised if `str` could not be parsed.
  ##
  litImpl(parseSequence(str, minVal, maxVal), "Invalid sequence string")

func litTrackRow*(str: string): TrackRow {. compileTime .} =
  ## Construct a track row from its textual representation at compile time.
  ## An `AssertError` will be raised if `str` could not be parsed.
  ##
  litImpl(parseTrackRow(str), "Invalid track row string")

func litOrderRow*(str: string): OrderRow {. compileTime .} =
  ## Construct an order row from its textual representation at compile time.
  ## An `AssertError` will be raised if `str` could not be parsed.
  ##
  litImpl(parseOrderRow(str), "Invalid order row string")

{. pop .}

