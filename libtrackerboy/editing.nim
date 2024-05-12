##[

Procs for editing module data.

]##

import
  ./common,
  ./data

export ByteIndex, ChannelId

type
  TrackColumn* = enum
    ## Enum of columns within a track
    ##
    colNote             ## The note
    colInstrumentHi     ## The high-nibble of instrument
    colInstrumentLo     ## The low-nibble of instrument
    colEffectType1      ## The effect type byte for effect no 1
    colEffectParamHi1   ## The high-nibble of effect param for effect no 1
    colEffectParamLo1   ## The low-nibble of effect param for effect no 1
    colEffectType2      ## The effect type byte for effect no 2
    colEffectParamHi2   ## The high-nibble of effect param for effect no 2
    colEffectParamLo2   ## The low-nibble of effect param for effect no 2
    colEffectType3      ## The effect type byte for effect no 3 
    colEffectParamHi3   ## The high-nibble of effect param for effect no 3
    colEffectParamLo3   ## The low-nibble of effect param for effect no 3

  TrackSelect* = enum
    ## Enum of columns within a track that can be selected.
    ##
    selNote             ## The note
    selInstrument       ## The instrument
    selEffect1          ## Effect no 1
    selEffect2          ## Effect no 2
    selEffect3          ## Effect no 3

  PatternCursor* = object
    ## A position inside a pattern.
    ##
    row*: int
    track*: int
    column*: TrackColumn

  PatternAnchor* = object
    ## A position inside a pattern similiar to [PatternCursor], except that
    ## it uses [TrackSelect] as the column coordinate. Two anchors are needed
    ## to make a [PatternSelection], which are the starting and ending corners
    ## of a selection.
    ##
    row*: int
    track*: int
    select*: TrackSelect

  PatternSelection* = object
    ## A selection is a span of rows, tracks and selects within a pattern.
    ## Visual representation of a selection is equivalent to a rectangle, with
    ## the rows being the y coordinates, and the tracks, selects as the x
    ## coordinates.
    ##  - `rows`: The starting and ending row of the selection.
    ##  - `tracks`: The starting and ending track of the selection.
    ##  - `selects`: The starting and ending column of the selection.
    ##
    rows*: Slice[int]
    tracks*: Slice[int]
    selects*: Slice[TrackSelect]

  SelectionFit* = enum
    ## Enum of possible fits, or how much the selection actually selects in a
    ## pattern. Use this to check for validity.
    ##
    nothing ## nothing is selected: selection is invalid or out of bounds
    partial ## some of the selection fits the pattern
    whole   ## all of the selection fits within the pattern

  PatternClip* = object
    ## A partial copy of pattern data that can be pasted elsewhere.
    ##
    data: seq[TrackRow]
    location: PatternSelection

  PasteMode* = enum
    ## Modes of operation when pasting pattern data.
    ##  - `overwrite`: default, source data overwrites destination data.
    ##  - `mix`: Source data is only pasted when the destination column is
    ##           empty. In other words, the pasted data mixes with the existing
    ##           data at the destination.
    ##
    overwrite
    mix

const
  validTracks = ord(low(ChannelId))..ord(high(ChannelId))

func clamp(i: int; R: typedesc[SomeOrdinal]): R =
  result = R(clamp(i, ord(low(R)), ord(high(R))))

{. push raises: [] .}

# TrackColumn =================================================================

func toSelect*(column: TrackColumn): TrackSelect =
  ## Convert a column to a selectable column.
  ##
  result = case column
  of colNote: selNote
  of colInstrumentHi..colInstrumentLo: selInstrument
  of colEffectType1..colEffectParamLo1: selEffect1
  of colEffectType2..colEffectParamLo2: selEffect2
  else: selEffect3

# TrackSelect =================================================================

func effectNumber*(column: TrackSelect): int =
  ## Gets the effect index of the select. `0` is returned If `column` is not an
  ## effect.
  ##
  result = clamp(ord(column) - ord(selEffect1), 0, 2)

