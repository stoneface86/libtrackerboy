##[

.. include:: warning.rst

]##

import
  ./hardware,
  ./ptrarith,
  ../common

import std/[algorithm, math]

export Pcm

const
  stepWidth = 16
  stepPhases = 32

type
  StepSet = array[stepWidth, float32]
  StepTable = array[stepPhases + 1, StepSet]
  
  Accumulator = object
    sum: float32
    highpass: float32

  MixMode* = enum
    ## Enum of possible mix operations: mute, left-only, right-only or
    ## middle (both).
    ##
    mixMute
    mixLeft
    mixRight
    mixMiddle

  Synth* {.requiresInit.} = object
    volumeStepLeft*, volumeStepRight*: float32
    samplerate: int
    # cycletime to sampletime conversion factor
    factor: float32
    # highpass filter rate
    highpass: float32
    # sample buffer, stereo interleaved f32 samples
    buffer: seq[Pcm]
    # fractional sample time offset
    sampleOffset: float32
    # sample accumulators
    accums: array[2, Accumulator]

const
  stepTable: StepTable = [
    [ 0.001312256f, -0.003509521f,  0.010681152f, -0.014892578f,  0.034667969f, -0.027893066f,  0.178863525f,  0.641540527f,  0.178863525f, -0.027893066f,  0.034667969f, -0.014892578f,  0.010681152f, -0.003509521f,  0.001312256f,  0.000000000f ],
    [ 0.001342773f, -0.003601074f,  0.010620117f, -0.014434814f,  0.032836914f, -0.024383545f,  0.160949707f,  0.640899658f,  0.197265625f, -0.031158447f,  0.036315918f, -0.015228271f,  0.010681152f, -0.003356934f,  0.001220703f,  0.000030518f ],
    [ 0.001373291f, -0.003692627f,  0.010498047f, -0.013854980f,  0.030853271f, -0.020660400f,  0.143615723f,  0.638916016f,  0.216125488f, -0.034149170f,  0.037780762f, -0.015441895f,  0.010589600f, -0.003112793f,  0.001068115f,  0.000091553f ],
    [ 0.001403809f, -0.003723145f,  0.010253906f, -0.013153076f,  0.028747559f, -0.016754150f,  0.126831055f,  0.635650635f,  0.235382080f, -0.036773682f,  0.039001465f, -0.015472412f,  0.010406494f, -0.002868652f,  0.000946045f,  0.000122070f ],
    [ 0.001434326f, -0.003753662f,  0.009979248f, -0.012329102f,  0.026489258f, -0.012756348f,  0.110748291f,  0.631072998f,  0.254974365f, -0.039062500f,  0.040039063f, -0.015380859f,  0.010162354f, -0.002593994f,  0.000793457f,  0.000183105f ],
    [ 0.001434326f, -0.003723145f,  0.009643555f, -0.011444092f,  0.024169922f, -0.008697510f,  0.095336914f,  0.625244141f,  0.274810791f, -0.040863037f,  0.040802002f, -0.015136719f,  0.009826660f, -0.002288818f,  0.000671387f,  0.000213623f ],
    [ 0.001434326f, -0.003662109f,  0.009246826f, -0.010498047f,  0.021789551f, -0.004608154f,  0.080688477f,  0.618164063f,  0.294799805f, -0.042205811f,  0.041320801f, -0.014739990f,  0.009429932f, -0.001922607f,  0.000488281f,  0.000274658f ],
    [ 0.001403809f, -0.003570557f,  0.008819580f, -0.009460449f,  0.019348145f, -0.000518799f,  0.066772461f,  0.609893799f,  0.314910889f, -0.043029785f,  0.041564941f, -0.014160156f,  0.008911133f, -0.001495361f,  0.000274658f,  0.000335693f ],
    [ 0.001403809f, -0.003479004f,  0.008331299f, -0.008392334f,  0.016876221f,  0.003570557f,  0.053649902f,  0.600433350f,  0.335052490f, -0.043304443f,  0.041534424f, -0.013397217f,  0.008300781f, -0.001068115f,  0.000091553f,  0.000396729f ],
    [ 0.001342773f, -0.003295898f,  0.007781982f, -0.007232666f,  0.014373779f,  0.007537842f,  0.041381836f,  0.589813232f,  0.355163574f, -0.042968750f,  0.041229248f, -0.012512207f,  0.007629395f, -0.000579834f, -0.000122070f,  0.000457764f ],
    [ 0.001312256f, -0.003143311f,  0.007232666f, -0.006072998f,  0.011901855f,  0.011383057f,  0.029937744f,  0.578125000f,  0.375152588f, -0.041992188f,  0.040618896f, -0.011444092f,  0.006896973f, -0.000091553f, -0.000366211f,  0.000549316f ],
    [ 0.001281738f, -0.002990723f,  0.006652832f, -0.004882813f,  0.009460449f,  0.015106201f,  0.019317627f,  0.565399170f,  0.394958496f, -0.040344238f,  0.039703369f, -0.010223389f,  0.006072998f,  0.000488281f, -0.000610352f,  0.000610352f ],
    [ 0.001220703f, -0.002777100f,  0.006042480f, -0.003692627f,  0.007049561f,  0.018646240f,  0.009582520f,  0.551696777f,  0.414489746f, -0.037963867f,  0.038482666f, -0.008850098f,  0.005187988f,  0.001037598f, -0.000823975f,  0.000671387f ],
    [ 0.001159668f, -0.002563477f,  0.005432129f, -0.002471924f,  0.004669189f,  0.022033691f,  0.000671387f,  0.537078857f,  0.433654785f, -0.034851074f,  0.036956787f, -0.007293701f,  0.004241943f,  0.001617432f, -0.001098633f,  0.000762939f ],
    [ 0.001098633f, -0.002319336f,  0.004791260f, -0.001312256f,  0.002441406f,  0.025146484f, -0.007354736f,  0.521606445f,  0.452392578f, -0.030975342f,  0.035156250f, -0.005615234f,  0.003234863f,  0.002227783f, -0.001342773f,  0.000823975f ],
    [ 0.001037598f, -0.002075195f,  0.004119873f, -0.000091553f,  0.000244141f,  0.028045654f, -0.014526367f,  0.505310059f,  0.470642090f, -0.026306152f,  0.033050537f, -0.003753662f,  0.002136230f,  0.002868652f, -0.001586914f,  0.000885010f ],
    [ 0.000976563f, -0.001861572f,  0.003509521f,  0.001037598f, -0.001831055f,  0.030700684f, -0.020843506f,  0.488311768f,  0.488311768f, -0.020843506f,  0.030700684f, -0.001831055f,  0.001037598f,  0.003509521f, -0.001861572f,  0.000976563f ],
    [ 0.000885010f, -0.001586914f,  0.002868652f,  0.002136230f, -0.003753662f,  0.033050537f, -0.026306152f,  0.470642090f,  0.505310059f, -0.014526367f,  0.028045654f,  0.000244141f, -0.000091553f,  0.004119873f, -0.002075195f,  0.001037598f ],
    [ 0.000823975f, -0.001342773f,  0.002227783f,  0.003234863f, -0.005615234f,  0.035156250f, -0.030975342f,  0.452392578f,  0.521606445f, -0.007354736f,  0.025146484f,  0.002441406f, -0.001312256f,  0.004791260f, -0.002319336f,  0.001098633f ],
    [ 0.000762939f, -0.001098633f,  0.001617432f,  0.004241943f, -0.007293701f,  0.036956787f, -0.034851074f,  0.433654785f,  0.537078857f,  0.000671387f,  0.022033691f,  0.004669189f, -0.002471924f,  0.005432129f, -0.002563477f,  0.001159668f ],
    [ 0.000671387f, -0.000823975f,  0.001037598f,  0.005187988f, -0.008850098f,  0.038482666f, -0.037963867f,  0.414489746f,  0.551696777f,  0.009582520f,  0.018646240f,  0.007049561f, -0.003692627f,  0.006042480f, -0.002777100f,  0.001220703f ],
    [ 0.000610352f, -0.000610352f,  0.000488281f,  0.006072998f, -0.010223389f,  0.039703369f, -0.040344238f,  0.394958496f,  0.565399170f,  0.019317627f,  0.015106201f,  0.009460449f, -0.004882813f,  0.006652832f, -0.002990723f,  0.001281738f ],
    [ 0.000549316f, -0.000366211f, -0.000091553f,  0.006896973f, -0.011444092f,  0.040618896f, -0.041992188f,  0.375152588f,  0.578125000f,  0.029937744f,  0.011383057f,  0.011901855f, -0.006072998f,  0.007232666f, -0.003143311f,  0.001312256f ],
    [ 0.000457764f, -0.000122070f, -0.000579834f,  0.007629395f, -0.012512207f,  0.041229248f, -0.042968750f,  0.355163574f,  0.589813232f,  0.041381836f,  0.007537842f,  0.014373779f, -0.007232666f,  0.007781982f, -0.003295898f,  0.001342773f ],
    [ 0.000396729f,  0.000091553f, -0.001068115f,  0.008300781f, -0.013397217f,  0.041534424f, -0.043304443f,  0.335052490f,  0.600433350f,  0.053649902f,  0.003570557f,  0.016876221f, -0.008392334f,  0.008331299f, -0.003479004f,  0.001403809f ],
    [ 0.000335693f,  0.000274658f, -0.001495361f,  0.008911133f, -0.014160156f,  0.041564941f, -0.043029785f,  0.314910889f,  0.609893799f,  0.066772461f, -0.000518799f,  0.019348145f, -0.009460449f,  0.008819580f, -0.003570557f,  0.001403809f ],
    [ 0.000274658f,  0.000488281f, -0.001922607f,  0.009429932f, -0.014739990f,  0.041320801f, -0.042205811f,  0.294799805f,  0.618164063f,  0.080688477f, -0.004608154f,  0.021789551f, -0.010498047f,  0.009246826f, -0.003662109f,  0.001434326f ],
    [ 0.000213623f,  0.000671387f, -0.002288818f,  0.009826660f, -0.015136719f,  0.040802002f, -0.040863037f,  0.274810791f,  0.625244141f,  0.095336914f, -0.008697510f,  0.024169922f, -0.011444092f,  0.009643555f, -0.003723145f,  0.001434326f ],
    [ 0.000183105f,  0.000793457f, -0.002593994f,  0.010162354f, -0.015380859f,  0.040039063f, -0.039062500f,  0.254974365f,  0.631072998f,  0.110748291f, -0.012756348f,  0.026489258f, -0.012329102f,  0.009979248f, -0.003753662f,  0.001434326f ],
    [ 0.000122070f,  0.000946045f, -0.002868652f,  0.010406494f, -0.015472412f,  0.039001465f, -0.036773682f,  0.235382080f,  0.635650635f,  0.126831055f, -0.016754150f,  0.028747559f, -0.013153076f,  0.010253906f, -0.003723145f,  0.001403809f ],
    [ 0.000091553f,  0.001068115f, -0.003112793f,  0.010589600f, -0.015441895f,  0.037780762f, -0.034149170f,  0.216125488f,  0.638916016f,  0.143615723f, -0.020660400f,  0.030853271f, -0.013854980f,  0.010498047f, -0.003692627f,  0.001373291f ],
    [ 0.000030518f,  0.001220703f, -0.003356934f,  0.010681152f, -0.015228271f,  0.036315918f, -0.031158447f,  0.197265625f,  0.640899658f,  0.160949707f, -0.024383545f,  0.032836914f, -0.014434814f,  0.010620117f, -0.003601074f,  0.001342773f ],
    # extra step! this step is just the first one reversed
    [ 0.000000000f,  0.001312256f, -0.003509521f,  0.010681152f, -0.014892578f,  0.034667969f, -0.027893066f,  0.178863525f,  0.641540527f,  0.178863525f, -0.027893066f,  0.034667969f, -0.014892578f,  0.010681152f, -0.003509521f,  0.001312256f ]
  ]

