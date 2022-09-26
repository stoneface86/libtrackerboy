import std/[os, strformat, strutils]

# Package

version       = "0.7.0"
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
        exec &"nim r --hints:off --path:src {defs} tests/private/tendian.nim"

task tester, "Builds the unit tester":
    --threads:on
    switch("d", "nimtestParallel")
    switch("outdir", binDir)
    setCommand("c", "tests/tester.nim")

task test, "Runs the unit tester":
    exec "nimble tester"
    # filter the nimble arguments (seems to be an regression in nimble that's
    # not yet fixed? )
    let args = commandLineParams()
    let i = args.find("test")
    assert i != -1
    let taskParams = args[i+1..^1]
    exec(binDir / "tester " & taskParams.quoteShellCommand())

task docgen, "Generate documentation":
    --hints:off
    const rstFiles = [
        "docs/module-file-format-spec.rst",
        "docs/piece-file-format-spec.rst"
    ]
    rmDir "htmldocs"
    # Generate all rst documents
    for filename in rstFiles:
        echo &"Generating page for '{filename}'"
        exec &"nim rst2html --hints:off --index:on --outdir:htmldocs \"{filename}\""

    # generate project documentation via libtrackerboy.nim
    echo "Generating documentation for whole project..."
    exec "nim doc --hints:off --project --index:on --outdir:htmldocs libtrackerboy.nim"

    # generate the index
    echo "Building index..."
    exec "nim buildIndex --hints:off -o:htmldocs/theindex.html htmldocs"

task apugen, "Generate demo APU wav files":
    --run
    switch("outdir", binDir)
    setCommand "c", "tests/apugen.nim"

task wavegen, "Generate demo synth waveforms":
    --run
    switch("outdir", binDir)
    setCommand "c", "tests/wavegen.nim"
