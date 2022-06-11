##[

The engine module is responsible for playing a song from a module. Similar
to a sound driver, the engine is stepped every frame and the APU's registers
are updated in order to play music.

]##

## common abbrievations
## fc - frequency control
## tc - track control
## mr - music runtime
## chno - channel number

import apuio, common, data, notes, private/[hardware]
export common

import std/[bitops, options, with]

export Module, Song, ApuIo


type

    PatternCommand = enum
        pcNone
        pcNext
        pcJump

    FrequencyMod = enum
        freqNone
        freqPortamento
        freqPitchUp
        freqPitchDown
        freqNoteUp
        freqNoteDown
        freqArpeggio

    FcMode = enum
        fcmNone,
        fcmPortamento,
        fcmPitchSlide,
        fcmNoteSlide,
        fcmArpeggio

    Operation = object
        ## An Operation is the processed form of a TrackRow, that is ready to
        ## be perfomed by the TrackControl
        patternCommand: PatternCommand
        patternCommandParam: uint8
        speed: uint8
        volume: uint8
        halt: bool
        note: Option[uint8]
        instrument: Option[uint8]
        delay: uint8
        duration: Option[uint8]
        envelope: Option[uint8]
        timbre: Option[uint8]
        panning: Option[uint8]
        sweep: Option[uint8]
        freqMod: FrequencyMod
        freqModParam: uint8
        vibrato: Option[uint8]
        vibratoDelay: Option[uint8]
        tune: Option[uint8]

    SequenceInput = array[SequenceKind, Option[uint8]]
        ## Input data to pass to TrackControl and FrequencyControl from
        ## enumerated sequences

    InstrumentRuntime = object
        ## Enumerates all sequences in an instrument
        instrument: Immutable[ref Instrument]
        sequenceCounters: array[SequenceKind, int]

    FrequencyLookupFunc = proc(note: Natural): uint16

    FrequencyBounds = object
        maxFrequency: uint16
        maxNote: uint8
        lookupFn: FrequencyLookupFunc

    FrequencyControl = object
        ## Handles frequency calculation for a channel
        bounds: FrequencyBounds
        mode: FcMode
        note: uint8
        tune: int8
        frequency: uint16
        # pitch slide
        slideAmount: uint8
        slideTarget: uint16
        instrumentPitch: int16
        # arpeggio
        chordOffset1: uint8
        chordOffset2: uint8
        chordIndex: uint8
        chord: array[0u8..2u8, uint16]
        # vibrato
        vibratoEnabled: bool
        vibratoDelayCounter: uint8
        vibratoCounter: uint8
        vibratoValue: int8
        vibratoDelay: uint8
        vibratoParam: uint8

    NoteAction = enum
        naSustain
        naTrigger
        naCut

    TrackControl = object
        ## Modifies a ChannelState and GlobalState for a given TrackRow
        op: Operation
        ir: InstrumentRuntime
        fc: FrequencyControl
        delayCounter: Option[int]
        cutCounter: Option[int]
        playing: bool
        envelope: uint8
        panning: uint8
        timbre: uint8

    UpdateFlag = enum
        ufTimbre,
        ufEnvelope,
        ufPanning,
        ufFrequency

    UpdateFlags = set[UpdateFlag]

    ChannelState = object
        envelope: uint8
        timbre: range[0u8..3u8]
        panning: range[0u8..3u8]
        frequency: uint16

    GlobalState = object
        patternCommand: PatternCommand
        patternCommandParam: uint8
        panning: array[ChannelId, uint8]
        speed: uint8
        sweep: uint8
        volume: uint8
        halt: bool

    Timer = object
        period, counter: int

    MusicRuntime {.requiresInit.} = object
        song: Immutable[ref Song]
        halted: bool
        orderCounter: int
        rowCounter: int
        patternRepeat: bool
        timer: Timer
        global: GlobalState
        lockflags: uint8
        states: array[ChannelId, ChannelState]
        trackControls: array[ChannelId, TrackControl]

    EngineFrame* = object
        ## Informational data about the current engine frame being stepped.
        ## 
        halted*: bool
        startedNewRow*: bool
        startedNewPattern*: bool
        speed*: uint8
        time*: int
        order*: int
        row*: int

    Engine* = object
        module: Immutable[ref Module]
        musicRuntime: Option[MusicRuntime]

        time: int
        patternRepeat: bool
        frame: EngineFrame

