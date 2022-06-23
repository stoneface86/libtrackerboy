
import ../testing
import trackerboy/common

testclass "Immutable"

type T = int


dtest "default Immutable[ref T] == nil":
    var iref: Immutable[ref T]
    check:
        iref.isNil
        iref == nil
        nil == iref

dtest "default Immutable[T] == default(T)":
    var ival: Immutable[T]
    check:
        ival[] == default(T)

dtest "Immutable[ref T] access":
    
    var ref1: ref T
    new(ref1)

    var iref = ref1.toImmutable
    check:
        iref[] == default(T)
        iref == ref1
        ref1 == iref

