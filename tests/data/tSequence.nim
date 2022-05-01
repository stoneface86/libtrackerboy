discard """
"""

import ../../src/trackerboy/data
import ../unittest_wrapper

unittests:

    test "$Sequence":
        var s: Sequence
        check $s == ""
        s.data = @[127u8]
        check $s == "127"
        s.data = @[1u8, 2, 3, 0xFF, 0x80]
        check $s == "1 2 3 -1 -128"
        s.loopIndex = some(1.ByteIndex)
        check $s == "1 | 2 3 -1 -128"
        s.loopIndex = some(200.ByteIndex)
        check $s == "1 2 3 -1 -128"
        s.setLen(0)
        check $s == ""
    
    test "parseSequence":
        template testImpl(str: string, d: seq[uint8], l = none(ByteIndex)): untyped =
            block:
                let s = str.parseSequence()
                check:
                    s.data == d
                    s.loopIndex == l
        testImpl "", default(seq[uint8])
        testImpl "  1 2   \t3  4\t", @[1u8, 2, 3, 4]
        testImpl "2 | 3 4", @[2u8, 3, 4], some(1.ByteIndex)
        testImpl "23sasd32sasd3@@$@21||23|2", @[23u8, 32, 3, 21, 23, 2], some(5.ByteIndex)