func pansLeft*(mode: MixMode): bool =
  ## Determine whether the mode pans left, returns `true` when mode is
  ## `mixLeft` or `mixMiddle`
  ##
  result = mode in { mixLeft, mixMiddle }

func pansRight*(mode: MixMode): bool =
  ## Determine whether the mode pans right, returns `true` when mode is
  ## `mixRight` or `mixMiddle`
  ##
  result = mode in { mixRight, mixMiddle }

template assertTime(s: Synth; t: int): untyped =
  assert t < s.buffer.len, "attempted to mix past the buffer"

template frameIndex(t: Natural): int = t * 2

func initAccumulator(): Accumulator =
  discard  # default is sufficient

proc process(a: var Accumulator; input, highpassRate: float32;): float32 =
  a.sum += input
  result = a.sum - a.highpass
  a.highpass = a.sum - (result * highpassRate)

func sampletime*(s: Synth; cycletime: uint32): float32 =
  (cycletime.float32 * s.factor) + s.sampleOffset

func getMixParam(s: Synth; cycletime: uint32
                ): tuple[step, timeIndex: int; timeFract: float32] =
  let time = s.sampletime(cycletime)
  let phase = (time - trunc(time)) * stepPhases.float32

  (
    step: phase.int,
    timeIndex: time.int,
    timeFract: phase - trunc(phase)
  )

