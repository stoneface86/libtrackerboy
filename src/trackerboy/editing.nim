##[

Module for editing pattern data.

]##

import common, data
export common

import std/options

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
        colNote
        colInstrumentHi
        colInstrumentLo
        colEffectType1
        colEffectParamHi1
        colEffectParamLo1
        colEffectType2
        colEffectParamHi2
        colEffectParamLo2
        colEffectType3
        colEffectParamHi3
        colEffectParamLo3

    TrackSelect* = enum
        selNote,
        selInstrument,
        selEffect1,
        selEffect2,
        selEffect3
    
    PatternCursorBase[T: TrackColumn|TrackSelect] = object
        row*: int
        track*: int
        column*: T

    PatternCursor* = PatternCursorBase[TrackColumn]

    PatternAnchor* = PatternCursorBase[TrackSelect]

    PatternSelection* = object
        corners: array[2, PatternAnchor]
    PatternIter* = PatternSelection # PatternIter is the same as PatternSelection, but guarantees that the corners are normalized

    ColumnIter* = object
        columnStart*, columnEnd*: TrackSelect

    PatternClip* = object
        data: seq[byte]
        location: PatternSelection

template first(p: PatternSelection|PatternIter): PatternAnchor =
    p.corners[0]

template last(p: PatternSelection|PatternIter): PatternAnchor =
    p.corners[1]

func isEffect*(column: TrackSelect): bool =
    column >= selEffect1 and column <= selEffect3

func init*(T: typedesc[PatternCursor], row: int, track: int, column: TrackColumn): PatternCursor =
    result = PatternCursor(
        row: row,
        track: track,
        column: column
    )

func isValid(c: PatternCursor|PatternAnchor, rows: int): bool =
    c.row >= 0 and c.row < rows and c.track >= ChannelId.low.ord and c.track <= ChannelId.high.ord

func rows*(i: PatternIter): Slice[int] =
    result = i.first.row..i.last.row

func tracks*(i: PatternIter): Slice[int] =
    result = i.first.track..i.last.track

func columnIter*(i: PatternIter, track: int): ColumnIter =
    if track == i.first.track:
        result.columnStart = i.first.column
    else:
        result.columnStart = low(TrackSelect)

    if track == i.last.track:
        result.columnEnd = i.last.column
    else:
        result.columnEnd = high(TrackSelect)

func columns*(i: ColumnIter): Slice[TrackSelect] =
    result = i.columnStart..i.columnEnd

func hasColumn*(i: ColumnIter, col: TrackSelect): bool =
    col >= i.columnStart and col <= i.columnEnd

func effectNumber*(column: TrackSelect): EffectIndex =
    result = max(column.int - selEffect1.int, 0).EffectIndex

func toSelect(column: TrackColumn): TrackSelect =
    result = case column
    of colNote: selNote
    of colInstrumentHi..colInstrumentLo: selInstrument
    of colEffectType1..colEffectParamLo1: selEffect1
    of colEffectType2..colEffectParamLo2: selEffect2
    else: selEffect3

func init*(T: typedesc[PatternSelection], a: PatternAnchor, b = a): PatternSelection =
    result = PatternSelection(corners: [a, b])

proc translate*(s: var PatternSelection, rows: int) =
    for anchor in s.corners.mitems:
        anchor.row = clamp(anchor.row.int + rows, low(ByteIndex), high(ByteIndex))

proc clamp*(s: var PatternSelection, maxRows: ByteIndex) =
    for anchor in s.corners.mitems:
        anchor.row = clamp(anchor.row, low(ByteIndex), maxRows)

func isValid*(s: PatternSelection, rows: TrackSize): bool =
    s.first.isValid(rows) and s.last.isValid(rows)


func iter*(s: PatternSelection): PatternIter =
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

func contains*(s: PatternSelection, pos: PatternAnchor): bool =
    let iter = s.iter()
    template toAbsolute(track: int, col: TrackSelect): int =
        track.int * (high(TrackSelect).int + 1) + col.int
    let absStart = toAbsolute(iter.first.track, iter.first.column)
    let absEnd = toAbsolute(iter.last.track, iter.last.column)
    let absCol = toAbsolute(pos.track, pos.column)
    result = pos.row >= iter.first.row and pos.row <= iter.last.row and
             absCol >= absStart and absCol <= absEnd

proc moveTo*(s: var PatternSelection, pos: PatternAnchor) =
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
    result = c.data.len > 0

func selection*(c: PatternClip): PatternSelection =
    c.location

template offsetInto[T](src: ptr T, offset: Natural): pointer =
    cast[ptr array[T.sizeof, byte]](src)[][offset].addr

proc save*(c: var PatternClip, pattern: CPattern, region: PatternSelection) =

    if not region.isValid(pattern.tracks[ch1][].len()):
        raise newException(RangeDefect, "selection is not in range of the pattern")

    c.location = region
    let iter = region.iter()

    let rowlen = rowLength(iter)
    let seqsize = rowlen * (iter.last.row - iter.first.row + 1)
    assert seqsize > 0
    c.data.setLen(seqsize)

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
        let trackRef = pattern.tracks[track.ChannelId]
        for row in iter.rows():
            var src = trackRef[][row]
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

proc pasteImpl(c: PatternClip, pattern: Pattern, pos: Option[PatternAnchor], mix: bool) =

    var iter = c.location.iter()
    let rowlen = rowLength(iter)
    var bufIndex = 0

    if pos.isSome():
        let tracksize = pattern.tracks[ch1][].len()
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

    proc paster(c: PatternClip, pattern: Pattern, mix: static[bool]) =
        for track in iter.tracks():
            let columnIter = iter.columnIter(track)
            let offset = columnToOffset(columnIter.columnStart)
            let length = columnToLength(columnIter.columnEnd) - offset

            assert offset + length <= TrackRow.sizeof
            assert length > 0

            var bufIndexInTrack = bufIndex
            let trackRef = pattern.tracks[track.ChannelId]
            for row in iter.rows():
                let rowdata = trackRef[][row].addr
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
        paster(c, pattern, true)
    else:
        paster(c, pattern, false)

proc paste*(c: PatternClip, pattern: Pattern, pos: PatternCursor, mix = false) =
    c.pasteImpl(pattern, some(pos.toAnchor()), mix)

proc restore*(c: PatternClip, pattern: Pattern) =
    c.pasteImpl(pattern, none[PatternAnchor](), false)

