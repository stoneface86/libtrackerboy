
import ../testing
import libtrackerboy/private/utils

testunit "private/utils"
testclass "deepEquals"

type T = int


template setup(): untyped {.dirty.} =
  var a, b: ref T
  template checkEqual(): untyped {.used.} =
    check:
      deepEquals(a, b)
      deepEquals(b, a)
  template checkNotEqual(): untyped {.used.} =
    check:
      not deepEquals(a, b)
      not deepEquals(b, a)

dtest "equal when a, b are nil":
  setup
  checkEqual

dtest "not equal when a is nil, b is not nil":
  setup
  new(a)
  checkNotEqual

dtest "not equal when a is not nil, b is nil":
  setup
  new(b)
  checkNotEqual

dtest "not equal when a[] is 2, b[] is 3":
  setup
  new(a)
  new(b)
  a[] = 2
  b[] = 3
  checkNotEqual

dtest "equal when a[] and b[] are 2":
  setup
  new(a)
  new(b)
  a[] = 2
  b[] = 2
  checkEqual
