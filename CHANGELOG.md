# Changelog

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