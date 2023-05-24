
import libtrackerboy/[data, io]
import ../testing

import std/streams

# testing for deserializing major 0 modules (legacy modules)

const moduleBin = slurp("data/major0-sample.tbm")

testclass "major0"

testgroup:
  setup:
    var 
      strm = newStringStream(moduleBin)
      m = Module.init()

  dtest "deserialize":
    checkout m.deserialize(strm) == frNone
    check:
      m.title == "legacy example"
      m.artist == "stoneface86"
      m.copyright == "2022 - stoneface86"
      m.comments == "legacy module for unit testing"
      m.tickrate.system == systemSgb
      m.songs.len == 1
      m.instruments.len == 2
      m.waveforms.len == 3

  dtest "cannot upgrade when numberOfInstruments or numberOfWaveforms > 256":
    # set high byte of numberOfInstruments to 1
    strm.setPosition(125)
    strm.write(1u8)
    strm.setPosition(127)
    strm.write(1u8)
    strm.setPosition(0)
    check m.deserialize(strm) == frCannotUpgrade
