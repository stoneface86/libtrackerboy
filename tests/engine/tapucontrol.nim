
import trackerboy/private/[enginestate, apucontrol, hardware]
import trackerboy/[data, notes]
import utils
import ../testing

import std/strformat

testclass "apucontrol"

func `$`(aw: ApuWrite): string =
    &"${aw.regaddr:02X} <- ${aw.value:02X}"

func `$`(list: ApuWriteList): string =
    result.add('[')
    if list.len >= 1:
        for i in 0..<list.len-1:
            result.add($list.data[i])
            result.add(", ")
        result.add($list.data[list.len-1])
    result.add(']')

func aw(reg, val: uint8): ApuWrite = (reg, val)

func `^`[Idx](data: sink array[Idx, ApuWrite]): ApuWriteList =
    when Idx.high - Idx.low > ApuWriteList.data.len:
        {.error: "Cannot make a ApuWriteList from the given array".}
    for i, item in data.pairs:
        result.data[i] = item
    result.len = data.len

func `==`(a, b: ApuWriteList): bool =
    if a.len != b.len:
        return false
    for i in 0..<a.len:
        if a.data[i] != b.data[i]:
            return false
    result = true

dtest "ApuWriteList":
    var list: ApuWriteList
    list.add(0, 1)
    list.add(1, 2)
    list.add(0, 0)

    check list == ^[aw(0, 1), aw(1, 2), aw(0, 0)]


dtest "empty operation results in no writes":
    let wt = WaveformTable.init
    check getWrites(ApuOperation(), wt, 0x00u8).len == 0

dtest "update timbre":
    let wt = WaveformTable.init
    
    func timbreTest(timbre: uint8, wt: WaveformTable): ApuWriteList =
        let op = mkOperation(
            mkUpdates(
                mkUpdate(mkState(t = timbre), {ufTimbre}),
                mkUpdate(mkState(t = timbre), {ufTimbre}),
                mkUpdate(mkState(t = timbre), {ufTimbre}),
                mkUpdate(mkState(t = timbre), {ufTimbre})
            )
        )
        getWrites(op, wt, 0)

    check timbreTest(0, wt) == ^[
        aw(rNR11, 0x00),
        aw(rNR21, 0x00),
        aw(rNR32, 0x00),
        aw(rNR43, lookupNoiseNote(0))
    ]
    check timbreTest(1, wt) == ^[
        aw(rNR11, 0x40),
        aw(rNR21, 0x40),
        aw(rNR32, 0x60),
        aw(rNR43, lookupNoiseNote(0) or 0x8)
    ]
    check timbreTest(2, wt) == ^[
        aw(rNR11, 0x80),
        aw(rNR21, 0x80),
        aw(rNR32, 0x40),
        aw(rNR43, lookupNoiseNote(0) or 0x8)
    ]
    check timbreTest(3, wt) == ^[
        aw(rNR11, 0xC0),
        aw(rNR21, 0xC0),
        aw(rNR32, 0x20),
        aw(rNR43, lookupNoiseNote(0) or 0x8)
    ]

dtest "cuts":
    let wt = WaveformTable.init
    let op = mkOperation(
        mkUpdates(mkCut(), mkCut(), mkCut(), mkCut())
    )
    check getWrites(op, wt, 0xFF) == ^[
        aw(rNR51, 0x00)
    ]

dtest "panning":
    # ch1 and ch4 will update the panning
    # ch2 and ch3 panning should be untouched
    let wt = WaveformTable.init
    let op = mkOperation(
        mkUpdates(
            up1 = mkUpdate(mkState(p = 2), {ufPanning}),
            up4 = mkUpdate(mkState(p = 3), {ufPanning})
        )
    )
    check getWrites(op, wt, 0b0000_0000) == ^[aw(rNR51, 0b1000_1001)]
    check getWrites(op, wt, 0b0110_0110) == ^[aw(rNR51, 0b1110_1111)]
    # no change in panning results in no write to nr51 being added
    check getWrites(op, wt, 0b10001001).len == 0

dtest "trigger":
    let wt = WaveformTable.init
    let op = mkOperation(
        mkUpdates(
            mkUpdate(mkState(e = 0xF0, p = 3), t = true),
            mkUpdate(mkState(e = 0xF1, f = 0x3DE, p = 3), t = true),
            mkUpdate(mkState(p = 3), t = true),
            mkUpdate(mkState(e = 0xA3, p = 3), t = true)
        )
    )
    check getWrites(op, wt, 0) == ^[
        aw(rNR12, 0xF0),
        aw(rNR14, 0x80),
        aw(rNR22, 0xF1),
        aw(rNR24, 0x83), # Note that the 3 comes from the MSB of frequency
        aw(rNR42, 0xA3),
        aw(rNR44, 0x80),
        aw(rNR51, 0xFF)
    ]

