##[

Module for editing pattern data.

]##

import 
  ./common,
  ./data

import std/options

export common

#
# Iterating selections:
#
# let iter = selection.iter()
# 
# for row in iter.rows():
#   for track in iter.tracks():
#     let columnIter = iter.columnIter(track)
#     for column in TrackSelect:
#       if columnIter.hasColumn(column):
#         <do something for this column>
#

type
  TrackColumn* = enum
    ## Enum of columns within a track
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
  
  PatternCursorBase[T: TrackColumn|TrackSelect] = object
    row*: int
      ## The row coordinate (0-[1..255])
    track*: int
      ## The track coordinate (0-3)
    column*: T
      ## The column coordinate within a track

  PatternCursor* = PatternCursorBase[TrackColumn]
    ## Object representating a cursor's position in a pattern.
    ##

  PatternAnchor* = PatternCursorBase[TrackSelect]
    ## Similar to a `PatternCursor` but differs in that its column member is a
    ## `TrackSelect` instead of `TrackColumn`. An anchor is used for specifying
    ## a boundary corner of a pattern selection.
    ##

  PatternSelection* = object
    ## A selection within a pattern. The region is determined from two corner
    ## anchors, which can be either top-left + bottom-right or top-right +
    ## bottom-left in any order. A normalized selection has the first corner
    ## top-left and the second bottom-right.
    ##
    corners: array[2, PatternAnchor]
  
  PatternIter* = PatternSelection
    ## Iterator object for iterating through a selection. Note this is the same
    ## type as a pattern selection, but will have its corners normalized for
    ## easy iteration.
    ##

  ColumnIter* = object
    ## Iterator object for iterating the selectable columns within a track.
    ##
    columnStart*, columnEnd*: TrackSelect

  PatternClip* = object
    ## A partial copy of pattern data that can be pasted elsewhere.
    ##
    data: seq[byte]
    location: PatternSelection

{. push raises: [] .}

template first(p: PatternSelection|PatternIter): PatternAnchor =
  p.corners[0]

template last(p: PatternSelection|PatternIter): PatternAnchor =
  p.corners[1]

func isEffect*(column: TrackSelect): bool =
  ## Determines if `column` is an effect column
  ##
  column >= selEffect1 and column <= selEffect3

func init*(T: typedesc[PatternCursor]; row, track: int; column: TrackColumn
          ): PatternCursor =
  ## Creates a pattern cursor with the given coordinates
  ##
  result = PatternCursor(
    row: row,
    track: track,
    column: column
  )

func isValid(c: PatternCursor|PatternAnchor; rows: int): bool =
  ## Determine if a cursor or anchor has valid coordinates
  ##
  c.row >= 0 and c.row < rows and c.track >= ChannelId.low.ord and c.track <= ChannelId.high.ord

func rows*(i: PatternIter): Slice[int] =
  ## Convert a pattern iterator to a slice of rows
  ##
  result = i.first.row..i.last.row

func tracks*(i: PatternIter): Slice[int] =
  ## Convert a pattern iterator to a slice of tracks
  ##
  result = i.first.track..i.last.track

func columnIter*(i: PatternIter; track: int): ColumnIter =
  ## Get a column iterator for a track
  ##
  if track == i.first.track:
    result.columnStart = i.first.column
  else:
    result.columnStart = low(TrackSelect)

  if track == i.last.track:
    result.columnEnd = i.last.column
  else:
    result.columnEnd = high(TrackSelect)

func columns*(i: ColumnIter): Slice[TrackSelect] =
  ## Convert a column iterator to a slice of columns
  ##
  result = i.columnStart..i.columnEnd

func hasColumn*(i: ColumnIter; col: TrackSelect): bool =
  ## Determine if the column iterator contains the given column
  ##
  col >= i.columnStart and col <= i.columnEnd

func effectNumber*(column: TrackSelect): EffectIndex =
  ## Convert a column to its corresponding effect number. 0 is returned
  ## for non-effect columns.
  ##
  result = max(column.int - selEffect1.int, 0).EffectIndex

func toSelect(column: TrackColumn): TrackSelect =
  ## Convert a column to a selectable column.
  ##
  result = case column
  of colNote: selNote
  of colInstrumentHi..colInstrumentLo: selInstrument
  of colEffectType1..colEffectParamLo1: selEffect1
  of colEffectType2..colEffectParamLo2: selEffect2
  else: selEffect3

func init*(T: typedesc[PatternSelection]; a: PatternAnchor; b = a
          ): PatternSelection =
  ## Create a pattern selection with the two boundary anchors `a` and `b`.
  ##
  result = PatternSelection(corners: [a, b])

proc translate*(s: var PatternSelection; rows: int) =
  ## Translate the section by a given number of rows.
  ##
  for anchor in s.corners.mitems:
    anchor.row = clamp(anchor.row.int + rows, low(ByteIndex), high(ByteIndex))

