discard """
"""
import utils
import sampledata

# correct serialized waveform
const
    waveformBinary = slurp("data/sample.tbw")

unittests:

    suite "io - waveforms":

        pieceTests get(sampleWaveformTriangle), waveformBinary:
            discard


