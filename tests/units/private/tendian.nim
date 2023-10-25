
# the inverse endian tests allow us to mock the endian opposite to the system's
# endian.


import libtrackerboy/private/endian

import unittest2

const testData = (
  [0x1234'u16,             0x3412'u16],
  [-1'i16,                 -1'i16],
  [0x12345678'u32,         0x78563412'u32],
  [-2126381057'i32,        -48767'i32],
  [0xDEADCAFEBABEBEEF'u64, 0xEFBEBEBAFECAADDE'u64],
  [1.25e1'f32,             2.591982e-41'f32]
)

func involutionTest[T: SomeWord](val: T): bool =
  val.toLE.toNE == val

func sameSize(T: typedesc[SomeWord]): bool =
  LittleEndian[T].sizeof == T.sizeof

static:
  # test that toLE and toNE can be called statically
  for val in testData.fields:
    assert involutionTest(val[0])

  # not using distinct T, ensure that the sizes are equivalent to the wrapped type
  assert sameSize(int16)
  assert sameSize(uint16)
  assert sameSize(int32)
  assert sameSize(uint32)
  assert sameSize(int64)
  assert sameSize(uint64)
  assert sameSize(float32)
  assert sameSize(float64)


test "involution":
  # endian conversion has an involutory property
  # converting a value to LE, then converting that to NE should result
  # in the original value.
  for val in testData.fields:
    check involutionTest(val[0])

test "toLE/toNE":
  for val in testData.fields:
    when willCorrect:
      let input = val[0]
      let output = val[1]
      check cast[input.type](input.toLE) == output
    else:
      let input = val[0]
      check cast[input.type](input.toLE) == input
