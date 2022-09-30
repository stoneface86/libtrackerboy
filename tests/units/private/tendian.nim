
# the inverse endian tests allow us to mock the endian opposite to the system's
# endian.


import libtrackerboy/private/endian
import ../testing

testunit "private/endian"
testclass ""

const testData = (
    [0x1234'u16,             0x3412'u16],
    [0x12345678'u32,         0x78563412'u32],
    [0xDEADCAFEBABEBEEF'u64, 0xEFBEBEBAFECAADDE'u64]
)

static:
    # test that toLE and toNE can be called statically
    for val in testData.fields:
        assert val[0].toLE.toNE == val[0]

    # not using distinct T, ensure that the sizes are equivalent to the wrapped type
    assert LittleEndian[uint16].sizeof == uint16.sizeof
    assert LittleEndian[uint32].sizeof == uint32.sizeof
    assert LittleEndian[uint64].sizeof == uint64.sizeof

dtest "involution":
    # endian conversion has an involutory property
    # converting a value to LE, then converting that to NE should result
    # in the original value.
    for val in testData.fields:
        check val[0].toLE.toNE == val[0]

dtest "toLE/toNE":
    for val in testData.fields:
        when willCorrect:
            let input = val[0]
            let output = val[1]
            check cast[input.type](input.toLE) == output
        else:
            let input = val[0]
            check cast[input.type](input.toLE) == input
