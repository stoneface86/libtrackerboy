

import libtrackerboy/[data, io, text, version]
import std/[streams]

import unittest2

import ../data/sampledata

# utils

proc corruptSignature(strm: Stream) =
  strm.setPosition(0)
  var data: byte
  strm.read(data)
  data = not data
  strm.setPosition(0)
  strm.write(data)
  strm.setPosition(0)

proc overwriteRevMajor(strm: Stream, major: uint8) =
  strm.setPosition(24) # seek to revMajor
  strm.write(major)    # overwrite with the given major


template pieceTests(
  correctData: ModulePiece,
  correctBin: string,
  setupBody: untyped
  ): untyped =
  
  type PieceType = correctData.typeOf

  setup:
    var strm {.inject.} = newStringStream()
    setupBody
  
  test "deserialize":
    strm.write(correctBin)
    strm.setPosition(0)

    var dataIn = PieceType.init()
    let res = dataIn.deserialize(strm)
    check res == frNone
    if res == frNone:
      check dataIn == correctData

  test "deserialize - bad signature":
    strm.write(correctBin)
    corruptSignature(strm)
    strm.setPosition(0)
    var dataIn = PieceType.init()
    check dataIn.deserialize(strm) == frInvalidSignature

  test "deserialize - bad revision":
    strm.write(correctBin)
    overwriteRevMajor(strm, currentFileMajor + 1)
    strm.setPosition(0)
    var dataIn = PieceType.init()
    check dataIn.deserialize(strm) == frInvalidRevision
    # piece files were introduced in major 1, so a rev 0 file should not exist
    overwriteRevMajor(strm, 0)
    strm.setPosition(0)
    check dataIn.deserialize(strm) == frInvalidRevision

  test "serialize":
    let res = correctData.serialize(strm)
    check res == frNone
    if res == frNone:
      strm.setPosition(0)
      check correctBin == strm.readAll()

  test "persistance":
    let serializeRes = correctData.serialize(strm)
    check serializeRes == frNone
    if serializeRes == frNone:
      strm.setPosition(0)
      var dataIn = PieceType.init()
      let deserializeRes = dataIn.deserialize(strm)
      check deserializeRes == frNone
      if deserializeRes == frNone:
        check correctData == dataIn

block: # ========================================================== instruments
  
  const
    instrumentBinary = slurp("../data/sample.tbi")
    instrumentBadChannel = slurp("../data/badchannel.invalid.tbi")

  suite "io.instruments":
    pieceTests get(sampleInstrument1), instrumentBinary:
      discard

    test "deserialize - unknown channel":
      strm.write(instrumentBadChannel)
      strm.setPosition(0)
      var inst = Instrument.init
      check inst.deserialize(strm) == frInvalidChannel

block: # =============================================================== major0
  
  const moduleBin = slurp("../data/major0-sample.tbm")

  suite "major0":

    setup:
      var 
        strm = newStringStream(moduleBin)
        m = Module.init()

    test "deserialize":
      let fr = m.deserialize(strm)
      check fr == frNone
      if fr == frNone:
        check:
          m.title == "legacy example"
          m.artist == "stoneface86"
          m.copyright == "2022 - stoneface86"
          m.comments == "legacy module for unit testing"
          m.tickrate.system == systemSgb
          m.songs.len == 1
          m.instruments.len == 2
          m.waveforms.len == 3

    test "cannot upgrade when numberOfInstruments or numberOfWaveforms > 256":
      # set high byte of numberOfInstruments to 1
      strm.setPosition(125)
      strm.write(1u8)
      strm.setPosition(127)
      strm.write(1u8)
      strm.setPosition(0)
      check m.deserialize(strm) == frCannotUpgrade