func identityLookup(note: Natural): uint16 = note.uint16

const
    toneFrequencyBounds = FrequencyBounds(
        maxFrequency: 2047,
        maxNote: high(ToneNote).uint8,
        lookupFn: lookupToneNote
    )
    noiseFrequencyBounds = FrequencyBounds(
        maxFrequency: high(NoiseNote).uint8,
        maxNote: high(NoiseNote).uint8,
        lookupFn: identityLookup
    )

    updateAll = {low(UpdateFlag)..high(UpdateFlag)}

func init(T: typedesc[ChannelState], ch: ChannelId): ChannelState =
    result = ChannelState(
        envelope: if ch == ch3: 0xFF else: 0x00,
        timbre: 0,
        panning: 0,
        frequency: 0
    )

func init(T: typedesc[GlobalState]): GlobalState =
    discard

proc setBit[T: SomeInteger](v: var T; bit: BitsRange[T]; val: bool) {.inline.} =
    if val:
        v.setBit(bit)
    else:
        v.clearBit(bit)

proc update(chno: static ChannelId, apu: var ApuIo, uf: UpdateFlags, state: ChannelState, wt: WaveformTable) =
    const chord = chno.ord
    const regaddr = rNR10 + (chord * 5).uint8
    
    if ufTimbre in uf:
        when chno == ch1 or chno == ch2:
            # update timbre (duty)
            apu.writeRegister(regaddr + 1, (state.timbre and 3) shl 6)
        elif chno == ch3:
            # update timbre (wave volume)
            const waveVolumes = [ 0b00000000u8, 0b01100000, 0b01000000, 0b00100000 ]
            apu.writeRegister(regaddr + 2, waveVolumes[state.timbre.int])
        else:
            var nr43 = apu.readRegister(rNR43)
            nr43.setBit(4, state.timbre > 0)
            apu.writeRegister(rNR43, nr43)
    
    if ufPanning in uf:
        const panningMask = 0x11u8 shl chord
        const panningTable = [0x00u8 shl chord, 0x01u8 shl chord, 0x10u8 shl chord, 0x11u8 shl chord]
        var nr51 = apu.readRegister(rNR51)
        nr51 = nr51 and (not panningMask)
        nr51 = nr51 or panningTable[state.panning.int]
        apu.writeRegister(rNR51, nr51)

    var retrigger = none(uint8)

    if ufFrequency in uf:
        when chno == ch4:
            var nr43 = lookupNoiseNote(state.frequency)
            nr43.setBit(4, state.timbre > 0)
            apu.writeRegister(rNR43, nr43)
        else:
            apu.writeRegister(regaddr + 3, (state.frequency and 0xFF).uint8)
            retrigger = some((state.frequency shr 8).uint8 and 0x7)

    proc updateRetrigger() =
        if retrigger.isSome():
            # enable retrigger
            retrigger.get().setBit(7)
        else:
            # enable retrigger, include frequency MSB
            retrigger = some(((state.frequency shr 8).uint8 and 0x7) or 0x80)

    if ufEnvelope in uf:
        when chno == ch3:
            if state.envelope == 0xFF:
                # note cut, turn DAC off
                apu.writeRegister(rNR30, 0xFF)
            else:
                let waveform = wt[state.envelope]
                if waveform != nil:
                    apu.writeRegister(rNR30, 0x00)
                    var waveramAddr = rWAVERAM
                    for samples in waveform[].data:
                        apu.writeRegister(waveramAddr, samples)
                        inc waveramAddr
                    apu.writeRegister(rNR30, 0x80)
                    updateRetrigger()
        else:
            apu.writeRegister(regaddr + 2, state.envelope)
            when chno == ch4:
                retrigger = some(0x80u8)
            else:
                updateRetrigger()

    if retrigger.isSome():
        apu.writeRegister(regaddr + 4, retrigger.get())

proc clearChannel(chno: static ChannelId, apu: var ApuIo) =
    const regstart = rNR10 + (chno.ord * 5).uint8
    const regend = when chno == ch3: regstart + 4 else: regstart + 3
    for regaddr in regstart..regend:
        apu.writeRegister(regaddr, 0x00)
    when chno != ch3:
        apu.writeRegister(regstart + 4, 0x80)

