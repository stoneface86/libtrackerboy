##[

Game Boy APU emulation. Provides an Apu object that can synthesize audio to
an internal buffer when stepping for a given number of cycles. The emulated
registers can be read/written to, which can be used along side a full Game
Boy emulator, or to just generate audio when playing a module.

See also
--------

`Pan Docs<https://gbdev.io/pandocs/Sound_Controller.html>`_ for details about
the hardware being emulated.


]##

import 
  ./common,
  ./private/hardware,
  ./private/synth

import std/[bitops, algorithm, math]

export common
export MixMode, pansLeft, pansRight

const
  dcOffset: float32 = 7.5f

type
  Channel = object
    output: uint8
    dacEnable: bool
    enabled: bool

  Timer = object
    counter: uint32
    period: uint32

  LengthCounter = object
    enabled: bool
    counter: int
    counterMax: int

  Sweep = object
    subtraction: bool
    time: int
    shift: int
    counter: int
    register: uint8
    shadow: uint16

  Envelope = object
    register: uint8
    counter: uint8
    period: uint8
    amplify: bool
    volume: uint8

  NoiseChannel = object
    channel: Channel
    timer: Timer
    envelope: Envelope
    lc: LengthCounter
    register: uint8
    validScf: bool
    halfWidth: bool
    lfsr: uint16
  
  Duty = enum
    Duty125,
    Duty25,
    Duty50,
    Duty75

  PulseChannel = object
    channel: Channel
    timer: Timer
    envelope: Envelope
    lc: LengthCounter
    frequency: uint16
    duty: Duty
    dutyWaveform: uint8
    dutyCounter: uint8

  WaveVolume = enum
    WaveMute,
    WaveFull,
    WaveHalf,
    WaveQuarter

  WaveChannel = object
    channel: Channel
    timer: Timer
    lc: LengthCounter
    frequency: uint16
    waveram: array[16, uint8]
    waveIndex: uint8
    sampleBuffer: uint8
    volumeShift: int
    volume: WaveVolume

  Sequencer = object
    timer: Timer
    triggerIndex: int

  Apu* {.requiresInit.} = object
    ## Game Boy APU emulator. Satisfies the `ApuIo<apuio.html#ApuIo>`_ concept.
    ## 
    ch1, ch2: PulseChannel
    ch3: WaveChannel
    ch4: NoiseChannel
    sweep: Sweep
    sequencer: Sequencer
    synth: Synth
    mix: array[4, MixMode]
    lastOutputs: array[4, uint8]
    time: uint32
    leftVolume, rightVolume: int
    nr51: uint8
    enabled: bool
    volumeStep: float32
    autostep*: uint32
    framerate: float
    cyclesPerFrame: float
    cycleOffset: float

{. push raises: [] .}

# Timer =======================================================================

proc initTimer(initPeriod: uint32): Timer =
  Timer(
    counter: initPeriod,
    period: initPeriod
  )

proc run(t: var Timer; cycles: uint32): bool =
  # if this assertion fails, we have missed a clock!
  assert t.counter >= cycles
  t.counter -= cycles
  result = t.counter == 0
  if result:
    # reload counter with period
    t.counter = t.period

proc fastforward(t: var Timer; cycles: uint32): uint32 =
  if cycles < t.counter:
    t.counter -= cycles
    0u32
  else:
    let c = cycles - t.counter
    let clocks = (c div t.period) + 1
    t.counter = t.period - (c mod t.period)
    clocks

proc restart(t: var Timer) =
  t.counter = t.period

# Channel =====================================================================

proc initChannel(): Channel =
  Channel(
    output: 0,
    dacEnable: false,
    enabled: false
  )

proc disable(ch: var Channel) =
  ch.enabled = false

proc setDacEnable(ch: var Channel; enable: bool) =
  ch.dacEnable = enable
  if not enable:
    ch.disable()

proc restart(ch: var Channel) =
  ch.enabled = ch.dacEnable



# Envelope ====================================================================

proc initEnvelope(): Envelope =
  Envelope(
    register: 0,
    counter: 0,
    period: 0,
    amplify: false,
    volume: 0
  )

proc writeRegister(e: var Envelope; ch: var Channel; val: uint8) =
  e.register = val
  ch.setDacEnable((val and 0xF8).bool)

