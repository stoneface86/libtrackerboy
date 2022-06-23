
import trackerboy/data
import ../testing

testclass "WaveData"

const
    zero = default(WaveData)
    zeroStr = "00000000000000000000000000000000"
    triangle: WaveData = [0x01u8, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
                            0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10]
    triangleStr = "0123456789ABCDEFFEDCBA9876543210"


dtest "$WaveData":
    check:
        $zero == zeroStr
        $triangle == triangleStr

dtest "parseWave":
    check:
        zeroStr.parseWave == zero
        triangleStr.parseWave == triangle
        # partial waveform
        "11223344".parseWave == [0x11u8, 0x22, 0x33, 0x44, 0, 0, 0, 0, 
                                    0, 0, 0, 0, 0, 0, 0, 0]
        # invalid string
        "11@3sfji2maks;w".parseWave == [0x11u8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
