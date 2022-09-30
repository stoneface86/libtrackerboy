
import libtrackerboy/editing

static:
    assert not isEffect(selNote)
    assert not isEffect(selInstrument)
    assert isEffect(selEffect1)
    assert isEffect(selEffect2)
    assert isEffect(selEffect3)

    assert selNote.effectNumber == 0
    assert selInstrument.effectNumber == 0
    assert selEffect1.effectNumber == 0
    assert selEffect2.effectNumber == 1
    assert selEffect3.effectNumber == 2
