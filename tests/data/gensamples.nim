## Utility program generates sample data for unit testing
## Tweak this program when there's a change in the format and you need new
## data, as opposed to creating some by hand in a hex editor.
## 

import ../sampledata

import libtrackerboy/[data, io]

import std/[os, streams]


let dataDir = currentSourcePath().parentDir()

template generate(sample: ModulePiece|Module, filename: string) =
  block:
    let strm = newFileStream(dataDir / filename, fmWrite)
    doAssert sample.serialize(strm) == frNone
    strm.close()

generate(get(sampleInstrument1), "sample.tbi")
generate(get(sampleWaveformTriangle), "sample.tbw")
generate(get(sampleSongTest), "sample.tbs")

let module = makeModule()
generate(module, "sample.tbm")
