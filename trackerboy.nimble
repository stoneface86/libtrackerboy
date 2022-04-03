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

task doc, "Builds the documentation":
    exec("nim doc --project --index:on --outdir:docs src/trackerboy.nim")

task apugen, "Generate APU wav files for tapu":
    exec("nim c -r --outdir:" & binDir & " tests/apugen.nim")

task wavegen, "Generate waveforms for tsynth":
    exec("nim c -r --outdir:" & binDir & " tests/wavegen.nim")
