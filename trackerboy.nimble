# Package

version       = "0.1.0"
author        = "stoneface"
description   = "Trackerboy utility library"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"


# Dependencies

requires "nim >= 1.6.0"

# Tasks

task test, "Runs the unit tester":
    exec("nim c -r --outdir:" & binDir & " tests/tester.nim")
