
# nut - Nim UTilty
# just some utility nimscript tasks but properly handles compilation flags and
# task arguments use this instead of nimble tasks if you want your tasks to be able to
# properly forward compiler flags
# usage: ./nut [compflags] <taskname> [taskargs]
#  OR
# usage: nim e --hints:off nut.nims -- [compflags] <taskname> [taskargs]

# why nut? cause having to use this instead of nimble is nutty

import std/[os, strformat]

#mode = ScriptMode.WhatIf

let argTuple = block:
    var res: tuple[compflags, taskargs: seq[string]]
    let args = commandLineParams()
    # if we assume this script is invoked via ./nut, then we don't have to
    # search for --
    let argStart = args.find("--") + 1
    if argStart != 0:
        let taskIndex = block:
            var res = -1
            for i in argStart..<args.len:
                if args[i].len > 0 and args[i][0] != '-':
                    res = i
                    break
            res
        if taskIndex != -1:
            setCommand args[taskIndex]
            res.compflags = args[argStart..taskIndex-1]
            res.taskargs = args[taskIndex+1..^1]
    res

proc getCompflags(): string =
    quoteShellCommand(argTuple.compflags)

template execCmd(cmd, sub, args: string): untyped =
    var cmdline = cmd & " " & sub
    cmdline.add(' ')
    cmdline.add(getCompFlags())
    cmdline.add(' ')
    cmdline.add(args)
    exec cmdline
    
template execNimble(cmd, args: string): untyped =
    execCmd("nimble", cmd, args)

template execNim(cmd, args: string): untyped =
    execCmd("nim", cmd, args)

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
        execNim "r", &"--hints:off --path:src {defs} tests/private/tendian.nim"

task tester, "Builds the unit tester":
    execNimble "c", "--outdir:bin tests/tester.nim"

task test, "Runs the unit tester":
    testerTask()
    exec &"bin/tester {argTuple.taskargs.quoteShellCommand}"

task dumpArgs, "Echos the parsed compflags and taskargs":
    echo "Compiler flags: ", argTuple.compflags
    echo "Task arguments: ", argTuple.taskargs

task apugen, "Generate demo APU wav files":
    execNimble "c", "--outdir:bin --run tests/standalones/apugen.nim"

task wavegen, "Generate demo synth waveforms":
    execNimble "c", "--outdir:bin --run tests/standalones/wavegen.nim"

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
