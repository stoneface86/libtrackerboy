# Changelog

## Unreleased

### Important

- **Nim 2.0.0 is now required.**
- All init procs have been renamed, `init(T, ...)` -> `initT(...)`
- `Immutable[ref T]` has been replaced by `iref[T]`
- `Immutable[ptr T]` has been replaced by `iptr[T]`
- Renamed `toImmutable` -> `immutable`

The API in the data module has been completely overhauled:
- removed types `EffectIndex`, `EffectColumns`
- added consts `rangeSpeed`, `noLoopPoint`, `noteNone`, `instrumentNone` and
  `effectNone`
- Speed
  - is now a `distinct uint8`
  - Renamed `speedToFloat` -> `toFloat`
  - Renamed `speedToTempo` -> `tempo`
  - Added `toSpeed`, `isValid`, `$` procs
- added type `LoopPoint`
- Sequence
  - renamed field `loopIndex` -> `loop`
  - `loop` field is now of type `LoopPoint`
  - add `isValid` proc
  - removed `data`, `data=` procs
- Instrument
  - removed `new` overload
  - add `hash` overload
- Waveform
  - removed `new` overload
  - add `hash` overload
- Renamed `SequenceSize` -> `SequenceLen`
- Renamed `OrderSize` -> `OrderLen`
- Table
  - added proc `uniqueIds`
- Order
  - `Order` is now a `seq[OrderRow]`
  - add proc `initOrderRow`, template `orow`
  - removed procs `[]`, `[]=`, `len`, `setLen`, `setData`, `add`, `insert`,
    `remove` and `swap`
- Effect
  - renamed `EffectType` -> `EffectCmd`, each enum starts with `ec` instead of `et`
  - renamed field `effectType` -> `cmd`
  - renamed proc `effectTypeShortensPattern` -> `shortensPattern`
  - renamed proc `toEffectType` -> `toEffectCmd`
  - renamed proc `effectTypeToChar` -> `effectCmdToChar`
- TrackRow
  - add types `NoteColumn` and `InstrumentColumn`
  - field `note` is now of type `NoteColumn`
  - field `instrument` is now of type `InstrumentColumn`
  - added procs `has`, `value`, `asOption`, `$` for Column types
  - removed procs `clearNote`, `clearInstrument`, `hasNote`, `hasInstrument`,
    `setNote`, `setInstrument`, `queryNote`, `queryInstrument`,
- Track
  - Track data is now stored using a `ref seq[TrackRow]`
  - added proc `data` for accessing the track's data seq
  - removed procs `setNote`, `setInstrument`, `setEffect`, `setEffectType`,
    `setEffectParam`
- TrackView
  - `TrackView` is no longer a `distinct Track`, but a proxy object containing
     a `Track`. (There were some Nim internal errors using the borrow pragma).
  - add converter `toView`
- added types `Pattern`, `PatternView`, `SomePattern`, `SomeTrack`
- Song
  - add procs `$`, `isValid`, `removeUnusedTracks`, `allocateTracks`, `getRow`,
    `effectiveTickrate`, `patternLen`
  - `trackLen` is now a property instead of a field
  - `editPattern` and `viewPattern` templates inject a `Pattern` variable
    instead of a template. Use `value[channel]` instead of `value(channel)`
- add types `SongPos`, `SongSpan`
- SongList
  - add procs `isValid`, `data`
  - removed overload for `get` that returns a `ref Song`
  - added proc `mget` that returns a `ref Song`
  - removed procs `add`, `duplicate`, `remove`, `moveUp`, `moveDown`
- Module
  - add proc `isValid`

### Added
 - (common) `iref[T]` and `iptr[T]` (these replace `Immutable[T]`)
 - (common) `FixedSeq[N, T]` type for a seq-like container of fixed capacity.
 - (common) `Tristate` enum
 - (ir) `==` operator overload for `RowIr`
 - (ir) `runtime` proc for an `Operation`
 - (ir) `toTrackRow` proc for converting an `Operation` back into a `TrackRow`
 - (ir) overload for `toIr` proc for partial ir conversion
 - (note) `NoteRange`, `Octave`, `Letter`, `NoteIndex` and `NotePair` types
 - (note) procs for converting a `NoteIndex` to a `NotePair` and vice versa
 - New module, `text`, for text conversion and parsing of libtrackerboy data.
 - New module, `tracking`, for tracking playback of a song.

