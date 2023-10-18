##[

.. include:: warning.rst

]##

import enginestate, hardware
import ../common, ../data, ../notes

import std/[bitops, options]

type
  ApuWrite* = tuple[regaddr, value: uint8]

  # Fixed size array is used instead of a seq for performance reasons
  ApuWriteList* = object
    data*: array[64, ApuWrite]
    len*: int

  PanningAccum = object
    val: uint8
    mask: uint8

  RetriggerByte = object
    shouldRender: bool
    retrigger: bool
    frequency: uint16

proc add*(l: var ApuWriteList; regaddr, value: uint8;) =
  l.data[l.len] = (regaddr, value)
  inc l.len

iterator items*(l: ApuWriteList): ApuWrite =
  for i in 0..<l.len:
    yield l.data[i]

proc setRetrigger(b: var RetriggerByte) =
  b.shouldRender = true
  b.retrigger = true

func render(b: RetriggerByte): uint8 =
  if b.retrigger:
    result = 0x80
  result = result or ((b.frequency shr 8).uint8 and 0x7)

proc accumulate(accum: var PanningAccum; panning: uint8;
                chno: static ChannelId) =
  func makePanningTable(): auto =
    result = [0x00u8, 0x10, 0x01, 0x11]
    for item in result.mitems:
      item = item shl chno.ord
  const panningTable = makePanningTable()

  accum.val = accum.val or panningTable[panning]
  accum.mask = accum.mask or (0x11u8 shl chno.ord)

func update(accum: PanningAccum; nr51: uint8): uint8 =
  (nr51 and (not accum.mask)) or accum.val

proc clearChannel*(chno: ChannelId; writes: var ApuWriteList) =
  let regstart = rNR10 + (chno.ord * 5).uint8
  for regaddr in regstart..regstart+4:
    writes.add(regaddr, 0x00)

func getRegAddr(chno: ChannelId): uint8 {.compileTime.} =
  rNR10 + (chno.ord * 5).uint8

const dutyTable = [
  0b00000000u8,   # V00 - 12.5%
  0b01000000,     # V01 - 25.0%
  0b10000000,     # V02 - 50.0%
  0b11000000      # V03 - 75.0% (default)
]
const waveVolumes = [ 
  0b00000000u8,   # V00 - mute
  0b01100000,     # V01 - 25% volume
  0b01000000,     # V02 - 50% volume
  0b00100000      # V03 - 100% volume (default)
]

proc getChannelWrites(chno: static ChannelId; wt: WaveformTable;
                      update: ChannelUpdate; panningAccum: var PanningAccum;
                      list: var ApuWriteList) =
  case update.action:
  of caNone:
    discard
  of caUpdate:
    if update.trigger or ufPanning in update.flags:
      panningAccum.accumulate(update.state.panning, chno)
    
    var nrx4: RetriggerByte
    when chno != ch4:
      nrx4.frequency = update.state.frequency

    when chno == ch3:
      if ufEnvelope in update.flags:
        let waveform = wt[update.state.envelope.uint8]
        if waveform != nil:
          list.add(rNR30, 0x00) # DAC off
          var waveramAddr = rWAVERAM
          for samples in waveform[].data:
            list.add(waveramAddr, samples)
            inc waveramAddr
          list.add(rNR30, 0x80) # DAC on
          nrx4.setRetrigger()
    else:
      if update.trigger or ufEnvelope in update.flags:
        list.add(getRegAddr(chno) + 2, update.state.envelope.uint8)
        nrx4.setRetrigger()

    when chno == ch4:
      if ufTimbre in update.flags or ufFrequency in update.flags:
        var nr43 = lookupNoiseNote(update.state.frequency)
        if update.state.timbre > 0:
          nr43.setBit(3)
        list.add(rNR43, nr43)
    else:
      if ufTimbre in update.flags:
        when chno == ch3:
          # update timbre (wave volume)
          list.add(rNR32, waveVolumes[update.state.timbre.int])
        else:
          list.add(getRegAddr(chno) + 1, dutyTable[update.state.timbre.int])
      if ufFrequency in update.flags:
        list.add(getRegAddr(chno) + 3, (update.state.frequency and 0xFF).uint8)
        nrx4.shouldRender = true
    
    if nrx4.shouldRender:
      list.add(getRegAddr(chno) + 4, nrx4.render())
  of caCut:
    panningAccum.accumulate(0, chno)
  of caShutdown:
    panningAccum.accumulate(0, chno)
    clearChannel(chno, list)

func getWrites*(op: ApuOperation, wt: WaveformTable, nr51: uint8
               ): ApuWriteList =
  var panningAccum: PanningAccum

  if op.sweep.isSome():
    result.add(rNR10, op.sweep.get() and 0x7F)

  ch1.getChannelWrites(wt, op.updates[ch1], panningAccum, result)

  if op.sweep.isSome():
    result.add(rNR10, 0x00)

  ch2.getChannelWrites(wt, op.updates[ch2], panningAccum, result)
  ch3.getChannelWrites(wt, op.updates[ch3], panningAccum, result)
  ch4.getChannelWrites(wt, op.updates[ch4], panningAccum, result)

  if op.volume.isSome():
    result.add(rNR50, op.volume.get() and 0x77)

  let newNr51 = panningAccum.update(nr51)
  if newNr51 != nr51:
    result.add(rNR51, newNr51)
