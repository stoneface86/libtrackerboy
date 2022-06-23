import trackerboy/editing

template a*(r: int, t: int, c: TrackSelect): PatternAnchor =
    PatternAnchor(row: r, track: t, column: c)
