
# run this when currentVersion in libtrackerboy/version.nim is changed
# otherwise the io tests will fail!

import std/[os, streams]

import ../../libtrackerboy/version
import ../../libtrackerboy/private/endian

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
  strm.write(currentVersion.major.uint32.toLE)
  strm.write(currentVersion.minor.uint32.toLE)
  strm.write(currentVersion.patch.uint32.toLE)
  strm.close()