func init(T: typedesc[Timer], speed: Speed): Timer =
    result = Timer(
        period: speed.int,
        counter: 0
    )

func active(t: Timer): bool =
    t.counter < unitSpeed

proc setPeriod(t: var Timer, speed: Speed) =
    t.period = clamp(speed, low(Speed), high(Speed)).int
    # if the counter exceeds the new period, clamp it to 1 unit less
    # this way, the timer will overflow on the next call to step
    t.counter = min(t.counter, t.period - unitSpeed)

proc step(t: var Timer): bool =
    t.counter += unitSpeed
    result = t.counter >= t.period
    if result:
        # timer overflow
        t.counter -= t.period

converter toOperation(row: TrackRow): Operation =
    # note column
    result.note = row.queryNote()
    if result.note.isSome() and result.note.get() == noteCut:
        # noteCut behaves exactly the same as effect S00
        result.note = none[uint8]()
        result.duration = some(0u8)

    # instrument column
    result.instrument = row.queryInstrument()
    
    # effects
    for effect in row.effects:
        case effect.effectType:
        of etPatternGoto.uint8:
            result.patternCommand = pcJump
            result.patternCommandParam = effect.param
        of etPatternHalt.uint8:
            result.halt = true
        of etPatternSkip.uint8:
            result.patternCommand = pcNext
            result.patternCommandParam = effect.param
        of etSetTempo.uint8:
            if effect.param >= low(Speed) and effect.param <= high(Speed):
                result.speed = effect.param
        of etSfx.uint8:
            discard  # TBD
        of etSetEnvelope.uint8:
            result.envelope = some(effect.param)
        of etSetTimbre.uint8:
            result.timbre = some(clamp(effect.param, 0, 3))
        of etSetPanning.uint8:
            result.panning = some(clamp(effect.param, 0, 3))
        of etSetSweep.uint8:
            result.sweep = some(effect.param)
        of etDelayedCut.uint8:
            result.duration = some(effect.param)
        of etDelayedNote.uint8:
            result.delay = effect.param
        of etLock.uint8:
            discard  # TBD
        of etArpeggio.uint8:
            result.freqMod = freqArpeggio
            result.freqModParam = effect.param
        of etPitchUp.uint8:
            result.freqMod = freqPitchUp
            result.freqModParam = effect.param
        of etPitchDown.uint8:
            result.freqMod = freqPitchDown
            result.freqModParam = effect.param
        of etAutoPortamento.uint8:
            result.freqMod = freqPortamento
            result.freqModParam = effect.param
        of etVibrato.uint8:
            result.vibrato = some(effect.param)
        of etVibratoDelay.uint8:
            result.vibratoDelay = some(effect.param)
        of etTuning.uint8:
            result.tune = some(effect.param)
        of etNoteSlideUp.uint8:
            result.freqMod = freqNoteUp
            result.freqModParam = effect.param
        of etNoteSlideDown.uint8:
            result.freqMod = freqNoteDown
            result.freqModParam = effect.param
        of etSetGlobalVolume.uint8:
            if effect.param < 0x80:
                result.volume = effect.param or 0x80
        else:
            discard  # ignore any unknown effect


converter toOperation(note: uint8): Operation =
    if note == noteCut:
        result.duration = some(1u8)
    else:
        result.note = some(note)

func init(T: typedesc[FrequencyControl], bounds: FrequencyBounds): FrequencyControl =
    result.bounds = bounds

