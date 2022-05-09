discard """
"""

import ../../src/trackerboy/[data, io]
import ../unittest_wrapper

import std/streams

# testing for deserializing major 0 modules (legacy modules)

const moduleBin = slurp("data/sample.major0.tbm")

unittests:

    suite "io - modules (major 0)":
        setup:
            var strm = newStringStream()

        test "deserialize":
            strm.write(moduleBin)
            strm.setPosition(0)
            
            var m = initModule()
            check m.deserialize(strm) == frNone
            check m.title == "legacy example"
            check m.artist == "stoneface86"
            check m.copyright == "2022 - stoneface86"
            check m.comments == "legacy module for unit testing"
            check m.system == systemSgb
            check m.songs.len == 1
            check m.instruments.len == 2
            check m.waveforms.len == 3

        test "cannot upgrade when numberOfInstruments or numberOfWaveforms > 256":
            strm.write(moduleBin)
            # set high byte of numberOfInstruments to 1
            strm.setPosition(125)
            strm.write(1u8)
            strm.setPosition(0)
            var m = initModule()
            check m.deserialize(strm) == frCannotUpgrade
