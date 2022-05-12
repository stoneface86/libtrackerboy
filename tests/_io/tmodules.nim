discard """
"""

import ../../src/trackerboy/[data, io]
import ../unittest_wrapper

import sampledata
import utils

const moduleBinary = slurp("data/sample.tbm")

let module = block:
    var m = Module.init
    m.title = "sample"
    m.artist = "stoneface86"
    m.copyright = "2022 - stoneface86"
    m.comments = "sample module for unit testing"
    m.songs[0][] = get(sampleSongTest)
    for sample in InstrumentSamples:
        let id = m.instruments.add()
        m.instruments[id][] = get(sample)
    for sample in WaveformSamples:
        let id = m.waveforms.add()
        m.waveforms[id][] = get(sample)
    m

unittests:

    suite("io - modules"):

        setup:
            var strm = newStringStream()
        
        test "deserialize":
            strm.write(moduleBinary)
            strm.setPosition(0)

            var moduleIn = Module.init
            let res = moduleIn.deserialize(strm)
            check res == frNone
            if res == frNone:
                check:
                    moduleIn.songs == module.songs
                    moduleIn.instruments == module.instruments
                    moduleIn.waveforms == module.waveforms
                    moduleIn.title == module.title
                    moduleIn.artist == module.artist
                    moduleIn.copyright == module.copyright
                    moduleIn.comments == module.comments
                    moduleIn.system == module.system
                    moduleIn.customFramerate == module.customFramerate

        test "deserialize - invalid signature":
            discard

        test "deserialize - future revision":
            discard

        test "deserialize - invalid system":
            discard

        test "deserialize - invalid table count":
            discard

        test "deserialize - invalid terminator":
            discard

        test "serialize":
            discard

        test "persistance":
            discard