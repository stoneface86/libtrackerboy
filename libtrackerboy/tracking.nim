##[

Music tracking. Allows you to perform each tick of a Song and track its
position, speed, and track operations.

Originally this code was a part of [libtrackerboy/engine/enginecontrol], but
has been decoupled so that it may be used for exporting routines.

]##


import
  ./data,
  ./ir,
  ./private/utils

import std/[options, times]

type
  Counter* = distinct int
    ## A counter for counting ticks.
    ##

  TrackTimer = object
    delayCounter: Counter
    op: Operation

  Timer = object
    # Playback timer, indicates when a row is started
    period: int
    counter: int
  
  PatternChange = object
    # indicates how the next pattern should be determined for the next row
    cmd: PatternCommand
    param: uint8
    speed: uint8
    shouldHalt: bool

  Tracker* = object
    ## Music tracker. Tracks the position of the song during performance.
    ##
    running: bool
    pos: SongPos
    timer: Timer
    tracks: array[ChannelId, TrackTimer]
    
    nextRowCmd: PatternCommand
    nextRowParam: uint8
    incRow: bool
    
    effectsFilter: set[EffectType]
    patternRepeat: bool

  TrackerStatus* = enum
    ## Possible statuses for the [Tracker]
    ##
    tsHalted      ## Tracker has halted, or is no longer playing.
    tsSteady      ## Normal playback status
    tsNewRow      ## Same as tsSteady, but indicates the start of a new row
    tsNewPattern  ## Same as tsNewRow, but indicates the start of a new pattern

  TrackerResult* = object
    ## Result object after ticking a [Tracker]
    ## * `status`: the tracker's current status after this tick.
    ## * `speedChanged`: `true` if the tracker's speed changed this tick.
    ## * `ops`: A set of tracks that have an `Operation` to be performed this
    ##          tick.
    ## * `filtered`:  A set of tracks that had one or more effects removed by
    ##                the tracker's `effectsFilter`
    ##
    status*: TrackerStatus
    speedChanged*: bool
    ops*: set[ChannelId]
    filtered*: set[ChannelId]

  SongPath* = object
    ## Defines the path a song will take during performance. A song's path is
    ## the order in which patterns are encountered, or visited. The path also
    ## has an optional loop index, that indicates whether the song will loop
    ## to a previous visit or halt at the last visit.
    ## * `visits`: This seq contains the patterns that were visited, in order
    ##             of occurance.
    ## * `loopsTo`: Specifies the index of the visit the song will loop to
    ##              after the last visit. If not provided, then the song will
    ##              halt after the last visit.
    ##
    visits*: seq[SongSpan]
    loopsTo*: Option[int]
    

func filter*(filter: set[EffectType]; row: TrackRow): TrackRow =
  ## Applies an effect filter to a row. The resulting row is a copy of `row`,
  ## except that any effect whose `effectType` is contained in `filter` will
  ## be replaced by an empty Effect.
  ## 
  ## To test if the filter removed any effects, check if the input row and
  ## output row are not equal.
  ##
  result.note = row.note
  result.instrument = row.instrument
  for i in 0..<row.effects.len:
    let e = row.effects[i]
    if toEffectType(e.effectType) notin filter:
      result.effects[i] = e

func trackerResult*(status = tsHalted; speedChanged = false;
                    ops: set[ChannelId] = {}; filtered: set[ChannelId] = {}
                    ): TrackerResult =
  result = TrackerResult(status: status, speedChanged: speedChanged, 
                         ops: ops, filtered: filtered)

# ======

# Counter
# This is an integer value for counting ticks.

const noCounter* = Counter(0)

func `==`*(x, y: Counter;): bool {.borrow.}

func isEnabled*(c: Counter): bool {.inline.} =
  ## Deterine if the counter is enabled, or if it has a target number of
  ## ticks.
  ##
  result = c != noCounter

func initCounter*(v: int): Counter =
  ## Initialize an enabled counter for a target number of ticks, `v`. A
  ## counter of target 0 is an instantaneous one, or triggers on the first
  ## call to tick.
  ##
  Counter(v + 1)