proc apply(fc: var FrequencyControl, op: Operation) =
    var updateChord = false
    if op.note.isSome():
        if fc.mode == fcmNoteSlide:
            # setting a new note cancels a slide
            fc.mode = fcmNone
        fc.note = min(op.note.get(), fc.bounds.maxNote)

    case op.freqMod:
    of freqArpeggio:
        if op.freqModParam == 0:
            fc.mode = fcmNone
        else:
            fc.mode = fcmArpeggio
            fc.chordOffset1 = op.freqModParam shr 4
            fc.chordOffset2 = op.freqModParam and 0xF
            updateChord = true
    of freqPitchUp, freqPitchDown:
        if op.freqModParam == 0:
            fc.mode = fcmNone
        else:
            fc.mode = fcmPitchSlide
            if op.freqMod == freqPitchUp:
                fc.slideTarget = fc.bounds.maxFrequency
            else:
                fc.slideTarget = 0
            fc.slideAmount = op.freqModParam
    of freqNoteUp, freqNoteDown:
        fc.slideAmount = 1 + (2 * (op.freqModParam and 0xF))
        # upper 4 bits is the # of semitones to slide to
        let semitones = op.freqModParam shr 4
        let targetNote = block:
            if op.freqMod == freqNoteUp:
                min(fc.note + semitones, fc.bounds.maxNote)
            else:
                if fc.note < semitones:
                    0u8
                else:
                    fc.note - semitones
        fc.mode = fcmNoteSlide
        fc.slideTarget = fc.bounds.lookupFn(targetNote)
        fc.note = targetNote
    of freqPortamento:
        if op.freqModParam == 0:
            fc.mode = fcmNone
        else:
            if fc.mode != fcmPortamento:
                fc.slideTarget = fc.frequency
                fc.mode = fcmPortamento
            fc.slideAmount = op.freqModParam
    else:
        discard

    if op.vibrato.isSome():
        fc.vibratoParam = op.vibrato.get()
        let extent = (fc.vibratoParam and 0xF).int8
        if extent == 0:
            # extent is 0, disable vibrato
            fc.vibratoEnabled = false
            fc.vibratoValue = 0
        else:
            # extent is nonzero, set vibrato
            fc.vibratoEnabled = true
            if fc.vibratoValue < 0:
                fc.vibratoValue = -extent
            else:
                fc.vibratoValue = extent

    if op.vibratoDelay.isSome():
        fc.vibratoDelay = op.vibratoDelay.get()

    if op.tune.isSome():
        # tune values have a bias of 0x80, so 0x80 is 0, is in tune
        # 0x81 is +1, frequency is pitch adjusted by 1
        # 0x7F is -1, frequency is pitch adjusted by -1
        fc.tune = (op.tune.get() - 0x80).int8

    if op.note.isSome():
        let freq = fc.bounds.lookupFn(op.note.get())
        if fc.mode == fcmPortamento:
            # automatic portamento, slide to this note
            fc.slideTarget = freq
        else:
            # otherwise, set the current frequency
            if fc.mode == fcmArpeggio:
                updateChord = true
            fc.frequency = freq

        if fc.vibratoEnabled:
            fc.vibratoDelayCounter = fc.vibratoDelay
            fc.vibratoCounter = 0
            fc.vibratoValue = (fc.vibratoParam and 0xF).int8
        fc.instrumentPitch = 0

    if updateChord:
        # first note in the chord is always the current note
        fc.chord[0] = fc.bounds.lookupFn(fc.note);
        # second note is the upper nibble + the current (clamped to the last possible note)
        fc.chord[1] = fc.bounds.lookupFn(min(fc.note + fc.chordOffset1, fc.bounds.maxNote));
        # third note is the lower nibble + current (also clamped)
        fc.chord[2] = fc.bounds.lookupFn(min(fc.note + fc.chordOffset2, fc.bounds.maxNote));

proc finishSlide(fc: var FrequencyControl) =
    fc.frequency = fc.slideTarget
    if fc.mode == fcmNoteSlide:
        # stop sliding once target note is reached
        fc.mode = fcmNone

proc step(fc: var FrequencyControl, arpIn, pitchIn: Option[uint8]): uint16 =
    if fc.vibratoEnabled:
        if fc.vibratoDelayCounter > 0:
            dec fc.vibratoDelayCounter
        else:
            if fc.vibratoCounter == 0:
                fc.vibratoValue = -fc.vibratoValue
                fc.vibratoCounter = fc.vibratoParam shr 4
            else:
                dec fc.vibratoCounter

    if pitchIn.isSome():
        fc.instrumentPitch += pitchIn.get().int8

    if arpIn.isSome():
        fc.frequency = fc.bounds.lookupFn(clamp(fc.note.int + arpIn.get().int, 0, fc.bounds.maxNote.int).uint8)
    else:
        # frequency modulation
        case fc.mode:
        of fcmPortamento, fcmPitchSlide, fcmNoteSlide:

            if fc.frequency != fc.slideTarget:
                if fc.frequency < fc.slideTarget:
                    # sliding up
                    fc.frequency += fc.slideAmount
                    if fc.frequency > fc.slideTarget:
                        fc.finishSlide()
                else:
                    # sliding down
                    fc.frequency -= fc.slideAmount
                    if fc.frequency < fc.slideTarget:
                        fc.finishSlide()
        of fcmArpeggio:
            fc.frequency = fc.chord[fc.chordIndex]
            inc fc.chordIndex
            if fc.chordIndex > high(fc.chord):
                fc.chordIndex = 0
        else:
            discard

    var calcfreq = fc.frequency.int + fc.tune.int + fc.instrumentPitch.int
    if fc.vibratoEnabled and fc.vibratoDelayCounter == 0:
        calcfreq += fc.vibratoValue.int
    result = clamp(calcfreq, 0, fc.bounds.maxFrequency.int).uint16

