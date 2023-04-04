##[

Version information about the library and Trackerboy application.

]##

type
  Version* = tuple[major, minor, patch: int]

const
  currentVersion* = (major: 0, minor: 7, patch: 1)
    ## libtrackerboy version tuple
  
  currentVersionString* = (
    $currentVersion[0] & "." &
    $currentVersion[1] & "." &
    $currentVersion[2]
  )
    ## libtrackerboy version string formatted as `major.minor.patch`

  # current file format revision: 1.1 (Rev C)

  currentFileMajor* = 1
    ## The current major revision of the file format
  currentFileMinor* = 1
    ## The current minor revision of the file format

  currentFileSerial* = 2
    ## The current serial number of the file format. It is incremented for each
    ## bump to the major or minor version.