proc tick*(c: var Counter): bool =
  ## Ticks the counter. `true` is returned if the counter has finished counting
  ## to its target, `false` otherwise.
  if int(c) > 0:
    c = Counter(int(c) - 1)
    result = c == noCounter

# ======

# TrackTimer
# Handles delayed rows for each track

proc setRow(t: var TrackTimer; row: TrackRow) =
  # convert the row to an operation and overwrite the last one
  t.op = row.toOperation()
  # set the counter to the op's delay parameter (Gxx effect)
  # note: if Gxx was not present in `row`, then delayCounter is now an
  # instantaneous one, since the value of opsDelay in op will be 0.
  t.delayCounter = initCounter(t.op[opsDelay].int)

proc tick(t: var TrackTimer; pc: var PatternChange): bool =
  # tick the TrackTimer. `true` is returned if an operation should be performed
  # for this tick, `false` otherwise.

  result = t.delayCounter.tick()
  if result:
    # the row can be performed
    
    # pattern change effects
    t.op.forFlagPresent(opsPatternCommand):
      pc.cmd = t.op.patternCommand
      pc.param = t.op[opsPatternCommand]
      t.op.flags.excl(opsPatternCommand)
    
    t.op.forFlagPresent(opsSpeed):
      pc.speed = t.op[opsSpeed]
      t.op.flags.excl(opsSpeed)
    
    if opsHalt in t.op.flags:
      pc.shouldHalt = true
    
    # disable counter
    t.delayCounter = noCounter
    

func initPatternChange(): PatternChange =
  result = PatternChange(
    cmd: pcNone,
    param: 0u8,
    speed: 0u8,
    shouldHalt: false
  )

# ======

# Timer
# song timer for counting ticks

func initTimer(speed: Speed): Timer =
  # Create a timer with the given speed as its period.
  #
  result = Timer(
    period: speed.int,
    counter: 0
  )

func active(t: Timer): bool =
  # Determine if the timer is active. An active timer means that the tracker
  # should start a new row.
  t.counter < unitSpeed

proc setPeriod(t: var Timer; speed: Speed) =
  # Change the timer's period to the given speed.
  #
  t.period = clamp(speed, low(Speed), high(Speed)).int
  # if the counter exceeds the new period, clamp it to 1 unit less
  # this way, the timer will overflow on the next tick
  t.counter = min(t.counter, t.period - unitSpeed)

proc tick(t: var Timer): bool =
  # Tick the timer. `true` is returned if the timer overflowed, which means the
  # tracker should advance its position to the next row.
  #
  t.counter += unitSpeed
  result = t.counter >= t.period
  if result:
    # timer overflow
    t.counter -= t.period

# ======

func initTracker*(song: Song; startAt = default(SongPos);
                  effectsFilter: set[EffectType] = {}; patternRepeat = false
                  ): Tracker =
  ## Initialize a [Tracker] for a song and starting position. `effectsFilter`
  ## is a set of effect types to remove/ignore when performing a row in a
  ## track. 
  ## 
  result.running = song.isValid(startAt)
  result.pos = startAt
  result.timer = initTimer(song.speed)
  defaultInit(result.tracks)
  defaultInit(result.nextRowCmd)
  defaultInit(result.nextRowParam)
  result.effectsFilter = effectsFilter
  result.patternRepeat = patternRepeat

func patternRepeat*(t: Tracker): bool {.inline.} =
  ## Gets the pattern repeat setting.
  ## 
  t.patternRepeat

proc `patternRepeat=`*(t: var Tracker; val: bool) {.inline.} =
  ## Sets the pattern repeat setting. When set to `true` the current pattern is
  ## repeated endlessly whenever the end of the pattern is reached or if a
  ## pattern jump effect is encountered.
  ## 
  t.patternRepeat = val  

func effectsFilter*(t: Tracker): set[EffectType] {.inline.} =
  ## Gets the current effects filter in use.
  ##
  t.effectsFilter

func `effectsFilter=`*(t: var Tracker; filter: set[EffectType]) {.inline.} =
  ## Set an effect filter. By default the tracker has no filter, or an empty
  ## set. When a filter is set, any effect with the type contained in the
  ## filter will be ignored during performance.
  ##
  t.effectsFilter = filter

