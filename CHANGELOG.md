# Changelog

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