proc clock(e: var Envelope) =
  if e.period > 0:
    inc e.counter
    if e.counter == e.period:
      e.counter = 0
      if e.amplify:
        if e.volume < 0xF:
          inc e.volume
      else:
        if e.volume > 0:
          dec e.volume

proc restart(e: var Envelope) =
  e.counter = 0
  e.period = e.register and 7
  e.amplify = testBit(e.register, 3)
  e.volume = e.register shr 4

# LengthCounter ===============================================================

proc initLengthCounter(max: int): LengthCounter =
  LengthCounter(
    enabled: false,
    counter: 0,
    counterMax: max
  )

proc clock(l: var LengthCounter; ch: var Channel) =
  if l.enabled:
    if l.counter == 0:
      ch.disable()
    else:
      dec l.counter

proc restart(l: var LengthCounter) =
  if l.counter == 0:
    l.counter = l.counterMax

# NoiseChannel ================================================================

#
# when bit 0 of val:
#   0: return 0
#   1: return vol
#
template getOutput(val, vol: uint8;): uint8 =
  ( ( not (val and 1) ) + 1 ) and vol

const
  noiseDefaultPeriod = 8u32
  lfsrInit = 0x7FFFu16

proc initNoiseChannel(): NoiseChannel =
  NoiseChannel(
    channel: initChannel(),
    timer: initTimer(noiseDefaultPeriod),
    envelope: initEnvelope(),
    lc: initLengthCounter(64),
    register: 0,
    validScf: true,
    halfWidth: false,
    lfsr: lfsrInit
  )

proc setNoise(n: var NoiseChannel; val: uint8) =
  n.register = val
  # drf = dividing ratio frequency (divisor)
  var drf = (val and 0x7).uint32
  if drf == 0:
    drf = 8
  else:
    drf *= 16
  n.halfWidth = testBit(val, 3)
  # scf = shift clock frequency
  let scf = val shr 4
  # obscure behavior: a scf of 14 or 15 results in the channel receiving no clocks
  n.validScf = scf < 0xE
  n.timer.period = drf shl scf

proc clockLfsr(n: var NoiseChannel) =
  let shifted = n.lfsr shr 1
  let bit = (n.lfsr xor shifted) and 1
  # shift + feedback
  n.lfsr = shifted or (bit shl 14)
  if n.halfWidth:
    if bit == 0:
      clearBit(n.lfsr, 7)
    else:
      setBit(n.lfsr, 7)

proc updateOutput(n: var NoiseChannel) =
  # channel output is bit 0 of the lfsr
  #   when 1: 0
  #   when 0: envelope.volume
  n.channel.output = getOutput(not n.lfsr.uint8, n.envelope.volume)

proc clock(n: var NoiseChannel) =
  if n.validScf:
    n.clockLfsr()
    n.updateOutput()

proc fastforward(n: var NoiseChannel; cycles: uint32) =
  var clocks = n.timer.fastforward(cycles)
  if n.validScf:
    while clocks > 0:
      n.clockLfsr()
      dec clocks
    n.updateOutput()

proc restart(n: var NoiseChannel) =
  n.channel.restart()
  n.timer.restart()
  n.envelope.restart()
  n.lc.restart()
  n.lfsr = lfsrInit
  n.channel.output = 0


# PulseChannel ================================================================

const
  pulseMultiplier = 4
  pulseDefaultPeriod = (2048 - 0) * pulseMultiplier

  dutyWaveforms: array[Duty, uint8] = [
    0b00000001u8, # 12.5% -_______
    0b10000001u8, # 25.0% -______-
    0b10000111u8, # 50.0% ---____-
    0b01111110u8  # 75.0% _------_
  ]

template dutyToRegister(duty: Duty): uint8 =
  0x3F or (ord(duty).uint8 shl 6)

template dutyFromRegister(reg: uint8): Duty =
  Duty(reg shr 6)


proc initPulseChannel(): PulseChannel =
  PulseChannel(
    channel: initChannel(),
    timer: initTimer(pulseDefaultPeriod),
    envelope: initEnvelope(),
    lc: initLengthCounter(64),
    frequency: 0,
    duty: Duty75,
    dutyWaveform: dutyWaveforms[Duty75],
    dutyCounter: 0
  )

proc writeFrequency(p: var PulseChannel; freq: uint16) =
  p.frequency = freq
  p.timer.period = (2048 - freq).uint32 * pulseMultiplier

proc setDuty(p: var PulseChannel; duty: Duty) =
  p.duty = duty
  p.dutyWaveform = dutyWaveforms[duty]