func pos*(t: Tracker): SongPos {.inline.} =
  ## Get the current position of the tracker. Since pattern changes occur at
  ## the start of a tick, this position may point to an invalid one, a position
  ## with one row past the last one in the song.
  ##
  t.pos

func isRunning*(t: Tracker): bool {.inline.} =
  ## Determines if the tracker is running, or is not halted.
  ##
  t.running

func isHalted*(t: Tracker): bool {.inline.} =
  ## Get the halted status of the tracker. Halting normally occurs when the
  ## `etPatternHalt` effect is performed (C00). Attempting to start at an
  ## invalid position, or jumping to an invalid position will result in a
  ## halt as well.
  ##
  not t.running

func getOp*(t: Tracker; track: ChannelId): Operation =
  ## Gets the last operation for the given track. The [statHasOp] flag will be
  ## set in [TickOut] when a tick has new operation set for the track.
  ##
  result = t.tracks[track].op

func speed*(t: Tracker): Speed {.inline.} =
  ## Gets the current playback Speed of the Tracker.
  ##
  result = Speed(t.timer.period)

proc halt*(t: var Tracker) =
  ## Halts the tracker.
  ##
  t.running = false

proc jump*(t: var Tracker; song: Song; pos: SongPos) =
  ## Change the tracker's current position in the song to the given one.
  ## If `pos` is not a valid position, the song will halt.
  ##
  if song.isValid(pos):
    t.timer.counter = 0
    t.pos = pos
  else:
    t.running = false
  
proc tick*(t: var Tracker; song: Song): TrackerResult =
  proc nextPatternImpl(t: var Tracker; song: Song): TrackerStatus =
    if t.patternRepeat:
      t.pos.row = 0
      result = tsNewRow
    else:
      inc t.pos.pattern
      if t.pos.pattern >= song.order.len:
        t.pos.pattern = 0
      t.pos.row = min(int(t.nextRowParam), song.trackLen - 1)
      result = tsNewPattern
  
  if t.running:
    result.status = tsSteady
    if t.timer.active():
      # timer is active, this tick starts a new row
      result.status = tsNewRow

      # determine next position
      case t.nextRowCmd:
      of pcNone: # no command, advance row by 1
        if t.incRow:
          inc t.pos.row
          if t.pos.row >= song.trackLen:
            result.status = nextPatternImpl(t, song)
          
      of pcNext: # Dxx command
        result.status = nextPatternImpl(t, song)
      of pcJump: # Bxx command
        t.pos.row = 0
        if not t.patternRepeat:
          t.pos.pattern = min(int(t.nextRowParam), song.order.len - 1)
          result.status = tsNewPattern
      
      # "consume" the command
      t.nextRowCmd = pcNone
      t.nextRowParam = 0
      
      # get the next row
      let prow = song.getRow(t.pos.pattern, t.pos.row)
      for ch, row in pairs(prow):
        if not row.isEmpty():
          # apply effectsFilter
          let filtered = filter(t.effectsFilter, row)
          if filtered != row:
            # one or more effects were filtered out, add this channel to the set
            result.filtered.incl(ch)
          t.tracks[ch].setRow(filtered)

    # tick track timers
    var pc = initPatternChange()
    for ch in ChannelId:
      if t.tracks[ch].tick(pc):
        # this channel has an op for this tick
        result.ops.incl(ch)

    if pc.shouldHalt:
      t.halt()
      result.status = tsHalted
    else:
      if pc.speed in Speed.low..Speed.high and int(pc.speed) != t.timer.period:
        t.timer.setPeriod(pc.speed)
        result.speedChanged = true
      if pc.cmd != pcNone:
        t.nextRowCmd = pc.cmd
        t.nextRowParam = pc.param
      t.incRow = t.timer.tick() and t.nextRowCmd == pcNone
        

# Pathing / runtime calculation

type
  PatternHistory = object
    # a history of rows visited in each pattern
    startRows: seq[set[ByteIndex]]

  PatternTracker = object
    tracker: Tracker
    itable: InstrumentTable
    history: PatternHistory
    
    current: SongPos
    currentAlreadyVisited: bool
    rowOfLastVisit: int
    halted: bool
    
    totalTicks: int

