
import testing
import libtrackerboy/common

testunit "common"
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

testclass "MixMode"

dtest "pan tests":
    check:
        not mixMute.pansLeft
        not mixMute.pansRight
        mixLeft.pansLeft
        not mixLeft.pansRight
        not mixRight.pansLeft
        mixRight.pansRight
        mixMiddle.pansLeft
        mixMiddle.pansRight