proc clamp*(s: var PatternSelection; maxRows: ByteIndex) =
  ## Clamp the selection to not exceed the given maximum number of rows.
  ##
  for anchor in s.corners.mitems:
    anchor.row = clamp(anchor.row, low(ByteIndex), maxRows)

func isValid*(s: PatternSelection; rows: TrackLen): bool =
  ## Determine if a pattern selection has valid coordinates, for a pattern of
  ## a given number of `rows`.
  ##
  s.first.isValid(rows) and s.last.isValid(rows)

func iter*(s: PatternSelection): PatternIter =
  ## Gets a pattern iterator for a selection.
  ##
  result.corners = s.corners

  # normalize the corners such that corner[0] <= corner[1]

  template first(): untyped = result.first
  template last(): untyped = result.last

  if first.row > last.row:
    swap(first.row, last.row)

  if first.track > last.track:
    swap(first.track, last.track)
    swap(first.column, last.column)
  elif first.track == last.track and first.column > last.column:
    swap(first.column, last.column)

func contains*(s: PatternSelection; pos: PatternAnchor): bool =
  ## Determine if a selection, `s`, contains an anchor, `pos`.
  ## 
  let iter = s.iter()
  template toAbsolute(track: int, col: TrackSelect): int =
    track.int * (high(TrackSelect).int + 1) + col.int
  let absStart = toAbsolute(iter.first.track, iter.first.column)
  let absEnd = toAbsolute(iter.last.track, iter.last.column)
  let absCol = toAbsolute(pos.track, pos.column)
  result = pos.row >= iter.first.row and pos.row <= iter.last.row and
       absCol >= absStart and absCol <= absEnd

proc moveTo*(s: var PatternSelection; pos: PatternAnchor) =
  ## Adjust the selection such that an anchor, `pos`, is contained within it.
  ## The selection is kept as is if `pos` is already contained.
  ##
  let iter = s.iter()
  s.corners = iter.corners

  # move to row
  s.first.row = pos.row
  s.last.row = pos.row + iter.last.row - iter.first.row

  # if the selection is just effects, we can move it to another effect column
  # otherwise, we can only move by tracks
  if iter.first.track == iter.last.track:
    # within the same track
    if iter.first.column.isEffect():
      # only effects are selected, move by column
      let begin = max(selEffect1, pos.column)
      s.first.column = begin
      s.last.column = (begin.int + (iter.last.column.int - iter.first.column.int)).TrackSelect
  
  # move to track
  s.first.track = pos.track
  s.last.track = max(ChannelId.high.ord.int, pos.track + iter.last.track - iter.first.track)

func toAnchor*(c: PatternCursor): PatternAnchor =
  ## Convert a pattern anchor to a cursor.
  ##
  result = PatternAnchor(
    row: c.row,
    track: c.track,
    column: c.column.toSelect()
  )

proc columnToOffset(column: TrackSelect): Natural =
  case column:
  of selNote:
    result = offsetOf(TrackRow, note)
  of selInstrument:
    result = offsetOf(TrackRow, instrument)
  of selEffect1:
    result = offsetOf(TrackRow, effects)
  of selEffect2:
    result = offsetOf(TrackRow, effects) + sizeof(Effect)
  of selEffect3:
    result = offsetOf(TrackRow, effects) + (sizeof(Effect) * 2)

proc columnToLength(column: TrackSelect): Natural =
  if column == high(TrackSelect):
    result = sizeof(TrackRow)
  else:
    result = columnToOffset(succ column)

proc rowLength(iter: PatternIter): Natural =
  # full tracks
  result = sizeof(TrackRow) * (iter.last.track - iter.first.track).int

  # first track partial
  result += columnToLength(iter.last.column)
  # last track partial
  result -= columnToOffset(iter.first.column)

func hasData*(c: PatternClip): bool =
  ## Determines if this clip contains pattern data that can be pasted
  ##
  result = c.data.len > 0

func selection*(c: PatternClip): PatternSelection =
  ## Gets the region of the clipped data as a pattern selection.
  ##
  c.location

template offsetInto[T](src: ptr T, offset: Natural): pointer =
  cast[ptr array[T.sizeof, byte]](src)[][offset].addr