proc reset(r: var InstrumentRuntime) =
    r.sequenceCounters = default(r.sequenceCounters.type)

proc setInstrument(r: var InstrumentRuntime, i: sink Immutable[ref Instrument]) =
    r.instrument = i
    r.reset()

proc step(r: var InstrumentRuntime): SequenceInput =
    proc next(s: Sequence, index: var int): Option[uint8] =
        let seqlen = s.data.len
        if index >= seqlen:
            if seqlen != 0 and s.loopIndex.isSome():
                # loop to the loop index
                index = s.loopIndex.get()
            else:
                # at end of sequence, return none
                return
        # get the value at the current index
        result = some(s.data[index])
        inc index

    if r.instrument != nil:
        for kind, sequence in r.instrument[].sequences.pairs:
            result[kind] = next(sequence, r.sequenceCounters[kind])



func init(T: typedesc[TrackControl], ch: ChannelId): TrackControl =
    result = TrackControl(
        op: default(Operation),
        fc: FrequencyControl.init(if ch == ch4: noiseFrequencyBounds else: toneFrequencyBounds),
        envelope: if ch == ch3: 0 else: 0xF0,
        timbre: 3,
        panning: 3
    )

proc setRow(tc: var TrackControl, row: TrackRow) =
    if row == default(TrackRow):
        # empty row, do nothing
        return

    # convert the row to an operation
    tc.op = row
    tc.delayCounter = some(tc.op.delay.int)

proc step(tc: var TrackControl, itable: InstrumentTable, state: var ChannelState, global: var GlobalState): NoteAction =
    result = naSustain

    if tc.delayCounter.isSome():
        if tc.delayCounter.get() == 0:
            # apply the operation

            # global effects
            if tc.op.patternCommand != pcNone:
                global.patternCommand = tc.op.patternCommand
                global.patternCommandParam = tc.op.patternCommandParam

            if tc.op.speed != 0:
                global.speed = tc.op.speed
            if tc.op.halt:
                global.halt = true
            if tc.op.volume >= 0x80:
                global.volume = tc.op.volume

            # instrument column
            if tc.op.instrument.isSome():
                let instrument = itable[tc.op.instrument.get()]
                if instrument != nil:
                    tc.ir.setInstrument(instrument)

            template updateSetting(setting: untyped): untyped =
                if tc.op.setting.isSome():
                    tc.setting = tc.op.setting.get()
                    state.setting = tc.setting

            updateSetting(envelope)
            updateSetting(panning)
            updateSetting(timbre)

            if tc.op.sweep.isSome():
                global.sweep = tc.op.sweep.get() or 0x80

            # note column
            if tc.op.note.isSome():
                tc.ir.reset()
                tc.playing = true
                if tc.ir.instrument != nil and tc.ir.instrument[].initEnvelope:
                    state.envelope = tc.ir.instrument[].envelope
                else:
                    state.envelope = tc.envelope
                state.panning = tc.panning
                state.timbre = tc.timbre
                result = naTrigger
                tc.cutCounter = none(int)

            tc.fc.apply(tc.op)
            tc.delayCounter = none(int)
        else:
            dec tc.delayCounter.get()
    
    if tc.playing:
        if tc.cutCounter.isSome():
            if tc.cutCounter.get() == 0:
                tc.playing = false
                tc.cutCounter = none(int)
                result = naCut
            else:
                dec tc.cutCounter.get()
        
        let inputs = tc.ir.step()

        # Frequency calculation
        state.frequency = tc.fc.step(inputs[skArp], inputs[skPitch])
        
        template readInput(dest: var uint8, kind: SequenceKind): untyped =
            if inputs[kind].isSome():
                dest = inputs[kind].get()

        readInput(state.panning, skPanning)
        readInput(state.timbre, skTimbre)