proc updateOutput(p: var PulseChannel) =
  p.channel.output = getOutput(p.dutyWaveform shr p.dutyCounter, p.envelope.volume) 

proc clock(p: var PulseChannel) =
  p.dutyCounter = (p.dutyCounter + 1) and 7
  p.updateOutput()

proc fastforward(p: var PulseChannel; cycles: uint32) =
  let clocks = p.timer.fastforward(cycles)
  p.dutyCounter = ((p.dutyCounter + clocks) and 7).uint8
  p.updateOutput()

proc restart(p: var PulseChannel) =
  p.channel.restart()
  p.timer.restart()
  p.envelope.restart()
  p.lc.restart()

# WaveChannel =================================================================

const
  waveMultiplier = 2
  waveDefaultPeriod = (2048 - 0) * waveMultiplier
  waveVolumeShifts: array[WaveVolume, int] = [
    4,
    0,
    1,
    2
  ]


proc initWaveChannel(): WaveChannel =
  WaveChannel(
    channel: initChannel(),
    timer: initTimer(waveDefaultPeriod),
    lc: initLengthCounter(256),
    frequency: 0,
    waveIndex: 0,
    sampleBuffer: 0,
    volumeShift: 0,
    volume: WaveMute
  )

proc updateOutput(w: var WaveChannel) =
  w.channel.output = w.sampleBuffer shr w.volumeShift

proc setVolume(w: var WaveChannel; vol: WaveVolume) =
  w.volume = vol
  w.volumeShift = waveVolumeShifts[vol]
  w.updateOutput()

proc writeFrequency(w: var WaveChannel; freq: uint16) =
  w.frequency = freq
  w.timer.period = (2048 - freq).uint32 * waveMultiplier

proc updateSampleBuffer(w: var WaveChannel) =
  w.sampleBuffer = w.waveram[w.waveIndex shr 1]
  if testBit(w.waveIndex, 0):
    # odd number, low nibble
    w.sampleBuffer = w.sampleBuffer and 0xF
  else:
    # even number, high nibble
    w.sampleBuffer = w.sampleBuffer shr 4
  w.updateOutput()

proc clock(w: var WaveChannel) =
  w.waveIndex = (w.waveIndex + 1) and 0x1F
  w.updateSampleBuffer()

proc fastforward(w: var WaveChannel; cycles: uint32) =
  let clocks = w.timer.fastforward(cycles)
  w.waveIndex = ((w.waveIndex + clocks) and 0x1F).uint8
  w.updateSampleBuffer()

proc restart(w: var WaveChannel) =
  w.channel.restart()
  w.timer.restart()
  w.lc.restart()
  w.waveIndex = 0

# Sweep =======================================================================

proc initSweep(): Sweep =
  Sweep(
    subtraction: false,
    time: 0,
    shift: 0,
    counter: 0,
    register: 0,
    shadow: 0
  )

proc readRegister(s: Sweep): uint8 =
  s.register and 0x7F

proc writeRegister(s: var Sweep; val: uint8) =
  s.register = val and 0x7F

proc clock(s: var Sweep; pul: var PulseChannel) =
  if s.time > 0:
    inc s.counter
    if s.counter >= s.time:
      s.counter = 0
      if s.shift > 0:
        var freq = s.shadow shr s.shift
        if s.subtraction:
          if freq > s.shadow:
            # underflow, no change to frequency
            return
          freq = s.shadow - freq
        else:
          freq += s.shadow
          if freq > 2047:
            # overflow, disable channel
            pul.channel.disable()
            return
        pul.writeFrequency(freq)
        s.shadow = freq

proc restart(s: var Sweep; pul: var PulseChannel) =
  s.counter = 0
  s.shift = (s.register and 0x7).int
  s.subtraction = testBit(s.register, 3)
  s.time = ((s.register shr 4) and 0x7).int
  s.shadow = pul.frequency

# Sequencer ===================================================================

type TriggerType = enum
  TriggerLc,
  TriggerLcSweep,
  TriggerEnv

const
  cyclesPerStep = 8192u32
  triggerSequence: array[5, tuple[nextIndex: int, period: uint32, trigger: TriggerType]] = [
    (1, cyclesPerStep * 2,  TriggerLc),
    (2, cyclesPerStep * 2,  TriggerLcSweep),
    (3, cyclesPerStep,      TriggerLc),
    (4, cyclesPerStep,      TriggerLcSweep),
    (0, cyclesPerStep * 2,  TriggerEnv)
  ]

