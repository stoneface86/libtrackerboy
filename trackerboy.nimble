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
    exec "testament --targets:c all"

task docgen, "Generate documentation":
    exec "nim --hints:off docgen.nims"

task apugen, "Generate demo APU wav files":
    exec("nim c -r --outdir:" & binDir & " tests/apugen.nim")

task wavegen, "Generate demo synth waveforms":
    exec("nim c -r --outdir:" & binDir & " tests/wavegen.nim")
