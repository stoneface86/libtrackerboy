{.used.}

import trackerboy/private/endian
import std/unittest

const testData = (
    [0x1234'u16,             0x3412'u16],
    [0x12345678'u32,         0x78563412'u32],
    [0xDEADCAFEBABEBEEF'u64, 0xEFBEBEBAFECAADDE'u64]
)

suite "endian":

    when cpuEndian == littleEndian:
        test "cpuEndian is littleEndian":
            discard
    else:
        test "cpuEndian is bigEndian":
            discard

    test "involution":
        # endian conversion has an involutory property
        # converting a value to LE, then converting that to NE should result
        # in the original value.
        for val in testData.fields:
            check val[0].toLE.toNE == val[0]

    test "toLE/toNE":
        for val in testData.fields:
            when cpuEndian == littleEndian:
                let input = val[0]
                check cast[input.type](input.toLE) == input
            else:
                let input = val[0]
                let output = val[1]
                check cast[input.type](input.toLE) == output
