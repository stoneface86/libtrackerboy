import libtrackerboy/[data, io]
import ../testing

import std/streams

# testing for deserializing major 1 modules (Rev B, C modules)

const 
  moduleBin = slurp("data/major1-sample.tbm")
  instNoEnvelope = slurp("data/major1-sampleNoEnvelope.tbi")
  instEnvelope = slurp("data/major1-sample.tbi")

var 
  testModule = Module.init
  testModuleResult: FormatResult

block:
  let strm = newStringStream(moduleBin)
  defer: strm.close()
  testModuleResult = testModule.deserialize(strm)


testclass "major1"

dtest "deserialize":
  checkout testModuleResult == frNone
  check:
    testModule.title == "sample"
    testModule.artist == "stoneface86"
    testModule.copyright == "2022 - stoneface86"
    testModule.comments == "sample module for unit testing"
    testModule.songs.len == 1
    testModule.instruments.len == 2
    testModule.waveforms.len == 3

dtest "module customFramerate safely converted to float":
  let strm = newStringStream(moduleBin)
  defer: strm.close()

  strm.setPosition(127)
  strm.write(2u8)
  strm.write(48u16)
  strm.setPosition(0)

  var m = Module.init()
  checkout m.deserialize(strm) == frNone
  check:
    m.tickrate.system == systemCustom
    m.tickrate.customFramerate == 48.0f
  

dtest "song deserialized with default tickrate override":
  checkout testModuleResult == frNone
  check    testModule.songs[0].tickrate.isNone()

dtest "instrument with no initEnvelope converted to empty envelope sequence":
  let strm = newStringStream(instNoEnvelope)
  defer: strm.close()

  var i = Instrument.init()
  checkout i.deserialize(strm) == frNone
  check    i.sequences[skEnvelope].len == 0

dtest "instrument with initEnvelope converted to envelope sequence of 1":
  let strm = newStringStream(instEnvelope)
  defer: strm.close()

  var i = Instrument.init()
  checkout i.deserialize(strm) == frNone
  check    i.sequences[skEnvelope] == "87".parseSequence