func init(T: typedesc[MusicRuntime], song: sink Immutable[ref Song], orderNo, rowNo: int, patternRepeat: bool): MusicRuntime =
    result = MusicRuntime(
        song: song,
        halted: false,
        orderCounter: orderNo,
        rowCounter: rowNo,
        patternRepeat: patternRepeat,
        timer: Timer.init(song[].speed),
        global: GlobalState.init(),
        lockflags: 0,
        states: [
            ChannelState.init(ch1),
            ChannelState.init(ch2),
            ChannelState.init(ch3),
            ChannelState.init(ch4)
        ],
        trackControls: [
            TrackControl.init(ch1),
            TrackControl.init(ch2),
            TrackControl.init(ch3),
            TrackControl.init(ch4)
        ]
    )

# prestep and poststep are separate procs, to reduce code duplication

proc prestep(r: var MusicRuntime, frame: var EngineFrame): bool =
    # we are starting a new row if the timer is active
    frame.startedNewRow = r.timer.active()
    # this gets set to true if:
    #  1. we have started a new row
    #  2. a pattern command was set (jump or next)
    frame.startedNewPattern = false
    if frame.startedNewRow:
        # change the current pattern if needed
        if r.global.patternCommand != pcNone and r.patternRepeat:
            r.global.patternCommand = pcNone
            r.rowCounter = 0
        else:
            case r.global.patternCommand:
            of pcNone:
                discard
            of pcNext:
                inc r.orderCounter
                if r.orderCounter >= r.song[].order.len:
                    # loop back to the first pattern
                    r.orderCounter = 0
                r.rowCounter = r.global.patternCommandParam.int
                r.global.patternCommand = pcNone
                frame.startedNewPattern = true
            of pcJump:
                r.rowCounter = 0
                # if the parameter goes past the last one, use the last one
                r.orderCounter = min(r.global.patternCommandParam.int, r.song[].order.len - 1)
                r.global.patternCommand = pcNone
                frame.startedNewPattern = true
        
        # set current track row to the track controls
        for chno in low(ChannelId)..high(ChannelId):
            r.trackControls[chno].setRow(r.song[].getRow(chno, r.orderCounter, r.rowCounter))
        
        if r.global.halt:
            
            return true

        frame.row = r.rowCounter
        frame.order = r.orderCounter

proc poststep(r: var MusicRuntime, frame: var EngineFrame) =
    # change speed if the Fxx effect was used
    if r.global.speed > 0:
        r.timer.setPeriod(r.global.speed)
        r.global.speed = 0
    frame.speed = r.timer.period.Speed

    if r.timer.step():
        # timer overflow, advance row counter
        inc r.rowCounter
        if r.rowCounter >= r.song[].trackLen():
            # end of pattern
            if r.global.patternCommand == pcNone:
                # go to the next pattern in the order
                with r.global:
                    patternCommand = pcNext
                    patternCommandParam = 0

proc haltAll(r: var MusicRuntime, apu: var ApuIo) =
    
    template haltChannel(chno: static ChannelId) =
        if not r.lockflags.testBit(chno.ord):
            clearChannel(chno, apu)
        r.states[chno] = default(ChannelState)

    haltChannel(ch1)
    haltChannel(ch2)
    haltChannel(ch3)
    haltChannel(ch4)

proc halt(r: var MusicRuntime, apu: var ApuIo) =
    r.halted = true
    r.haltAll(apu)

proc jump(r: var MusicRuntime, pattern: Natural) =
    r.orderCounter = pattern
    r.rowCounter = 0

proc lock(r: var MusicRuntime, chno: ChannelId) =
    discard

func difference(state, prev: ChannelState): UpdateFlags =
    template check(flag: UpdateFlag, param: untyped): untyped =
        if state.param != prev.param:
            result.incl(flag)
    check(ufEnvelope, envelope)
    check(ufTimbre, timbre)
    check(ufPanning, panning)
    check(ufFrequency, frequency)

