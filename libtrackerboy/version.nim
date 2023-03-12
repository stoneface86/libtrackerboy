##[

Version information about the library and Trackerboy application.

]##

import std/strformat

type
  Version* = object
    ## Data type for a semantic version. A semantic version consists of
    ## a major, minor and patch number.
    major*: Natural
    minor*: Natural
    patch*: Natural

template v*(m = 0, n = 0, p = 0): Version =
  ## Shorthand for initializing Version objects
  ## ie `v(0, 1, 0)` ==> `Version(major: 0, minor: 1, patch: 0)`
  Version(major: m, minor: n, patch: p)

const
  currentVersion* = v(0, 7, 1)
    ## libtrackerboy version

  # current file format revision: 1.1 (Rev C)

  currentFileMajor* = 1
    ## The current major revision of the file format
  currentFileMinor* = 1
    ## The current minor revision of the file format

func `$`*(v: Version): string =
  ## Convert a `Version` to a `string`. The string has the
  ## format `"major.minor.patch"`.
  &"{v.major}.{v.minor}.{v.patch}"

func `<`*(lhs: Version, rhs: Version): bool =
  ## `<` operator for comparing two Versions. Returns true if `rhs` is a
  ## newer version than `lhs`.
  lhs.major < rhs.major or lhs.minor < rhs.minor or lhs.patch < rhs.patch

func `<=`*(lhs: Version, rhs: Version): bool =
  ## `<=` operator for comparing two Versions. Returns true if `rhs` is a
  ## newer or equivalent version compared to `lhs`.
  lhs < rhs or lhs == rhs