func isEffect*(column: TrackSelect): bool =
  ## Determines if `column` is an effect column
  ##
  result = column in selEffect1..selEffect3

# PatternCursor ===============================================================

func isValid(row, track: int; trackLen: TrackLen): bool =
  result = row in 0..(trackLen-1) and track in ord(low(ChannelId))..ord(high(ChannelId))

func initPatternCursor*(row, track: int; column: TrackColumn): PatternCursor =
  ## Creates a [PatternCursor] with the given coordinates.
  ##
  result = PatternCursor(row: row, track: track, column: column)

func toAnchor*(c: PatternCursor): PatternAnchor =
  ## Convert a cursor to an anchor.
  ##
  result = PatternAnchor(
    row: c.row,
    track: c.track,
    select: c.column.toSelect()
  )

func isValid*(c: PatternCursor; trackLen: TrackLen): bool =
  ## Determine if the cursor has valid coordinates for the given track len.
  ##
  result = isValid(c.row, c.track, trackLen)

# PatternAnchor ===============================================================

func initPatternAnchor*(row, track: int; select: TrackSelect): PatternAnchor =
  ## Creates a [PatternAnchor] with the given coordinates.
  ##
  result = PatternAnchor(row: row, track: track, select: select)

func isValid*(a: PatternAnchor; trackLen: TrackLen): bool =
  ## Determine if the anchor has valid coordinates for the given track len.
  ##
  result = isValid(a.row, a.track, trackLen)

# PatternSelection ============================================================

const
  noSelection* = PatternSelection(rows: 0 .. -1, tracks: 0 .. -1)
    ## Constant for a selection that has no selection whatsoever.
    ##


template top(s: PatternSelection): int = s.rows.a
template `top=`(s: var PatternSelection; val: int) = s.rows.a = val
template bottom(s: PatternSelection): int = s.rows.b
template `bottom=`(s: var PatternSelection; val: int) = s.rows.b = val
template left(s: PatternSelection): int = s.tracks.a
template `left=`(s: var PatternSelection; val: int) = s.tracks.a = val
template right(s: PatternSelection): int = s.tracks.b
template `right=`(s: var PatternSelection; val: int) = s.tracks.b = val
template leftSelect(s: PatternSelection): TrackSelect = s.selects.a
template `leftSelect=`(s: var PatternSelection; val: TrackSelect) = s.selects.a = val
template rightSelect(s: PatternSelection): TrackSelect = s.selects.b
template `rightSelect=`(s: var PatternSelection; val: TrackSelect) = s.selects.b = val

func initPatternSelection*(rows, tracks: Slice[int];
                           selects: Slice[TrackSelect];
                           ): PatternSelection =
  ## Create a pattern selection with the given boundaries.
  ##
  result = PatternSelection(rows: rows, tracks: tracks, selects: selects)

func initPatternSelection*(a: PatternAnchor; b = a): PatternSelection =
  ## Create a pattern selection from the two boundary anchors `a` and `b`.
  ##
  if a.row <= b.row:
    result.rows = a.row..b.row
  else:
    result.rows = b.row..a.row
  
  if a.track <= b.track:
    result.tracks = a.track..b.track
    result.selects = a.select..b.select
  else:
    result.tracks = b.track..a.track
    result.selects = b.select..a.select

func trackSelects*(s: PatternSelection; track: int): Slice[TrackSelect] =
  ## Gets the starting and ending selects within a single track of a pattern
  ## selection.
  ## 
  ## If the given track is not in the selection's span of tracks, then all
  ## columns are selected.
  ##
  if track == s.left:
    result.a = s.leftSelect
  else:
    result.a = low(TrackSelect)
  if track == s.right:
    result.b = s.rightSelect
  else:
    result.b = high(TrackSelect)

