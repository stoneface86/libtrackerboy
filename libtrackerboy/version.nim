##[

Version information about the library and Trackerboy application.

]##

type
  Version* = tuple[major, minor, patch: int]

const
  currentVersion* = (major: 0, minor: 7, patch: 2)
    ## libtrackerboy version tuple
  
  currentVersionString* = (
    $currentVersion[0] & "." &
    $currentVersion[1] & "." &
    $currentVersion[2]
  )
    ## libtrackerboy version string formatted as `major.minor.patch`

  # current file format revision: 1.1 (Rev C)

  currentFileMajor* = 2
    ## The current major revision of the file format
  currentFileMinor* = 0
    ## The current minor revision of the file format

  currentFileSerial* = 3
    ## The current serial number of the file format. It is incremented for each
    ## bump to the major or minor version.
    ## 
    ## History:
    ## * 0: Revision A (0.0)
    ## * 1: Revision B (1.0)
    ## * 2: Revision C (1.1)
    ## * 3: Revision D (2.0)
