discard """
"""

import ../../src/trackerboy/data
import ../unittest_wrapper

static:
    assert TrackRow.sizeof == 8

unittests:

    test "TrackRow is empty on default init":
        let row = default(TrackRow)
        check row.queryNote().isNone()
        check row.queryInstrument().isNone()

        for effect in row.effects:
            check effect.effectType == etNoEffect.uint8
            check effect.param == 0u8