func getFit*(s: PatternSelection; rows: TrackLen): SelectionFit =
  ## Determine the fit for a selection in a pattern of the given size.
  ##
  const 
    nselects = len(low(TrackSelect)..high(TrackSelect))
    maxRight = ((validTracks.b + 1) * nselects) - 1
  
  if s.top > s.bottom:
    # selection is not normal
    return nothing
  
  let
    normalLeft = s.left * nselects + ord(s.leftSelect)
    normalRight = s.right * nselects + ord(s.rightSelect)
  
  if normalLeft > normalRight:
    # selection is not normal
    return nothing
  
  if s.bottom < 0 or s.top >= rows or normalRight < 0 or normalLeft > maxRight:
    # entire selection is out of bounds
    return nothing
  if s.top < 0 or normalLeft < 0 or s.bottom >= rows or normalRight > maxRight:
    # one of the coordinates is out of bounds
    return partial
  else:
    return whole

func hasOnlyEffects*(s: PatternSelection): bool =
  ## Determine if a selection contains only effect columns.
  ##
  result = s.left == s.right and s.leftSelect.isEffect()

func contains*(s: PatternSelection; pos: PatternAnchor): bool =
  ## Determine if a selection, `s`, contains an anchor, `pos`.
  ##
  if pos.row notin s.rows:
    return false
  if pos.track notin s.tracks:
    return false
  if pos.track == s.left and pos.select < s.leftSelect:
    return false
  if pos.track == s.right and pos.select > s.rightSelect:
    return false
  result = true

func clamped*(s: PatternSelection; trackLen = TrackLen(256)): PatternSelection =
  ## Calculates a new selection that is clamped in order to be a valid selection
  ## for a pattern of the given length. If the selection does not intersect the
  ## pattern region whatsoever, [noSelection] is returned.
  ## 
  case s.getFit(trackLen)
  of nothing:
    result = noSelection
  of partial:
    result.top = max(0, s.top)
    result.bottom = min(trackLen - 1, s.bottom)
    
    if s.left < validTracks.a:
      result.left = validTracks.a
      result.leftSelect = low(TrackSelect)
    else:
      result.left = s.left
      result.leftSelect = s.leftSelect
    
    if s.right > validTracks.b:
      result.right = validTracks.b
      result.rightSelect = high(TrackSelect)
    else:
      result.right = s.right
      result.rightSelect = s.rightSelect
  of whole:
    # no clamping needed
    result = s

func moved*(s: PatternSelection; pos: PatternAnchor): PatternSelection =
  ## Calculates a new selection by moving `s` to start at `pos`. The resulting
  ## selection may be invalid.
  ##
  result.top = pos.row
  result.bottom = pos.row + s.bottom - s.top
  result.left = pos.track
  result.right = pos.track + s.right - s.left
  if pos.select.isEffect() and s.hasOnlyEffects():
    # move by effects
    let 
      diff = int(s.rightSelect) - int(s.leftSelect)
      begin = max(selEffect1, pos.select)
    result.leftSelect = begin
    result.rightSelect = TrackSelect( min(int(begin) + diff, int(high(TrackSelect))) )
  else:
    result.selects = s.selects

func pos*(s: PatternSelection): PatternAnchor =
  ## Gets the starting position of the selection, as an anchor
  ##
  result = initPatternAnchor(s.top, s.left, s.leftSelect)

# PatternClip =================================================================

proc paste*(dest: var TrackRow; selected: Slice[TrackSelect]; src: TrackRow; 
            mode = overwrite) =
  ## Copies the selected columns from `src` onto `dest`, using the given paste
  ## mode. See [PasteMode] for more details on the possible modes.
  ##
  let alwaysPaste = mode == overwrite
  for select in selected:
    case select
    of selNote:
      if alwaysPaste or not dest.note.has:
        dest.note = src.note
    of selInstrument:
      if alwaysPaste or not dest.instrument.has:
        dest.instrument = src.instrument
    of selEffect1..selEffect3:
      let num = effectNumber(select)
      if alwaysPaste or dest.effects[num].cmd == 0:
        dest.effects[num] = src.effects[num]

