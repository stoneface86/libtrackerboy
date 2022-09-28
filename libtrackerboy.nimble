import libtrackerboy/version as tbversion

# Package

version       = $tbversion.currentVersion
author        = "stoneface"
description   = "Trackerboy utility library"
license       = "MIT"
binDir        = "bin"
installFiles  = @["libtrackerboy.nim"]
installDirs   = @["libtrackerboy"]

# Dependencies

requires "nim >= 1.6.0"
# only the unit tester needs this package
requires "unittest2"

# Tasks
# Use nut.nims instead for tasks
