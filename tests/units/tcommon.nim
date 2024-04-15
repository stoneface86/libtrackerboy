
import unittest2
import libtrackerboy/common

import std/sequtils

suite "iref[T]":

  type T = int

  test "default is nil when T is ref":
    var iref: iref[T]
    check:
      iref.isNil
      iref == nil
      nil == iref

  test "dereferencing":
    var
      mref = new(T)
      iref = immutable(mref)
    mref[] = 2
    check iref[] == 2

  test "equality":
    var x = new(int)
    let
      a = immutable(x)
      b = immutable(x)
    check:
      a == b
      b == a
      a == x
      x == a
      b == x
      x == b

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
