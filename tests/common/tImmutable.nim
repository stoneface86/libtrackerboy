discard """
"""

import ../../src/trackerboy/common
import ../unittest_wrapper

type T = int

unittests:
    test "default Immutable[ref T] == nil":
        var iref: Immutable[ref T]
        check:
            iref.isNil
            iref == nil
            nil == iref
    
    test "default Immutable[T] == default(T)":
        var ival: Immutable[T]
        check:
            ival[] == default(T)

    test "Immutable[ref T] access":
        
        var ref1: ref T
        new(ref1)

        var iref = ref1.toImmutable
        check:
            iref[] == default(T)
            iref == ref1
            ref1 == iref

