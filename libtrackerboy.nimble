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

requires "nim >= 2.0.0"

# dev dependencies
when fileExists(".dev"):
  requires "unittest2 == 0.2.2"
