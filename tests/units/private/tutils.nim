
#import ../testing
import libtrackerboy/private/utils

import unittest2

type T = int

suite "deepEquals":
  setup:
    var a, b: ref T
    template checkEqual(): untyped {.used.} =
      check:
        deepEquals(a, b)
        deepEquals(b, a)
    template checkNotEqual(): untyped {.used.} =
      check:
        not deepEquals(a, b)
        not deepEquals(b, a)
  
  test "equal when a, b are nil":
    checkEqual

  test "equal when a, b are the same reference":
    new(a)
    b = a
    checkEqual

  test "not equal when a is nil, b is not nil":
    new(a)
    checkNotEqual

  test "not equal when a is not nil, b is nil":
    new(b)
    checkNotEqual

  test "not equal when a[] is 2, b[] is 3":
    new(a)
    new(b)
    a[] = 2
    b[] = 3
    checkNotEqual

  test "equal when a[] and b[] are 2":
    new(a)
    new(b)
    a[] = 2
    b[] = 2
    checkEqual