### Changed
 - (data) The data module has been overhauled, see above
 - (ir) `fromIr(TrackIr)` returns a tuple containing a track and a bool
 - (ir) `setFromIr` proc now returns `bool`
 - (ir) renamed proc `toEffectType` -> `toEffectCmd`
 - modules `apucontrol`, `enginecontrol` and `enginestate` are no longer
   private and are now located in `libtrackerboy/engine`
 - (engine) `play` proc signature takes a `SongPos` instead of two ints
 - (editing) completely rewritten, safer and easier to use.

### Deprecated
 - (note) `note`

### Removed
 - (common) `MixMode` type and related procs.
 - (common) `Immutable[T]` type and related procs.
 - (data) `$` procs for `Sequence` and `WaveData` types. Use text module instead.
 - (data) `parseSequence` proc, use text module instead.
 - (data) `parseWave` proc, use text module instead.
 - (ir) `SongPath` and `PatternVisit` types.
 - (editing) `PatternIter`, `ColumnIter` types

## [0.8.3] - 2023-11-08

### Fixed
 - Error with nimble package: `cannot open file: build.nims`

## [0.8.2] - 2023-11-01

### Added
 - runtime calculation procs in engine module `engine.runtime`. These calculate
   the time of a song, in frames.

### Changed
 - `Duration` type in exports/wav renamed to `SongDuration`, it now contains
   a number of loops or a time amount using `Duration` from `std/times`
 - WavExporter's progress and progressMax procs are now always in units of
   frames.

### Fixed
 - Bug with arpeggio sequences treating -1, -2, etc as 255, 254, etc. The
   was added as an unsigned byte instead of a signed one. This caused songs
   with negative values in arp sequences to have the highest note play
   (resulting in high pitched chirping).

## [0.8.1] - 2023-10-18

### Fixed
 - Wav exporter never finishing for some songs when using a loop duration.
 - Default timbre for CH4 is now 0, was incorrectly set to 3

## [0.8.0] - 2023-06-14

### Added
 - `Tickrate` type which contains a system and customFramerate.
 - `hertz`, `getTickrate` procs to data module.
 - `items` and `mitems` iterators for `SongList`

### Changed
 - Added `skEnvelope` to `SequenceKind` enum.
 - `Instrument` type no longer contains the `initEnvelope` and `envelope` fields.
 - `Instrument` now contains a sequence of type `skEnvelope`
 - `Song` now has a `tickrate` field, for an optional tickrate override.
 - File revision is now at 2.0, rev D.

### Removed
 - `framerate` proc in data module. Use `getTickrate` proc or `Module.tickrate`.

## [0.7.2] - 2023-04-04

### Added
 - `ir` module for intermediate representation of pattern data. A utility module
   for converting module data to other formats.
 - `currentFileSerial` const to version module
 - `currentVersionString` const to version module
 - Implementation of the `L00` effect (lock/music priority).
 - Support for Nim 2.0.0. As of 2023-04-04, the library compiles and passes
   tests with Nim 2.0.0 Release Candidate 2.

### Changed
 - `Version` type is now a `tuple`

### Removed
 - `<=` and `<` procs in version module. The generic overload provided by
   Nim's system module should be used instead.
 - `$` overload for `Version`. Use `currentVersionString` instead of `$currentVersion`.
 - `v` template in version module, use a tuple constructor instead.

## [0.7.1] - 2022-12-27

### Added
 - `TrackView` and `SomeTrack` types to libtrackerboy/data
 - `Song.getTrackView` member proc

### Changed
 - Track data is stored using a `ref array` instead of a `seq`
 - Each track is allocated for 256 rows, regardless of the song's trackLen
   parameter. This allows for changing the trackLen without losing data at
   the cost of extra memory consumption when trackLen < 256.

### Removed
 - `len` and `setLen` overloads for `Track` instances, use the `Track.len` 
   field instead.
 - `trackLen` and `setTrackLen` procs, use the `Song.trackLen` field instead.

## [0.7.0] - 2022-11-09

Initial version of the Nim rewrite, also the canonical first version of the
library.

## Before v0.7.0

All code before v0.7.0  is UNVERSIONED, or rather, used trackerboy's versioning.
This is due to the fact that the back end was originally in the same repo as
the front end, and thus used the same version history.

All code before v0.7.0 is also known as "before Nim", where the original
implementation of this library was in C++.