block: # =============================================================== major1

  const 
    moduleBin = slurp("../data/major1-sample.tbm")
    instNoEnvelope = slurp("../data/major1-sampleNoEnvelope.tbi")
    instEnvelope = slurp("../data/major1-sample.tbi")

  var 
    testModule = Module.init
    testModuleResult: FormatResult

  block:
    let strm = newStringStream(moduleBin)
    defer: strm.close()
    testModuleResult = testModule.deserialize(strm)

  template skipOnFormatError() =
    if testModuleResult != frNone: skip()

  suite "io.major1":

    test "deserialize result":
      check testModuleResult == frNone
  
    test "deserialize":
      skipOnFormatError()
      check:
        testModule.title == "sample"
        testModule.artist == "stoneface86"
        testModule.copyright == "2022 - stoneface86"
        testModule.comments == "sample module for unit testing"
        testModule.songs.len == 1
        testModule.instruments.len == 2
        testModule.waveforms.len == 3

    test "module customFramerate safely converted to float":
      let strm = newStringStream(moduleBin)
      defer: strm.close()

      strm.setPosition(127)
      strm.write(2u8)
      strm.write(48u16)
      strm.setPosition(0)

      var m = Module.init()
      let fr = m.deserialize(strm)
      check fr == frNone
      if fr == frNone:
        check:
          m.tickrate.system == systemCustom
          m.tickrate.customFramerate == 48.0f
        

    test "song deserialized with default tickrate override":
      skipOnFormatError()
      check    testModule.songs[0].tickrate.isNone()

    test "instrument with no initEnvelope converted to empty envelope sequence":
      let strm = newStringStream(instNoEnvelope)
      defer: strm.close()

      var i = Instrument.init()
      let fr = i.deserialize(strm)
      check fr == frNone
      if fr == frNone:
        check i.sequences[skEnvelope].len == 0

    test "instrument with initEnvelope converted to envelope sequence of 1":
      let strm = newStringStream(instEnvelope)
      defer: strm.close()

      var i = Instrument.init()
      let fr = i.deserialize(strm)
      check fr == frNone
      if fr == frNone:
        check i.sequences[skEnvelope] == litSequence("87")

block: # ============================================================== modules

  const moduleBin = slurp("../data/sample.tbm")

  proc checkModule(m1, m2: Module) =
    check:
      m1.songs == m2.songs
      m1.instruments == m2.instruments
      m1.waveforms == m2.waveforms
      m1.title == m2.title
      m1.artist == m2.artist
      m1.copyright == m2.copyright
      m1.comments == m2.comments
      m1.tickrate == m2.tickrate

  suite "io.modules":

    setup:
      var strm = newStringStream()
    
    test "deserialize":
      strm.write(moduleBin)
      strm.setPosition(0)

      var moduleIn = Module.init
      let res = moduleIn.deserialize(strm)
      check res == frNone
      if res == frNone:
        checkModule moduleIn, makeModule()

    test "deserialize - invalid signature":
      strm.write(moduleBin)
      corruptSignature(strm)
      var moduleIn = Module.init
      check moduleIn.deserialize(strm) == frInvalidSignature

    test "deserialize - future revision":
      strm.write(moduleBin)
      # overwrite the rev major in the header to a future version
      overwriteRevMajor(strm, uint8.high)
      strm.setPosition(0)
      var moduleIn = Module.init
      # deserialize should return with error frInvalidRevision
      check moduleIn.deserialize(strm) == frInvalidRevision

    test "deserialize - invalid system":
      strm.write(moduleBin)
      strm.setPosition(127)
      strm.write(System.high.uint8 + 1)
      strm.setPosition(0)
      var moduleIn = Module.init
      # if the system field in the header is not a valid System value, it will default to systemDmg
      check moduleIn.deserialize(strm) == frNone
      check moduleIn.tickrate == defaultTickrate

    test "deserialize - invalid table count":
      strm.write(moduleBin)
      strm.setPosition(124)
      strm.write(123u8)
      strm.setPosition(126)
      strm.write(TableId.high+1)
      strm.setPosition(0)
      var moduleIn = Module.init
      check moduleIn.deserialize(strm) == frInvalidCount

    test "deserialize - invalid terminator":
      strm.write(moduleBin)
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

    test "serialize":
      let res = makeModule().serialize(strm)
      check res == frNone
      
      if res == frNone:
        strm.setPosition(0)
        check strm.readAll() == moduleBin

    test "persistance":
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

block: # ================================================================ songs

  const
    songBin = slurp("../data/sample.tbs")

  suite "io.songs":
    pieceTests get(sampleSongTest), songBin:
      discard

block: # ============================================================ waveforms
  
  const
    # correct serialized waveform
    waveformBin = slurp("../data/sample.tbw")


  suite "io.waveforms":

    pieceTests get(sampleWaveformTriangle), waveformBin:
      discard