proc initSequencer(): Sequencer =
  Sequencer(
    timer: initTimer(cyclesPerStep * 2),
    triggerIndex: 0
  )

proc run(s: var Sequencer; apu: var Apu; cycles: uint32) =
  if (s.timer.run(cycles)):
    let trigger = triggerSequence[s.triggerIndex]
    proc triggerLc(apu: var Apu) =
      apu.ch1.lc.clock(apu.ch1.channel)
      apu.ch2.lc.clock(apu.ch2.channel)
      apu.ch3.lc.clock(apu.ch3.channel)
      apu.ch4.lc.clock(apu.ch4.channel)

    case trigger[2]:
    of TriggerLc:
      triggerLc(apu)
    of TriggerLcSweep:
      triggerLc(apu)
      apu.sweep.clock(apu.ch1)
    of TriggerEnv:
      apu.ch1.envelope.clock()
      apu.ch2.envelope.clock()
      apu.ch4.envelope.clock()
    s.timer.period = trigger[1]
    s.triggerIndex = trigger[0]

proc timeToTrigger(s: Sequencer): uint32 {.inline.} =
  s.timer.counter

# Apu =========================================================================

proc updateVolume(a: var Apu) =
  a.synth.volumeStepLeft = a.leftVolume.float32 * a.volumeStep
  a.synth.volumeStepRight = a.rightVolume.float32 * a.volumeStep

proc setVolume*(a: var Apu; gain: range[0.0f32..1.0f32]) =
  ## Sets the volume level of `a` to the given linear gain value. The gain
  ## should range from 0.0f to 1.0f. The default volume level is a linear
  ## value of 0.625f or about -4 dB
  ##
  runnableExamples:
    var a = initApu(44100)
    a.setVolume(0.5f)

  # 4 channels
  # channel volume ranges from 0-15 (15 steps)
  # master volume ranges from 0-7 (8 steps, 0 is not mute)
  # 15 * 8 * 4 = 480
  # so 480 is the maximum possible volume on all channels
  a.volumeStep = gain / 480.0f
  a.updateVolume()

proc setFramerate*(a: var Apu; framerate: float) =
  ## Changes the size of frame to the given framerate. The APU must be reset
  ## when changing the framerate.
  ##
  a.framerate = framerate
  a.cyclesPerFrame = gbClockrate.float / framerate
  a.cycleOffset = 0.0
  a.synth.setBufferSize((a.synth.samplerate.float / framerate).ceil.int + 1)

func initApu*(samplerate: int; framerate = 59.7): Apu =
  ## Initializes an Apu with the given samplerate and internal buffer size
  ## that contains a single frame with the given framerate.
  ## `samplerate` and `framerate` are in Hz and must be greater than 0.
  ## 
  ## The returned `Apu` is in its default, or hardware reset, state. The
  ## volume step is set to a default of 0.625f.
  ##
  runnableExamples:
    var a = initApu(24000, 60.0) # 24000 Hz samplerate with a 60 Hz framerate
  result = Apu(
    ch1: initPulseChannel(),
    ch2: initPulseChannel(),
    ch3: initWaveChannel(),
    ch4: initNoiseChannel(),
    sweep: initSweep(),
    sequencer: initSequencer(),
    synth: initSynth(samplerate),
    mix: default(Apu.mix.type),
    lastOutputs: default(Apu.lastOutputs.type),
    time: 0,
    leftVolume: 1,
    rightVolume: 1,
    nr51: 0,
    enabled: false,
    volumeStep: 0.0f,
    autostep: 16,
    framerate: 0.0,
    cyclesPerFrame: 0.0,
    cycleOffset: 0.0
  )
  result.setVolume(0.625f)
  result.setFramerate(framerate)

proc reset*(a: var Apu) =
  ## Resets the apu to its initial state. Should behave similarly to a
  ## hardware reset. The internal sample buffer is also cleared.
  ##
  runnableExamples:
    var a = initApu(44100)
    a.writeRegister(0x26, 0x80)
    a.writeRegister(0x12, 0xF2)
    assert a.readRegister(0x12) == 0xF2u8
    a.reset()
    assert a.readRegister(0x12) == 0xFFu8
    assert a.availableSamples == 0
  a.ch1 = initPulseChannel()
  a.ch2 = initPulseChannel()
  a.ch3 = initWaveChannel()
  a.ch4 = initNoiseChannel()
  a.sweep = initSweep()
  a.sequencer = initSequencer()
  a.synth.clear()
  a.mix.fill(mixMute)
  a.lastOutputs.fill(0u8)
  a.time = 0
  a.nr51 = 0
  a.enabled = false
  a.leftVolume = 1
  a.rightVolume = 1
  a.cycleOffset = 0.0

