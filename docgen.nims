# This script builds the html documentation into htmldocs/
# run via `nim docgen.nims`

switch("hints", "off")

import std/[os, strformat]

const dryRun = false

when dryRun:
    template tryExec(code: int, cmd: string): untyped = echo cmd
else:
    template tryExec(code: int, cmd: string): untyped =
        try:
            exec cmd
        except OSError:
            quit(code)

const
    rstFiles = [
        "docs/module-file-format-spec.rst",
        "docs/piece-file-format-spec.rst"
    ]

when not dryRun:
    rmDir "htmldocs"

# Generate all rst documents
for filename in rstFiles:
    echo fmt"Generating page for '{filename}'"
    tryExec 1, &"nim rst2html --hints:off --index:on --outdir:htmldocs \"{filename}\""

# generate project documentation via src/trackerboy.nim
echo "Generating documentation for whole project..."
let srcpath = "src".absolutePath()
tryExec 2, &"nim doc --hints:off --project --index:on --outdir:htmldocs -p:\"{srcpath}\" src/trackerboy.nim"

# generate the index
echo "Building index..."
tryExec 3, "nim buildIndex --hints:off -o:htmldocs/theindex.html htmldocs"
