# Changelog

## Unreleased

### Added
 - (data) `toView` converter in data module for `Track -> TrackView`
 - (data) `clearNote`, `clearInstrument`, `setNote`, `setInstrument` procs for
   `TrackRow`
 - (data) `hash` procs for `Instrument` and `Waveform`
 - (data) `==` procs for `Instrument` and `Waveform`
 - (data) `uniqueIds` proc for `Table[T]`
 - (ir) `==` operator overload for `RowIr`
 - (ir) `runtime` proc for an `Operation`
 - (ir) `toTrackRow` proc for converting an `Operation` back into a `TrackRow`

### Changed
 - (data) `TrackView` is no longer a `distinct Track`, but a proxy object
   containing a `Track`. (There were some Nim internal errors using a distinct
   and borrow)
 - (ir) `fromIr(TrackIr)` returns a tuple containing a track and a bool
 - (ir) `setFromIr` proc now returns `bool`

### Removed
 - (ir) `SongPath` and `PatternVisit` types.

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