func initPatternHistory(totalPatterns: Positive): PatternHistory =
  # initialize a pattern history for a given number of patterns
  result.startRows.setLen(totalPatterns)

proc add(h: var PatternHistory; visit: SongPos): bool =
  # Adds the visit to the history, returns `true` if this visit was already
  # added.
  let pslot = h.startRows[visit.pattern].addr
  result = visit.row in pslot[]
  pslot[].incl(visit.row)

func initPatternTracker(song: Song; startPos: SongPos): PatternTracker =
  result = PatternTracker(
    tracker: initTracker(song, startPos),
    itable: InstrumentTable.init(),
    history: initPatternHistory(song.order.len),
    current: startPos,
    currentAlreadyVisited: false,
    halted: false,
    totalTicks: 0
  )
  discard result.history.add(startPos)

proc tick(pt: var PatternTracker; song: Song): int =
  var lastRow: int
  while true:
    inc result
    lastRow = pt.tracker.pos().row
    let tresult = tick(pt.tracker, song)
    case tresult.status
    of tsHalted:
      pt.halted = true
      break
    of tsNewPattern:
      pt.current = pt.tracker.pos()
      pt.currentAlreadyVisited = pt.history.add(pt.current)
      break
    else:
      discard
  pt.rowOfLastVisit = lastRow

#iterator all(sv: var SongVisitor; song: Song; )


func runtime*(song: Song; loopFor = Positive(1); startPos = default(SongPos)
              ): int =
  ## Gets the runtime in frames when playing a song.
  ## * `loopFor` is the number of times to loop
  ## * `startPos` is the starting position, default is start of the song
  ##
  ## The minimum runtime of a song is 1 frame, since 1 frame is required to be
  ## stepped in order for a song to halt.
  ##
  ## A runtime of 0 will be returned if `pattern` is greater than or equal to
  ## the song's order count or if `row` is greater than or equal to the song's
  ## track length. This means that the song cannot be played with these
  ## arguments and therefore has a runtime of 0 frames.
  ##
  if song.isValid(startPos):
    var
      pt = initPatternTracker(song, startPos)
      loopPos: Option[SongPos]
      loopCount = 0

    while true:
      if pt.currentAlreadyVisited:
        # we have revisited a previous visit
        var incrementLoopCount = false
        if loopPos.isNone():
          # first revisit is the loop point
          loopPos = some(pt.current)
          incrementLoopCount = true
        elif loopPos.get() == pt.current:
          # we have revisited the loop point again
          incrementLoopCount = true
        
        if incrementLoopCount:
          inc loopCount
          if loopCount == loopFor:
            dec result
            break

      result += pt.tick(song)
      if pt.halted:
        break

func runtime*(duration: Duration; framerate: float): int =
  ## Gets the runtime in frames when playing a song for a given time duration.
  ## 
  int(float(inSeconds(duration)) * framerate)

func runtime*(duration: Duration): int =
  ## Gets the runtime in frames when playing a song for a given time duration.
  ## The default framerate (DMG, 59.7 Hz) is used.
  ##
  const rate = defaultTickrate.hertz
  runtime(duration, rate)

func isValid*(p: SongPath): bool =
  ## Determines if a path is valid, or has one or more visits.
  ##
  result = p.visits.len > 0

func getPath*(song: Song; startPos = default(SongPos)): SongPath =
  ## Determines the path, or the order in which patterns are visited when
  ## performing a song. The calculated `SongPath` is returned for the given
  ## song, when starting at a specified pattern and row (default is the start
  ## of the song).
  ## 
  ## If `startRow` or `startPattern` are invalid positions for `song`, then an
  ## empty SongPath is returned.
  ##

  # invalid positions result in an empty path
  if song.isValid(startPos):
    var pt = initPatternTracker(song, startPos)
    while true:
      if pt.currentAlreadyVisited:
        # end of path: song loops
        for i, visit in pairs(result.visits):
          if visit.pos == pt.current:
            result.loopsTo = some(i)
            break
        break
      let current = pt.current
      discard pt.tick(song)
      result.visits.add(songSpan(current.pattern, current.row, pt.rowOfLastVisit))
      if pt.halted:
        # end of path: song halted
        break

