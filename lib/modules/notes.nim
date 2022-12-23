
import libtrackerboy/notes as ltb_notes

{.push exportc, noconv.}

# the lookup functions take a Natural, but out of bounds indices are just clamped
# so that's unnecessary, in the future change the API so that it takes an int instead.
# (casting is done to avoid the range check which would panic)

proc ltbNotesLookupTone*(note: cint): uint16 =
    lookupToneNote(cast[Natural](note))

proc ltbNotesLookupNoise*(note: cint): uint8 =
    lookupNoiseNote(cast[Natural](note))

{.pop.}
