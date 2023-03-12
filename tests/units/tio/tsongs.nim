
import utils
import sampledata

testclass "songs"

const
  songBinary = slurp("data/sample.tbs")

testgroup:
  pieceTests get(sampleSongTest), songBinary:
    discard
