from libtrackerboy/version as tbv import currentVersionString

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

# Tasks
# Use nut.nims instead for tasks

task packageVersion, "Prints package version and exits":
  echo version