proc silence(a: var Apu; ch: int; time: uint32) =
  let output = a.lastOutputs[ch]
  if output > 0:
    a.synth.mix(a.mix[ch], -(output.int8), time)
    a.lastOutputs[ch] = 0

proc preRunChannel(a: var Apu; chno: int; ch: Channel; time: uint32): MixMode =
  if ch.dacEnable and ch.enabled:
    result = a.mix[chno]
  else:
    a.silence(chno, time)
    result = mixMute

# type class for all of the Channel objects
type SomeChannel = PulseChannel|WaveChannel|NoiseChannel

proc mixChannel(a: var Apu; mix: static MixMode; ch: Channel; last: var uint8;
                time: uint32) =
  if ch.output != last:
    a.synth.mix(mix, ch.output.int8 - last.int8, time)
    last = ch.output

proc runChannel[T: SomeChannel](a: var Apu; chno: int; ch: var T; 
                                time, cycles: uint32;) =
  
  template runImpl(mix: static MixMode) =
    var last = a.lastOutputs[chno]
    a.mixChannel(mix, ch.channel, last, time)
    var timeCounter = time + ch.timer.counter

    # determine the number of clocks to run
    var clocks = ch.timer.fastforward(cycles)
    while clocks > 0:
      ch.clock()
      dec clocks
      a.mixChannel(mix, ch.channel, last, timeCounter)
      timeCounter += ch.timer.period
    
    a.lastOutputs[chno] = last
  
  case a.preRunChannel(chno, ch.channel, time):
  of mixMute:
    ch.fastforward(cycles)
  of mixLeft:
    runImpl(mixLeft)
  of mixRight:
    runImpl(mixRight)
  of mixMiddle:
    runImpl(mixMiddle)


proc run*(a: var Apu; cycles: uint32) =
  ## Runs the apu `a` for a given number of cycles. The internal sample
  ## buffer is updated with new samples from the run. Use
  ## `takeSamples<#takeSamples,Apu,seq[Pcm]>`_ afterwards to collect them for
  ## processing, or `removeSamples<#removeSamples,Apu>`_ to discard them.
  ##

  runnableExamples:
    var a = initApu(44100, 1.0)
    a.run(4194304) # 1 second
    assert a.availableSamples == 44100
    # another call to run will overrun the buffer
    # to empty the buffer do either:
    #  a.takeSamples(buffer)
    #  a.removeSamples()

  var cycleCountdown = cycles
  #var time = a.time
  while cycleCountdown > 0:
    # run components to the beat of the sequencer
    let toStep = min(cycleCountdown, a.sequencer.timeToTrigger())
    a.runChannel(0, a.ch1, a.time, toStep)
    a.runChannel(1, a.ch2, a.time, toStep)
    a.runChannel(2, a.ch3, a.time, toStep)
    a.runChannel(3, a.ch4, a.time, toStep)
    a.sequencer.run(a, toStep)

    cycleCountdown -= toStep
    a.time += toStep

proc runToFrame*(a: var Apu) =
  ## Runs the apu `a` for the required number of cycles to complete a frame.
  ## The amount of cycles that is run is determined by `a`'s current time and
  ## the framerate setting.
  ##
  runnableExamples:
    var a = initApu(48000, 60.0)
    a.runToFrame()
    # there are 800 samples in a frame
    # and 69905.06 cycles in a frame
    # so we step 69905 cycles which results in 799 samples instead
    # (eventually there will be one frame with 800 samples)
    assert a.availableSamples == 799
  let cycles = a.cyclesPerFrame - a.time.float + a.cycleOffset
  if cycles > 0.0:
    let split = splitDecimal(cycles)
    a.run(split.intpart.uint32)
    a.cycleOffset = split.floatpart

template cannotAccessRegister(a: Apu; reg: uint8): bool =
  not a.enabled and reg < rNR52

