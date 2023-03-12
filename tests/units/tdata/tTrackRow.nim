
import libtrackerboy/data

static:
  assert TrackRow.sizeof == 8
  let row = default(TrackRow)
  assert row.queryNote().isNone()
  assert row.queryInstrument().isNone()

  for effect in row.effects:
    assert effect.effectType == etNoEffect.uint8
    assert effect.param == 0u8
