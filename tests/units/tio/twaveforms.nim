
import utils
import sampledata

testclass "waveforms"

# correct serialized waveform
const
    waveformBinary = slurp("data/sample.tbw")


testgroup:

    pieceTests get(sampleWaveformTriangle), waveformBinary:
        discard


