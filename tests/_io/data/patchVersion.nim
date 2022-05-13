
# run this when appVersion in src/trackerboy/version.nim is changed
# otherwise the _io tests will fail!

import std/[os, streams]

import ../../../src/trackerboy/version
import ../../../src/trackerboy/private/endian

const filesToPatch = [
    "sample.tbi",
    "sample.tbm",
    "sample.tbs",
    "sample.tbw"
]

let dataDir = currentSourcePath().parentDir()

for filename in filesToPatch:
    let strm = newFileStream(dataDir.joinPath(filename), fmReadWriteExisting)
    strm.setPosition(12)
    strm.write(appVersion.major.uint32.toLE)
    strm.write(appVersion.minor.uint32.toLE)
    strm.write(appVersion.patch.uint32.toLE)
    strm.close()
