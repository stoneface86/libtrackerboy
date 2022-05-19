discard """
"""

import utils
import sampledata

const
    instrumentBinary = slurp("data/sample.tbi")
    instrumentBadChannel = slurp("data/badchannel.invalid.tbi")



unittests:

    suite "io - instruments":

        pieceTests get(sampleInstrument1), instrumentBinary:
            discard

        test "deserialize - unknown channel":
            strm.write(instrumentBadChannel)
            strm.setPosition(0)
            var inst = Instrument.init
            check inst.deserialize(strm) == frInvalidChannel
