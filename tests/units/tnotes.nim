
import libtrackerboy/notes
import unittest2


test "lookupToneNote":
  let
    lowest = lookupToneNote(low(ToneNote))
    highest = lookupToneNote(high(ToneNote))
  check:
    lookupToneNote(cast[Natural](low(ToneNote) - 1)) == lowest
    lookupToneNote(cast[Natural](high(ToneNote) + 1)) == highest

test "lookupNoiseNote":
  check:
    lookupNoiseNote(cast[Natural](low(NoiseNote) - 1)) == lookupNoiseNote(low(NoiseNote))
    lookupNoiseNote(cast[Natural](high(NoiseNote) + 1)) == lookupNoiseNote(high(NoiseNote))
  
test "toNote":
  check:
    toNote(C, 2) == NoteIndex(0)
    toNote(ASharp, 3) == NoteIndex(22)
    toNote(B, 8) == NoteIndex(83)
    toNote(-2) == NoteIndex(NoteRange.low)
    toNote(NoteRange.high + 3) == NoteIndex(NoteRange.high)

test "toPair":
  check:
    toPair(NoteIndex(2)) == notePair(D, 2)
    toPair(NoteIndex(22)) == notePair(ASharp, 3)
    toPair(NoteIndex(83)) == notePair(B, 8)
