
# Build tasks

import std/[strutils, strformat]
import std/os

const 
  binDir = "bin"
  flagOutdir = "--outdir:" & binDir
  gitRef {.strdefine.} = "develop"

proc vexec(args: varargs[string]) =
  exec(quoteShellCommand(args))

template nohints() = --hints:off

# SETUP

task setDev, "Sets this project to develop mode (dev dependencies enabled)":
  nohints()
  writeFile(".dev", "")

# TESTING

task endianTests, "Runs tests/private/tendian.nim with different configurations":
  nohints()
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
    exec &"nim r --hints:off {defs} tests/units/private/tendian.nim"

task buildTests, "Builds the unit tester":
  nohints()
  vexec("nim", "--hints:off", "c", flagOutdir, "tests/tests.nim")

task test, "Runs unit tests":
  buildTestsTask()
  try:
    exec binDir / "tests"
    echo "All tests passed."
  except OSError:
    discard

# DEMO/STANDALONE TEST PROGRAMS

proc standalone(name: string) =
  nohints()
  vexec "nim", "c", flagOutdir, "--run", "tests/standalones/" & name

task apugen, "Generate demo APU wav files":
  standalone("apugen.nim")

task wavegen, "Generate demo synth waveforms":
  standalone("wavegen.nim")

task wavexport, "Test the wav exporter":
  standalone("wavexport.nim")

task wavutil, "Exports a song from a module to wav":
  standalone("wavutil.nim")

# DOCUMENTATION

task docsSpecs, "Generate documentation for file format specifications":
  nohints()
  for name in [
    "tbm-spec-major-0",
    "tbm-spec-major-1",
    "tbm-spec-major-2"
  ]:
    withDir "docs":
      echo &"Generating HTML page for 'docs/{name}.adoc'"
      exec &"bundle exec asciidoctor --failure-level ERROR --trace {name}.adoc -o ../htmldocs/{name}.html"
      echo &"Generating PDF document for 'docs/{name}.adoc'"
      exec &"bundle exec asciidoctor-pdf --failure-level ERROR --trace {name}.adoc -o ../htmldocs/{name}.pdf"

proc getGitArgs(): string =
  result = &"--git.url:https://github.com/stoneface86/libtrackerboy --git.commit:{gitRef} --git.devel:develop"


proc docsRstImpl(gitargs: string) =
  for filename in [
    "docs/module-file-format-spec.rst"
  ]:
    echo &"Generating page for '{filename}'"
    exec &"nim rst2html --hints:off --index:on --outdir:htmldocs {gitargs} \"{filename}\""

task docsRst, "Generate RST documents":
  nohints()
  docsRstImpl(getGitArgs())

task docs, "Generate documentation":
  nohints()
  let gitargs = getGitArgs()

  # remove previously generated documentation if exists
  rmDir "htmldocs"
  
  # Generate all rst documents
  docsRstImpl(gitargs)

  echo "Indexing whole project..."
  exec "nim doc --hints:off --project --index:only libtrackerboy.nim"

  # generate project documentation via libtrackerboy.nim
  echo "Generating documentation for whole project..."
  exec &"nim doc --hints:off --project --outdir:htmldocs {gitargs} libtrackerboy.nim"

  # generate the index
  echo "Building index..."
  exec &"nim buildIndex --hints:off -o:htmldocs/theindex.html {gitargs} htmldocs"

  # remove .idx files
  for filename in walkDirRec("htmldocs"):
    if filename.endsWith(".idx"):
      rmFile(filename)

# MISC

task clean, "Clears the bin and htmldocs folders":
  nohints()
  rmDir "bin"
  rmDir "htmldocs"

# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
