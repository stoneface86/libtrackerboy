from ./libtrackerboy/version as tbv import currentVersionString

# Package

version       = currentVersionString
author        = "stoneface"
description   = "Trackerboy utility library"
license       = "MIT"
binDir        = "bin"
installFiles  = @["libtrackerboy.nim"]
installDirs   = @["libtrackerboy"]

# Dependencies

requires "nim >= 1.6.0"
requires "unittest2 ~= 0.1.0"

include "build.nims"