func readRegister*(a: var Apu; reg: uint8): uint8 =
  ##
  ## Reads the register at address `reg`. This proc emulates the behavior of
  ## reading the memory-mapped registers on an actual Game Boy. Since some
  ## registers are write-only (ie frequency), attempting to read these
  ## registers will result in their bits being read back as all 1s.
  ## 
  ## `reg` is the memory address of the register in the 0xFF00 page, so
  ## to read rNR10, 0xFF10, you would call this proc with `reg = 0x10u8`
  ## 
  ## The read occurs at the apu's current timestep, `run` the apu beforehand
  ## if you want the read to occur at a certain point in time.
  ## 
  ## The proc will return 0xFF for any invalid reg address.
  ## 
  
  runnableExamples:
    var a = initApu(44100)
    # sound is OFF, all reads should result in 0xFF
    assert a.readRegister(0x10) == 0xFFu8
    # NR52 should be 0x70
    assert a.readRegister(0x26) == 0x70u8

  template readNRx4(lc: LengthCounter): uint8 =
    if lc.enabled: 0xFF else: 0xBF

  a.run(a.autostep)

  if a.cannotAccessRegister(reg):
    return 0xFF

  case reg:
  of rNR10:
    result = a.sweep.readRegister()
  of rNR11:
    result = dutyToRegister(a.ch1.duty)
  of rNR12:
    result = a.ch1.envelope.register
  of rNR13, rNR23, rNR33:
    result = 0xFF
  of rNR14:
    result = readNRx4(a.ch1.lc)
  of rNR21:
    result = dutyToRegister(a.ch2.duty)
  of rNR22:
    result = a.ch2.envelope.register
  of rNR24:
    result = readNRx4(a.ch2.lc)
  of rNR30:
    result = if a.ch3.channel.dacEnable: 0xFF else: 0x7F
  of rNR31:
    result = 0xFF
  of rNR32:
    result = 0x9F or (a.ch3.volume.uint8 shl 5)
  of rNR34:
    result = readNRx4(a.ch3.lc)
  of rNR41:
    result = 0xFF
  of rNR42:
    result = a.ch4.envelope.register
  of rNR43:
    result = a.ch4.register
  of rNR44:
    result = readNRx4(a.ch4.lc)
  of rNR50:
    result = ((a.leftVolume.uint8 - 1) shr 4) or (a.rightVolume.uint8 - 1)
  of rNR51:
    result = a.nr51
  of rNR52:
    if a.enabled:
      result = 0xF0
      template channelStatus(stat: var uint8, chno: ChannelId, ch: Channel) =
        if ch.dacEnable:
          stat.setBit(chno.ord)
      channelStatus(result, ch1, a.ch1.channel)
      channelStatus(result, ch2, a.ch2.channel)
      channelStatus(result, ch3, a.ch3.channel)
      channelStatus(result, ch4, a.ch4.channel)
    else:
      result = 0x70
  of rWAVERAM..(rWAVERAM + 15):
    if a.ch3.channel.dacEnable:
      result = 0xFF
    else:
      result = a.ch3.waveram[reg - rWAVERAM]
  else:
    result = 0xFF

