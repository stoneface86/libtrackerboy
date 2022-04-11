{.used.}

import std/unittest

import trackerboy/common

type T = int

test "default CRef[T] == nil":
    var cref: CRef[T]
    check:
        cref.isRef(nil)
        cref == nil
        nil == cref

test "CRef[T] access":
    
    var ref1: ref T
    new(ref1)

    var cref = ref1.toCRef
    check:
        cref[] == default(T)
        cref.isRef(ref1)
        cref == ref1
        ref1 == cref

