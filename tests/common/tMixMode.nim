
import ../../src/trackerboy/common

static:
    assert not mixMute.pansLeft
    assert not mixMute.pansRight
    assert mixLeft.pansLeft
    assert not mixLeft.pansRight
    assert not mixRight.pansLeft
    assert mixRight.pansRight
    assert mixMiddle.pansLeft
    assert mixMiddle.pansRight