proc writeRegister*(a: var Apu; reg, value: uint8;) =
  ## Writes `value` to the apu's register at `reg` address. Like
  ## `readRegister<#readRegister,Apu,uint8>`_, this proc emulates writing to
  ## the Game Boy's memory-mapped APU registers. Writes to any unknown
  ## address are ignored. Writes to read-only portions of registers are also
  ## ignored. Like readRegister, the write occurs at the apu's current `time`.
  ##
  
  runnableExamples:
    var a = initApu(44100)
    a.writeRegister(0x12, 0xC0) # APU is off, write is ignored
    a.writeRegister(0x26, 0x80) # turn APU on
    assert a.readRegister(0x12) == 0x00
    a.writeRegister(0x12, 0xC0)
    assert a.readRegister(0x12) == 0xC0
    a.writeRegister(0xD3, 0xCC) # invalid register, write is ignored

  a.run(a.autostep)

  if a.cannotAccessRegister(reg):
    return

  template writeDutyLc(ch: PulseChannel; value: uint8) =
    ch.setDuty(dutyFromRegister(value))
    ch.lc.counter = (value and 0x3F).int

  template writeFrequencyLsb(ch: SomeChannel; value: uint8) =
    when ch is NoiseChannel:
      ch.setNoise(value)
    else:
      ch.writeFrequency((ch.frequency and 0xFF00) or value.uint16)
  
  template writeFrequencyMsb(ch: SomeChannel; value: uint8; body: untyped) =
    when ch isnot NoiseChannel:
      ch.writeFrequency((ch.frequency and 0x00FF) or ((value.uint16 and 7) shl 8))
    ch.lc.enabled = value.testBit(6)
    if value.testBit(7):
      ch.restart()
      ch.lc.restart()
      when ch isnot WaveChannel:
        ch.envelope.restart()
      body

  case reg:
  of rNR10:
    a.sweep.writeRegister(value)
  of rNR11:
    writeDutyLc(a.ch1, value)
  of rNR12:
    a.ch1.envelope.writeRegister(a.ch1.channel, value)
  of rNR13:
    writeFrequencyLsb(a.ch1, value)
  of rNR14:
    writeFrequencyMsb(a.ch1, value):
      a.sweep.restart(a.ch1)
  of rNR21:
    writeDutyLc(a.ch2, value)
  of rNR22:
    a.ch2.envelope.writeRegister(a.ch2.channel, value)
  of rNR23:
    writeFrequencyLsb(a.ch2, value)
  of rNR24:
    writeFrequencyMsb(a.ch2, value):
      discard
  of rNR30:
    a.ch3.channel.dacEnable = value.testBit(7)
  of rNR31:
    a.ch3.lc.counter = value.int
  of rNR32:
    a.ch3.setVolume(((value shr 5) and 3).WaveVolume)
  of rNR33:
    writeFrequencyLsb(a.ch3, value)
  of rNR34:
    writeFrequencyMsb(a.ch3, value):
      discard
  of rNR41:
    a.ch4.lc.counter = (value and 0x3F).int
  of rNR42:
    a.ch4.envelope.writeRegister(a.ch4.channel, value)
  of rNR43:
    writeFrequencyLsb(a.ch4, value)
  of rNR44:
    writeFrequencyMsb(a.ch4, value):
      discard
  of rNR50:
    a.leftVolume = ((value shr 4) and 7).int + 1
    a.rightVolume = (value and 7).int + 1

    # a change in volume requires a transition to the new volume step
    let oldVolumeLeft = a.synth.volumeStepLeft
    let oldVolumeRight = a.synth.volumeStepRight
    a.updateVolume()
    let leftDiff = a.synth.volumeStepLeft - oldVolumeLeft
    let rightDiff = a.synth.volumeStepRight - oldVolumeRight

    var dcLeft, dcRight = 0.0f
    for chno, mix in a.mix.pairs:
      let output = a.lastOutputs[chno].float32 - dcOffset

      if mix.pansLeft():
        dcLeft += output * leftDiff
      if mix.pansRight():
        dcRight += output * rightDiff

    a.synth.mixDc(dcLeft, dcRight, a.time)
  of rNR51:
    if a.nr51 != value:
      a.nr51 = value

      var nr51 = value
      var dcLeft = 0.0f
      var dcRight = 0.0f
      for chno, mode in a.mix.mpairs:
        let newmode = ((nr51 and 1) or ((nr51 shr 3) and 2)).MixMode
        nr51 = nr51 shr 1
        if newmode != mode:
          let changes = (ord(newmode) xor ord(mode))
          let level = dcOffset - a.lastOutputs[chno].float32
          if (changes and ord(mixLeft)) > 0:
            if newmode.pansLeft:
              dcLeft -= level
            else:
              dcLeft += level
          if (changes and ord(mixRight)) > 0:
            if newmode.pansRight:
              dcRight -= level
            else:
              dcRight += level
          mode = newmode
      a.synth.mixDc(dcLeft * a.synth.volumeStepLeft, dcRight * a.synth.volumeStepRight, a.time)
  of rNR52:
    if value.testBit(7) != a.enabled:
      if a.enabled:
        # shutdown
        for reg in rNR10..rNR51:
          a.writeRegister(reg, 0)
        a.enabled = false
      else:
        # startup
        a.enabled = true
  of rWAVERAM..rWAVERAM+15:
    if not a.ch3.channel.dacEnable:
      a.ch3.waveram[reg - rWAVERAM] = value
  else:
    discard

func time*(a: Apu): uint32 =
  ## Gets the apu's current time, in cycles. Calling `takeSamples<#takeSamples,Apu,seq[Pcm]>`_
  ## resets the time to 0.
  ##
  runnableExamples:
    var a = initApu(44100)
    assert a.time == 0
    a.run(1000)
    assert a.time == 1000
    a.run(100)
    assert a.time == 1100
    a.removeSamples()
    assert a.time == 0      # takeSamples will also reset time to 0
  a.time