proc save*(c: var PatternClip; pattern: PatternView; trackLen: TrackLen;
           region: PatternSelection) =
  ## Saves a portion of pattern data in the given song to a clip. 
  ## 
  ## - `pattern`: the pattern data to save from, invalid tracks are accepted.
  ## - `trackLen`: the length of the pattern, in rows.
  ## - `region`: is the selected region in the pattern to save.
  ## 
  ## If the region's fit is not `whole`, then nothing will be saved. See
  ## [SelectionFit] and [getFit] for more details.
  ##
  c.data.setLen(0)
  if region.getFit(trackLen) == whole:  
    c.location = region
    for track in region.tracks:
      let view = pattern[ChannelId(track)]
      if view.isValid():
        for row in region.rows:
          c.data.add(view[row])
      else:
        # invalid track, add empty rows
        c.data.setLen(c.data.len() + region.rows.len())
  else:
    c.location = noSelection

proc initPatternClip*(pattern: PatternView; trackLen: TrackLen; 
                      region: PatternSelection
                      ): PatternClip =
  ## Creates a [PatternClip] of the requested data from the song.
  ## 
  ## See [save].
  ##
  result.save(pattern, trackLen, region)


func hasData*(c: PatternClip): bool =
  ## Determines if this clip contains pattern data that can be pasted
  ##
  result = c.data.len > 0

func selection*(c: PatternClip): PatternSelection =
  ## Gets the region of the clipped data as a pattern selection.
  ##
  result = c.location

func data*(c: PatternClip): lent seq[TrackRow] =
  ## Access the clip's data buffer. The data is stored in the order specified
  ## by the clip's selection, from left-to-right (first track to last track)
  ## and top-to-bottom (first row to last row).
  ##
  result = c.data

type
  PasteAux = object
    # Auxillary data needed by paste
    selection: PatternSelection
      # destination region of the paste, clamped to fit within the bounds of
      # the pattern
    srcBufRowsPerTrack: int
      # number of rows per track in the clip's data buffer
      # add this to the buffer position to advance to the next track
    srcBufStart: int
      # starting position of the clip's data buffer when reading data to paste.

func getAux(src: PatternSelection; pos: PatternAnchor; trackLen: TrackLen): PasteAux =
  result.selection = src.moved(pos).clamped(trackLen)
  if result.selection.getFit(trackLen) != nothing:
    result.srcBufRowsPerTrack = src.rows.len()
    if result.selection.left < validTracks.a:
      result.srcBufStart = -(result.selection.left) * result.srcBufRowsPerTrack
    if result.selection.top < 0:
      result.srcBufStart -= result.selection.top
      
proc paste*(c: PatternClip; pattern: var Pattern; trackLen: TrackLen;
            pos: PatternAnchor; mode = overwrite) =
  ## Pastes or copies the clip's stored data into a pattern at the given
  ## starting position.
  ## 
  ## `mode` determines how the data is copied over, see [PasteMode] for details.
  ## 
  ## If the clip does not have any data then this proc does nothing. Any
  ## invalid track in the pattern will be ignored.
  ##
  if c.hasData():
    let aux = getAux(c.location, pos, trackLen)
    # check if a paste is possible at this position
    if aux.srcBufRowsPerTrack > 0:
      var bufPos = aux.srcBufStart
      
      for track in aux.selection.tracks:
        let nextPos = bufPos + aux.srcBufRowsPerTrack
        var data = pattern[ChannelId(track)]

        if data.isValid():
          let selected = aux.selection.trackSelects(track)
          for row in aux.selection.rows:
            paste(data[row], selected, c.data[bufPos], mode)
            inc bufPos

        bufPos = nextPos


proc restore*(c: PatternClip; pattern: var Pattern; trackLen: TrackLen) =
  ## Restores previously clipped data at its original location.
  ##
  c.paste(pattern, trackLen, c.location.pos(), overwrite)

{. pop .} # raises

