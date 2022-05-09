discard """
"""
import utils
import sampledata

const
    songBinary = slurp("data/sample.tbs")

unittests:

    suite "io - songs":

        pieceTests get(sampleSongTest), songBinary:
            discard