proc availableSamples*(a: Apu): int =
  ## Gets the amount of samples available in the buffer.
  ## `takeSamples<#takeSamples,Apu,seq[Pcm]>`_ will take this exact amount
  ## of samples when called
  ##
  a.synth.sampletime(a.time).int

proc takeOrRemove(a: var Apu; buf: ptr seq[Pcm]) =
  a.synth.takeSamples(a.time, buf)
  a.time = 0

proc takeSamples*(a: var Apu, buf: var seq[Pcm]) =
  ## Takes out the entire sample buffer and puts it into the given buf. The
  ## buf's len will be set to `a.availableSamples * 2` and will have the
  ## contents of the apu's sample buffer.
  ##
  a.takeOrRemove(buf.addr)

proc removeSamples*(a: var Apu) =
  ## Removes all samples in the sample buffer.
  ##
  a.takeOrRemove(nil)

proc setSamplerate*(a: var Apu; samplerate: int) =
  ## Sets the samplerate of the generated audio. The internal sample buffer
  ## is left untouched, so it is recommended you call `takeSamples<#takeSamples,Apu,seq[Pcm]>`_
  ## beforehand.
  ##
  a.synth.samplerate = samplerate

proc setBufferSize*(a: var Apu; samples: int) =
  ## Sets the apu's internal buffer to the given number of samples. This will
  ## destroy the contents of the buffer so it is recommended you call
  ## `takeSamples<#takeSamples,Apu,seq[Pcm]>`_ first.
  ##
  a.synth.setBufferSize(samples)
  a.time = 0

func channelFrequency*(a: Apu; chno: ChannelId): int =
  ## Gets the current frequency setting for the channel, for diagnostic
  ## purposes. Channels 1-3 will result in a value from 0 to 2047. Channel
  ## 4 will result in the contents of its NR43 register.
  ##
  runnableExamples:
    var a = initApu(44100)
    assert a.channelFrequency(ch2) == 0
  case chno:
  of ch1: result = a.ch1.frequency.int
  of ch2: result = a.ch2.frequency.int
  of ch3: result = a.ch3.frequency.int
  of ch4: result = a.ch4.register.int

func channelVolume*(a: Apu; chno: ChannelId): int =
  ## Returns a number from 0 to 15 resprenting the current volume level of
  ## the channel. For channels with an enevelope, this level is the current
  ## volume of the envelope. For the Wave channel, this value is the maximum
  ## possible determined by the wave volume setting (NR32).
  ##
  runnableExamples:
    var a = initApu(44100)
    assert a.channelVolume(ch1) == 0
    assert a.channelVolume(ch3) == 0
    a.writeRegister(0x26, 0x80)  # NR52 <- 0x80
    a.writeRegister(0x12, 0xD0)  # NR12 <- 0xD0
    a.writeRegister(0x14, 0x80)  # NR14 <- 0x80
    a.writeRegister(0x1C, 0x20)  # NR32 <- 0x20
    assert a.channelVolume(ch1) == 0xD
    assert a.channelVolume(ch3) == 0xF

  proc impl(ch: SomeChannel): int =
    when ch.type is WaveChannel:
      case ch.volume:
      of WaveMute: result = 0
      of WaveFull: result = 15
      of WaveHalf: result = 7
      of WaveQuarter: result = 3
    else:
      result = ch.envelope.volume.int

  case chno:
  of ch1: result = impl(a.ch1)
  of ch2: result = impl(a.ch2)
  of ch3: result = impl(a.ch3)
  of ch4: result = impl(a.ch4)

func channelMix*(a: Apu; chno: ChannelId): MixMode =
  ## Gets the current mix mode for the given channel. Provided as an alternative
  ## to reading ar51.
  ##
  runnableExamples:
    var a = initApu(44100)
    a.writeRegister(0x26, 0x80)         # NR52 <- 0x80
    a.writeRegister(0x25, 0b00110101)   # NR51 <- 0x35
    assert a.channelMix(ch1) == mixMiddle
    assert a.channelMix(ch2) == mixRight
    assert a.channelMix(ch3) == mixLeft
    assert a.channelMix(ch4) == mixMute
  result = a.mix[chno.ord]

{. pop .}
