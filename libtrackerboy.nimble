import std/[os, strutils]

# Package

version       = "0.2.0"
author        = "stoneface"
description   = "Trackerboy utility library"
license       = "MIT"
binDir        = "bin"
# tbc is a command-line frontend for the library
# it is not required for users of the library
bin           = @["tbc"]
installFiles  = @["libtrackerboy.nim"]
installDirs   = @["libtrackerboy"]

# Dependencies

requires "nim >= 1.6.0"
# only the unit tester needs this package
requires "unittest2"

# Tasks

task endianTests, "Runs tests/private/tendian.nim with different configurations":
    # test matrix
    # 0. Native endian w/ builtin bswap
    # 1. Native endian w/ reference bswap
    # 2. Inverse endian w/ builtin bswap
    # 3. Inverse endian w/ reference bswap
    const matrix = [
        "",
        "-d:noIntrinsicsEndians",
        "-d:tbEndianInverse",
        "-d:noIntrinsicsEndians -d:tbEndianInverse"
    ]
    for defs in matrix:
        exec "nim r --hints:off --path:src " & defs & " tests/private/tendian.nim"

task tester, "Builds the unit tester":
    --threads:on
    switch("d", "nimtestParallel")
    switch("outdir", binDir)
    setCommand("c", "tests/tester.nim")

task test, "Runs the unit tester":
    exec "nimble tester"
    let args = commandLineParams()
    let i = args.find("test")
    assert i != -1
    let taskParams = args[i+1..^1]
    exec(binDir / "tester " & taskParams.quoteShellCommand())

task docgen, "Generate documentation":
    exec "nim --hints:off docgen.nims"

task apugen, "Generate demo APU wav files":
    --run
    switch("outdir", binDir)
    setCommand "c", "tests/apugen.nim"

task wavegen, "Generate demo synth waveforms":
    --run
    switch("outdir", binDir)
    setCommand "c", "tests/wavegen.nim"