dtest "envelope":
    let wt = getSampleTable()
    var op = mkOperation(
        mkUpdates(
            up2 = mkUpdate(mkState(e = 0xD4), {ufEnvelope}),
            up3 = mkUpdate(mkState(e = 0x00), {ufEnvelope})
        )
    )
    check getWrites(op, wt, 0) == ^[
        aw(rNR22, 0xD4),
        aw(rNR24, 0x80),
        aw(rNR30, 0x00),
        aw(rWAVERAM, 0x01),
        aw(rWAVERAM+1, 0x23),
        aw(rWAVERAM+2, 0x45),
        aw(rWAVERAM+3, 0x67),
        aw(rWAVERAM+4, 0x89),
        aw(rWAVERAM+5, 0xAB),
        aw(rWAVERAM+6, 0xCD),
        aw(rWAVERAM+7, 0xEF),
        aw(rWAVERAM+8, 0xFE),
        aw(rWAVERAM+9, 0xDC),
        aw(rWAVERAM+10, 0xBA),
        aw(rWAVERAM+11, 0x98),
        aw(rWAVERAM+12, 0x76),
        aw(rWAVERAM+13, 0x54),
        aw(rWAVERAM+14, 0x32),
        aw(rWAVERAM+15, 0x10),
        aw(rNR30, 0x80),
        aw(rNR34, 0x80)
    ]
    # no waveform with the id, no writes
    op = mkOperation(mkUpdates(up3 = mkUpdate(mkState(e = 3), {ufEnvelope})))
    check getWrites(op, wt, 0).len == 0

dtest "frequency":
    let wt = WaveformTable.init
    let op = mkOperation(
        mkUpdates(
            up2 = mkUpdate(ChannelState(frequency: 0x1D9, envelope: 0x77), {ufFrequency, ufEnvelope}),
            up3 = mkUpdate(ChannelState(frequency: 0x7FF), {ufFrequency}),
            up4 = mkUpdate(ChannelState(frequency: 20), {ufFrequency})
        )
    )
    check getWrites(op, wt, 0) == ^[
        aw(rNR22, 0x77),
        aw(rNR23, 0xD9),
        aw(rNR24, 0x81),
        aw(rNR33, 0xFF),
        aw(rNR34, 0x07),
        aw(rNR43, lookupNoiseNote(20))
    ]

dtest "sweep":
    let wt = WaveformTable.init
    let op = mkOperation(
        mkUpdates(
            up1 = mkUpdate(mkState(e = 0xF0), t = true)
        ),
        some(0x77u8)
    )
    check getWrites(op, wt, 0) == ^[
        aw(rNR10, 0x77),
        aw(rNR12, 0xF0),
        aw(rNR14, 0x80),
        aw(rNR10, 0x00)
    ]

dtest "volume":
    let wt = WaveformTable.init
    let op = mkOperation(
        mkUpdates(),
        v = some(0x43u8)
    )
    check getWrites(op, wt, 0) == ^[aw(rNR50, 0x43)]

dtest "stress test":
    # this should be the maximum number of writes possible from an ApuOperation
    # to make sure getWrites() never exceeds the capacity of an ApuWriteList
    let wt = getSampleTable()
    let op = mkOperation(
        mkUpdates(
            mkShutdown(),   # +5 writes
            mkShutdown(),   # +5
            mkUpdate(
                mkState(0x432, 0, 3, 3),
                ufAll
            ),              # 1 + 16 + 1 + 3 = 21
            mkShutdown()    # +5
        ),
        some(0x11u8),       # +2
        some(0x45u8)        # +1
    )
    check getWrites(op, wt, 0) == ^[
        aw(rNR10, 0x11),
        aw(rNR10, 0x00),
        aw(rNR11, 0x00),
        aw(rNR12, 0x00),
        aw(rNR13, 0x00),
        aw(rNR14, 0x00),
        aw(rNR10, 0x00),

        aw(rNR21 - 1, 0x00),
        aw(rNR21, 0x00),
        aw(rNR22, 0x00),
        aw(rNR23, 0x00),
        aw(rNR24, 0x00),

        aw(rNR30, 0x00),
        aw(rWAVERAM, 0x01),
        aw(rWAVERAM+1, 0x23),
        aw(rWAVERAM+2, 0x45),
        aw(rWAVERAM+3, 0x67),
        aw(rWAVERAM+4, 0x89),
        aw(rWAVERAM+5, 0xAB),
        aw(rWAVERAM+6, 0xCD),
        aw(rWAVERAM+7, 0xEF),
        aw(rWAVERAM+8, 0xFE),
        aw(rWAVERAM+9, 0xDC),
        aw(rWAVERAM+10, 0xBA),
        aw(rWAVERAM+11, 0x98),
        aw(rWAVERAM+12, 0x76),
        aw(rWAVERAM+13, 0x54),
        aw(rWAVERAM+14, 0x32),
        aw(rWAVERAM+15, 0x10),
        aw(rNR30, 0x80),
        aw(rNR32, 0x20),
        aw(rNR33, 0x32),
        aw(rNR34, 0x84),

        aw(rNR41 - 1, 0x00),
        aw(rNR41, 0x00),
        aw(rNR42, 0x00),
        aw(rNR43, 0x00),
        aw(rNR44, 0x00),

        aw(rNR50, 0x45),
        aw(rNR51, 0x44)
    ]