proc step(r: var MusicRuntime, apu: var ApuIo, itable: InstrumentTable, wtable: WaveformTable, frame: var EngineFrame): bool =
    if r.halted:
        return true

    if r.prestep(frame):
        r.haltAll(apu)
        return true

    template impl(chno: static ChannelId) =
        const sweepChannel = chno == ch1
    
        var state = r.states[chno]
        let prev = state
        
        # step the channel's track control
        let action = r.trackControls[chno].step(itable, state, r.global)

        if not r.lockflags.testBit(chno.ord):
            # only write to registers if the channel is locked
            
            var flags = difference(state, prev)
            when sweepChannel:
                # check if the sweep effect was used
                if r.global.sweep >= 0x80:
                    apu.writeRegister(rNR10, r.global.sweep and 0x7F)
                    flags.incl(ufEnvelope)

            # Cuts and note triggers modify the envelope
            when chno == ch3:
                if action == naCut:
                    # when envelope is 0xFF on CH3, only the DAC will be disabled
                    state.envelope = 0xFF
                    flags.incl(ufEnvelope)
            else:
                case action:
                of naTrigger:
                    # always reload envelope register on note trigger
                    flags.incl(ufEnvelope)
                of naCut:
                    state.envelope = 0x00
                    flags.incl(ufEnvelope)
                else:
                    discard

            update(chno, apu, flags, state, wtable)

            when sweepChannel:
                if r.global.sweep >= 0x80:
                    # immediately clear the sweep register after retrigger
                    apu.writeRegister(rNR10, 0x00)
                    r.global.sweep = 0

        r.states[chno] = state

    impl(ch1)
    impl(ch2)
    impl(ch3)
    impl(ch4)

    if r.global.volume >= 0x80:
        apu.writeRegister(rNR50, r.global.volume and 0x77)
        r.global.volume = 0

    r.poststep(frame)
    result = false

func init*(T: typedesc[Engine]): Engine =
    discard  # default init is sufficient

proc module*(e: Engine): Immutable[ref Module] =
    result = e.module

proc `module=`*(e: var Engine, module: sink Immutable[ref Module]) =
    if e.module != module:
        e.module = module
        e.musicRuntime = none(MusicRuntime)

proc lock*(e: var Engine, chno: ChannelId) =
    discard

proc unlock*(e: var Engine, chno: ChannelId) =
    discard

proc halt*(e: var Engine, apu: var ApuIo) =
    if e.musicRuntime.isSome():
        e.musicRuntime.get().halt(apu)

proc reset*(e: var Engine) =
    e.musicRuntime = none(MusicRuntime)

proc setup*(e: var Engine, apu: var ApuIo) =
    apu.writeRegister(rNR52, 0x80)
    apu.writeRegister(rNR50, 0x77)
    # clear all locked channels
    let lockflags = if e.musicRuntime.isSome(): e.musicRuntime.get().lockflags else: 0
    template clearIfLocked(chno: ChannelId) =
        if lockflags.testBit(chno): clearChannel(chno, apu)
    clearIfLocked(0)
    clearIfLocked(1)
    clearIfLocked(2)
    clearIfLocked(3)

proc play*(e: var Engine, song, pattern, row: Natural = 0) =
    if e.module == nil:
        raise newException(InvalidOperationDefect, "cannot play: module not set")
    
    if song >= e.module[].songs.len():
        raise newException(IndexDefect, "invalid song index")
    
    let songref = e.module[].songs[song]
    if pattern >= songref[].order.len():
        raise newException(IndexDefect, "invalid pattern index")
    if row >= songref[].trackLen():
        raise newException(IndexDefect, "invalid row index")

    e.musicRuntime = some(MusicRuntime.init(songref, pattern, row, e.patternRepeat))
    e.time = 0

proc step*(e: var Engine, apu: var ApuIo) =
    if e.musicRuntime.isSome():
        e.frame.time = e.time
        e.frame.halted = e.musicRuntime.get().step(apu, e.module[].instruments, e.module[].waveforms, e.frame)

        if not e.frame.halted:
            inc e.time
    else:
        e.frame.halted = true

func currentFrame*(e: Engine): EngineFrame =
    result = e.frame

func currentSong*(e: Engine): Immutable[ref Song] =
    if e.musicRuntime.isSome():
        result = e.musicRuntime.get().song

# diagnostic functions

func currentState*(e: Engine, chno: ChannelId): ChannelState =
    if e.musicRuntime.isSome():
        result = e.musicRuntime.get().states[chno]

func currentNote*(e: Engine, chno: ChannelId): int =
    if e.musicRuntime.isSome():
        result = e.musicRuntime.get().trackControls[chno].fc.note.int