func deltaScale(delta, scale, interp: float32;
               ): tuple[first, second: float32;] =
  let first = delta * scale
  let second = first * interp
  (first - second, second)

iterator iterateStep(s: int): tuple[s0, s1: float32;] =
  # unsafeAddr because the stepTable is a const
  var stepset = stepTable[s][0].unsafeAddr
  var nextset = stepTable[s + 1][0].unsafeAddr
  for i in 0..stepWidth-2:
    yield (stepset[], nextset[])
    ptrArith:
      inc stepset
      inc nextset
  yield (stepset[], nextset[])

proc mix*(s: var Synth; mode: static MixMode; delta: int8; cycletime: uint32) =
  static: assert mode != mixMute, "cannot mix a muted mode!"

  let params = s.getMixParam(cycletime)
  
  when mode.pansLeft:
    let deltaLeft = deltaScale(delta.float32, s.volumeStepLeft, params.timeFract)
  
  when mode.pansRight:
    let deltaRight = deltaScale(delta.float32, s.volumeStepRight, params.timeFract)

  # DANGER! pointer arithmetic is used for optimization purposes, but a bug
  # can cause a buffer overrun if the cycletime exceeds the length of the buffer

  var buf = block:
    let time = frameIndex(params.timeIndex)
    assertTime(s, time + stepWidth * 2)  # <- if this fails we will overrun the buffer
    s.buffer[time].addr
  ptrArith:
    when mode == mixRight:
      inc buf
    template advanceBuf() =
      when mode == mixMiddle:
        inc buf
      else:
        # skip next terminal
        buf += 2
    for s0, s1 in iterateStep(params.step):
      when mode.pansLeft:
        buf[] += deltaLeft.first * s0 + deltaLeft.second * s1
        advanceBuf
      when mode.pansRight:
        buf[] += deltaRight.first * s0 + deltaRight.second * s1
        advanceBuf


