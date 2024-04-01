
import unittest2
import libtrackerboy/common

import std/sequtils

suite "Immutable[T]":

  type T = int

  test "default is nil when T is ref":
    var iref: Immutable[ref T]
    check:
      iref.isNil
      iref == nil
      nil == iref

  test "default Immutable[T] == default(T)":
    var ival: Immutable[T]
    check:
      ival[] == default(T)

  test "access when T is ref":
    
    var ref1: ref T
    new(ref1)

    var iref = ref1.toImmutable
    check:
      iref[] == default(T)
      iref == ref1
      ref1 == iref

  test "equality":
    var x = 2
    let
      a = x.toImmutable
      b = x.toImmutable
    check:
      a == b

suite "FixedSeq[N, T]":

  test "default init":
    var f: FixedSeq[10, int]
    check:
      f.len == 0
      f.capacity == 10
  
  test "add":
    var f: FixedSeq[10, int]
    f.add(1)
    check f.len == 1
    f.add(2)
    check f.len == 2
    f.add(3)
    check f.len == 3
    
    check:
      f[0] == 1
      f[1] == 2
      f[2] == 3

  test "items":
    var f: FixedSeq[5, int]
    check toSeq(f).len == 0
    f.add(-1)
    f.add(100)
    check toSeq(f) == @[-1, 100]
