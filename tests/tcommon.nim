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

test "noRef(T)":
    var ref1: CRef[T]
    check:
        ref1 == noRef(T)
        nil == noRef(T)

static:
    assert not mixMute.pansLeft
    assert not mixMute.pansRight
    assert mixLeft.pansLeft
    assert not mixLeft.pansRight
    assert not mixRight.pansLeft
    assert mixRight.pansRight
    assert mixMiddle.pansLeft
    assert mixMiddle.pansRight