proc save*(c: var PatternClip; song: Song; order: ByteIndex;
           region: PatternSelection) =
  ## Saves a portion of pattern data in the given song to a clip. The `order`
  ## is the index in the song order to use as the pattern data source. `region`
  ## is the location and amount of data to clip.
  ## 
  ## A RangeDefect will be raised if `region` is not a valid selection for
  ## a pattern in the song.
  ##

  if not region.isValid(song.trackLen):
    raise newException(RangeDefect, "selection is not in range of the pattern")

  c.location = region
  let iter = region.iter()

  let rowlen = rowLength(iter)
  let seqsize = rowlen * (iter.last.row - iter.first.row + 1)
  assert seqsize > 0
  c.data.setLen(seqsize)

  song.viewPattern(order, pattern):
    var bufIndex = 0
    for track in iter.tracks():
      let columnIter = iter.columnIter(track)
      let offset = columnToOffset(columnIter.columnStart)
      let length = columnToLength(columnIter.columnEnd) - offset

      # assert that we won't read past the bounds of a TrackRow
      assert offset + length <= sizeof(TrackRow)
      # assert that we're actually reading something
      assert length > 0

      var bufIndexInTrack = bufIndex
      for row in iter.rows():
        var src = pattern(track.ChannelId)[row]
        copyMem(
          c.data[bufIndexInTrack].addr,
          # convert the source row to an array of bytes, then take its
          # address from the offset
          offsetInto(src.addr, offset),
          length
        )
        bufIndexInTrack += rowlen

      # advance to the next track
      bufIndex += length

proc pasteImpl(c: PatternClip; song: var Song; order: ByteIndex;
               pos: Option[PatternAnchor]; mix: bool) =

  var iter = c.location.iter()
  let rowlen = rowLength(iter)
  var bufIndex = 0

  if pos.isSome():
    let tracksize = song.trackLen
    # when pos is set, we are pasting at a given location

    # determine the region we are pasting data to
    var destRegion = c.location
    destRegion.moveTo(pos.get())
    # update the iterator
    iter = destRegion.iter()
    # check the rows
    if iter.first.row < 0:
      if iter.last.row < 0:
        return # destination is out of bounds, nothing to paste
      bufIndex = rowlen * -iter.first.row # skip these rows
      iter.first.row = 0
    elif iter.first.row >= tracksize:
      return # out of bounds, nothing to paste
    iter.last.row = min(tracksize - 1, iter.last.row)
    if iter.last.track < ChannelId.low.ord or iter.first.track > ChannelId.high.ord:
      return
    iter.first.track = max(iter.first.track, ChannelId.low.ord)
    iter.last.track = min(iter.last.track, ChannelId.high.ord)

  proc paster(c: PatternClip; song: var Song; order: ByteIndex;
              mix: static[bool]) =
    song.editPattern(order, pattern):
      for track in iter.tracks():
        let columnIter = iter.columnIter(track)
        let offset = columnToOffset(columnIter.columnStart)
        let length = columnToLength(columnIter.columnEnd) - offset

        assert offset + length <= TrackRow.sizeof
        assert length > 0

        var bufIndexInTrack = bufIndex
        for row in iter.rows():
          let rowdata = pattern(track.ChannelId)[row].addr
          when mix:
            # mix paste, only empty columns will be pasted data from clip
            # create a (partial) TrackRow from the clip data
            var src: TrackRow
            copyMem(
              offsetInto(src.addr, offset),
              c.data[bufIndexInTrack].unsafeAddr,  # unsafeAddr because c.data is immutable
              length
            )
            if columnIter.hasColumn(selNote) and rowdata.note == 0:
              rowdata.note = src.note
            if columnIter.hasColumn(selInstrument) and rowdata.instrument == 0:
              rowdata.instrument = src.instrument
            for effectCol in selEffect1..selEffect3:
              if columnIter.hasColumn(effectCol):
                let effno = effectCol.effectNumber()
                if rowdata.effects[effno].effectType == etNoEffect.uint8:
                  rowdata.effects[effno] = src.effects[effno]
          else:
            # overwrite paste, copy clip data to destination track row
            copyMem(
              offsetInto(rowdata, offset),
              c.data[bufIndexInTrack].unsafeAddr,
              length
            )
          # advance to next row
          bufIndexInTrack += rowlen

        # advance to next track
        bufIndex += length
  if mix:
    paster(c, song, order, true)
  else:
    paster(c, song, order, false)

proc paste*(c: PatternClip; song: var Song; order: ByteIndex;
            pos: PatternCursor; mix = false) =
  ## Pastes or copies the clip's stored data into a song's pattern. `order` is
  ## the index in the song order of the pattern to paste into. `pos` is the
  ## position to insert the data at. When `mix` is `true`, the clipped data
  ## will be mixed in with the source data, where only the empty columns in the
  ## source are overwritten with the clip data. When `mix` is `false`, overwrite
  ## paste is used, which simply overwrites the source pattern's data with the
  ## clip's data.
  ##
  c.pasteImpl(song, order, some(pos.toAnchor()), mix)

proc restore*(c: PatternClip; song: var Song; order: ByteIndex) =
  ## Restores previously clipped data at its original location.
  ##
  c.pasteImpl(song, order, none[PatternAnchor](), false)

{. pop .}