proc mix*(s: var Synth; mode: MixMode; delta: int8; cycletime: uint32) =
  case mode
  of mixLeft:
    s.mix(mixLeft, delta, cycletime)
  of mixRight:
    s.mix(mixRight, delta, cycletime)
  of mixMiddle:
    s.mix(mixMiddle, delta, cycletime)
  else:
    # do nothing for muted mode
    discard

proc mixDc*(s: var Synth; dcLeft, dcRight: PcmF32; cycletime: uint32) =
  let time = frameIndex(s.sampletime(cycletime).int)
  assertTime(s, time)
  s.buffer[time] += dcLeft
  s.buffer[time + 1] += dcRight

proc clear*(s: var Synth) =
  s.sampleOffset = 0
  s.accums.fill(initAccumulator())
  s.buffer.fill(0.0f)

func samplerate*(s: Synth): int =
  s.samplerate

proc `samplerate=`*(s: var Synth; samplerate: int) =
  if s.samplerate != samplerate:
    s.samplerate = samplerate
    s.factor = samplerate.float32 / gbClockRate.float32
    # sameboy's HPF
    s.highpass = pow(0.999958f, 1.0f / s.factor)

proc setBufferSize*(s: var Synth; samples: Natural) =
  s.buffer.setLen(frameIndex(samples + stepWidth))
  s.clear()

func initSynth*(samplerate = 44100; buffersize = Natural(0)): Synth =
  result = Synth(
    volumeStepLeft: 0.0f,
    volumeStepRight: 0.0f,
    samplerate: 0,
    factor: 0.0f,
    highpass: 0.0f,
    buffer: newSeq[Pcm](),
    sampleOffset: 0.0f,
    accums: [
      initAccumulator(),
      initAccumulator()
    ]
  )
  result.`samplerate=`(samplerate)
  result.setBufferSize(buffersize)

proc endFrame(s: var Synth; cycletime: uint32): int =
  # end the frame, discarding all mixed samples
  let split = splitDecimal(s.sampletime(cycletime))
  s.sampleOffset = split.floatpart
  assert split.intpart.int <= s.buffer.len, "end of frame exceeds buffer"
  split.intpart.int

proc takeSamples*(s: var Synth; endtime: uint32; buf: ptr seq[Pcm]) =
  # takes samples out of the synth's buffer and puts it into buf. If buf is
  # nil, the samples are discarded.
  let samplesToTake = s.endframe(endtime)
  let totalSamples = frameIndex(samplesToTake)
  if buf != nil:
    buf[].setLen(totalSamples)
    # move samples to the destination buf, after integrating and applying the
    # high pass filter
    var dest = buf[][0].addr
    var src = s.buffer[0].addr
    for i in 0..<samplesToTake:
      ptrArith:
        template accumulateChannel(channel: int): untyped =
          dest[] = s.accums[channel].process(src[], s.highpass)
          src[] = 0
          inc src
          inc dest
        accumulateChannel(0)
        accumulateChannel(1)
  else:
    s.buffer.fill(0, totalSamples-1, 0.0f)
  # copy leftovers to the front of the synth's buffer
  var d = totalSamples
  for i in 0..<(stepWidth*2):
    s.buffer[i] = s.buffer[d]
    s.buffer[d] = 0.0f
    inc d
