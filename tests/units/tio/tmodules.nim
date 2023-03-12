
import libtrackerboy/[data, io]

import sampledata
import utils

const moduleBinary = slurp("data/sample.tbm")

testclass "modules"

func makeModule(): Module =
  result = Module.init
  result.title = "sample"
  result.artist = "stoneface86"
  result.copyright = "2022 - stoneface86"
  result.comments = "sample module for unit testing"
  result.songs[0][] = get(sampleSongTest)
  for sample in InstrumentSamples:
    let id = result.instruments.add()
    result.instruments[id][] = get(sample)
  for sample in WaveformSamples:
    let id = result.waveforms.add()
    result.waveforms[id][] = get(sample)

proc checkModule(m1, m2: Module) =
  check:
    m1.songs == m2.songs
    m1.instruments == m2.instruments
    m1.waveforms == m2.waveforms
    m1.title == m2.title
    m1.artist == m2.artist
    m1.copyright == m2.copyright
    m1.comments == m2.comments
    m1.system == m2.system
    m1.customFramerate == m2.customFramerate


testgroup:

  setup:
    var strm = newStringStream()
  
  dtest "deserialize":
    strm.write(moduleBinary)
    strm.setPosition(0)

    var moduleIn = Module.init
    let res = moduleIn.deserialize(strm)
    check res == frNone
    if res == frNone:
      checkModule moduleIn, makeModule()

  dtest "deserialize - invalid signature":
    strm.write(moduleBinary)
    corruptSignature(strm)
    var moduleIn = Module.init
    check moduleIn.deserialize(strm) == frInvalidSignature

  dtest "deserialize - future revision":
    strm.write(moduleBinary)
    # overwrite the rev major in the header to a future version
    overwriteRevMajor(strm, uint8.high)
    strm.setPosition(0)
    var moduleIn = Module.init
    # deserialize should return with error frInvalidRevision
    check moduleIn.deserialize(strm) == frInvalidRevision

  dtest "deserialize - invalid system":
    strm.write(moduleBinary)
    strm.setPosition(127)
    strm.write(System.high.uint8 + 1)
    strm.setPosition(0)
    var moduleIn = Module.init
    # if the system field in the header is not a valid System value, it will default to systemDmg
    check moduleIn.deserialize(strm) == frNone
    check moduleIn.system == systemDmg
    # ensure that the customFramerate was also reset to default
    check moduleIn.customFramerate == defaultFramerate

  dtest "deserialize - invalid table count":
    strm.write(moduleBinary)
    strm.setPosition(124)
    strm.write(123u8)
    strm.setPosition(126)
    strm.write(TableId.high+1)
    strm.setPosition(0)
    var moduleIn = Module.init
    check moduleIn.deserialize(strm) == frInvalidCount

  dtest "deserialize - invalid terminator":
    strm.write(moduleBinary)
    let pos = strm.getPosition() - 1
    strm.setPosition(pos)
    var data: uint8
    strm.read(data)
    data = not data
    strm.setPosition(pos)
    strm.write(data)
    strm.setPosition(0)
    var moduleIn = Module.init
    check moduleIn.deserialize(strm) == frInvalidTerminator

  dtest "serialize":
    let res = makeModule().serialize(strm)
    check res == frNone
    
    if res == frNone:
      strm.setPosition(0)
      check strm.readAll() == moduleBinary

  dtest "persistance":
    let module = makeModule()
    let serializeRes = module.serialize(strm)
    check serializeRes == frNone
    if serializeRes == frNone:
      strm.setPosition(0)
      var moduleIn = Module.init
      let deserializeRes = moduleIn.deserialize(strm)
      check deserializeRes == frNone
      if deserializeRes == frNone:
        checkModule moduleIn, module
