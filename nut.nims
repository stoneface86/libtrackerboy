
# nut - Nim UTilty
# just some utility nimscript tasks but properly handles compilation flags and
# task arguments use this instead of nimble tasks if you want your tasks to be able to
# properly forward compiler flags
# usage: ./nut [compflags] <taskname> [taskargs]
#  OR
# usage: nim e --hints:off nut.nims -- [compflags] <taskname> [taskargs]

# why nut? cause having to use this instead of nimble is nutty

import std/[os, strformat, strutils]

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
  argTuple.compflags.quoteShellCommand

proc getTaskArgs(): string = 
  argTuple.taskargs.quoteShellCommand

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

template withTests(body: untyped): untyped =
  withDir "tests":
    body

template onEachPackage(body: untyped): untyped =
  body
  withTests:
    body

proc installDeps() =
  exec "nimble install -y --depsOnly"

task check, "Runs nimble check on each package":
  proc check() =
    exec "nimble check"
  onEachPackage:
    check()    

task init, "Installs dependencies needed for the project":
  
  onEachPackage:
    installDeps()

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
    echo "switches: ", defs
    execNim "r", &"--hints:off {defs} tests/endianTests.nim"

task test, "Runs unit tests":
  withTests:
    execNimble "run", "tests " & getTaskArgs()

task dumpArgs, "Echos the parsed compflags and taskargs":
  echo "Compiler flags: ", argTuple.compflags
  echo "Task arguments: ", argTuple.taskargs

task apugen, "Generate demo APU wav files":
  withTests:
    execNimble "c", "--outdir:../bin --run standalones/apugen.nim"

task wavegen, "Generate demo synth waveforms":
  withTests:
    execNimble "c", "--outdir:../bin --run standalones/wavegen.nim"

task wavexport, "Test the wav exporter":
  withTests:
    execNimble "c", "--outdir:../bin --run standalones/wavexport.nim"

task docsSpecs, "Generate documentation for file format specifications":
  for name in [
    "tbm-spec-major-0",
    "tbm-spec-major-1"
  ]:
    withDir "docs":
      echo &"Generating HTML page for 'docs/{name}.adoc'"
      exec &"bundle exec asciidoctor --failure-level ERROR --trace {name}.adoc -o ../htmldocs/{name}.html"
      echo &"Generating PDF document for 'docs/{name}.adoc'"
      exec &"bundle exec asciidoctor-pdf --failure-level ERROR --trace {name}.adoc -o ../htmldocs/{name}.pdf"

proc getGitArgs(): string =
  let commit = block:
    if argTuple.taskargs.len == 1:
      argTuple.taskargs[0]
    else:
      "develop"
  result = &"--git.url:https://github.com/stoneface86/libtrackerboy --git.commit:{commit} --git.devel:develop"

proc docsRstImpl(gitargs = "") =
  for filename in [
    "docs/module-file-format-spec.rst"
  ]:
    echo &"Generating page for '{filename}'"
    exec &"nim rst2html --hints:off --index:on --outdir:htmldocs {gitargs} \"{filename}\""

task docsRst, "Generate RST documents":
  docsRstImpl(getGitArgs())

task docs, "Generate documentation":
  let gitargs = getGitArgs()

  # remove previously generated documentation if exists
  rmDir "htmldocs"
  
  # Generate all rst documents
  docsRstImpl(gitargs)

  # generate project documentation via libtrackerboy.nim
  echo "Generating documentation for whole project..."
  exec &"nim doc --hints:off --project --index:on --outdir:htmldocs {gitargs} libtrackerboy.nim"

  # generate the index
  echo "Building index..."
  exec &"nim buildIndex --hints:off -o:htmldocs/theindex.html {gitargs} htmldocs"

  # remove .idx files
  for filename in walkDirRec("htmldocs"):
    if filename.endsWith(".idx"):
      rmFile(filename)


task clean, "Clears the bin and htmldocs folders":
  rmDir "bin"
  rmDir "htmldocs"
