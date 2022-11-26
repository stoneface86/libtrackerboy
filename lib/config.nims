--noMain
--app:staticLib
--path:"../"

const cmakeBuildType {.strdefine.} = "Debug"

proc releaseBuild() =
    --define:release
    --define:strip
    --define:lto

import std/strutils

case cmakeBuildType.toLowerAscii()
of "release":
    releaseBuild()
of "minsizerel":
    releaseBuild()
    --opt:size
of "relwithdebinfo":
    releaseBuild()
    --debuginfo
else:
    discard
