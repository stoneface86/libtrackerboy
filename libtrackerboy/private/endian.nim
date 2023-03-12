##[

.. include:: warning.rst

]##

# Endian conversion module. Converts native endian words to little endian and
# vice-versa.

# I am aware std/endians exists, however it's API is unstable (and awkward to
# use, why pointers?)
# stew/endians2 is a much better replacement, but I do not require all of its
# features. Using their swapBytesNim funcs alongside my implementation (I only
# care about little endian conversion)

{.push raises: [].}

# byte swapping is only necessary when this bool is true
# the tbEndianInverse is for testing purposes only
when defined(tbEndianInverse):
  const willCorrect* = cpuEndian != bigEndian
else:
  const willCorrect* = cpuEndian == bigEndian

when willCorrect:
  const useBuiltins = not defined(noIntrinsicsEndians)
  
  # byte swap reference functions, in pure nim

  func bswapReference(val: uint16): uint16 =
    # stew/endians2 swapBytesNim(uint16)
    (val shl 8) or (val shr 8)

  func bswapReference(val: uint32): uint32 =
    # stew/endians2 swapBytesNim(uint32)
    let v = (val shl 16) or (val shr 16)
    ((v shl 8) and 0xff00ff00'u32) or ((v shr 8) and 0x00ff00ff'u32)

  func bswapReference(val: uint64): uint64 =
    # stew/endians2 swapBytesNim(uint64)
    var v = (val shl 32) or (val shr 32)
    v =
      ((v and 0x0000ffff0000ffff'u64) shl 16) or
      ((v and 0xffff0000ffff0000'u64) shr 16)
    ((v and 0x00ff00ff00ff00ff'u64) shl 8) or
      ((v and 0xff00ff00ff00ff00'u64) shr 8)

  # builtin versions via compiler instrinsics
  # support depends on the backend compiler, can be disabled with -d:noIntrinsicEndians

  when useBuiltins and (defined(gcc) or defined(llvm_gcc) or defined(clang)):

    func bswapBuiltin(a: uint16): uint16 {.
      importc: "__builtin_bswap16", nodecl.}

    func bswapBuiltin(a: uint32): uint32 {.
      importc: "__builtin_bswap32", nodecl.}

    func bswapBuiltin(a: uint64): uint64 {.
      importc: "__builtin_bswap64", nodecl.}

  elif useBuiltins and defined(icc):

    func bswapBuiltin(a: uint16): uint16 {.
      importc: "_bswap16", nodecl.}

    func bswapBuiltin(a: uint32): uint32 {.
      importc: "_bswap", nodecl.}

    func bswapBuiltin(a: uint64): uint64 {.
      importc: "_bswap64", nodecl.}

  elif useBuiltins and defined(vcc):

    func bswapBuiltin(a: uint16): uint16 {.
      importc: "_byteswap_ushort", nodecl, header: "<intrin.h>".}

    func bswapBuiltin(a: uint32): uint32 {.
      importc: "_byteswap_ulong", nodecl, header: "<intrin.h>".}

    func bswapBuiltin(a: uint64): uint64 {.
      importc: "_byteswap_uint64", nodecl, header: "<intrin.h>".}
  else:
    # builtins are not available, or were disabled
    # use the reference ones instead
    template bswapBuiltin(a: uint16): uint16 = bswapReference(a)
    template bswapBuiltin(a: uint32): uint32 = bswapReference(a)
    template bswapBuiltin(a: uint64): uint64 = bswapReference(a)

# philosophy notes
# should uint8 be included in SomeWord? Since endianess only applies to
# multi-byte datatypes, uint8 can be omitted from endianess conversion.
# Including it, however, would allow for easier generics.

# LittleEndian[T] allows us to use the type system to enforce correctness, but
# could be cumbersome to use.

# intxx types are omitted from SomeWord in case nim does overflow/underflow
# checks. libtrackerboy doesn't use signed integers for serialization at all so
# this feature isn't necessary for us.

# toLE and toNE are annotated with inline since these functions just call the
# bswap function or just the return the value given.

type
  # intxx are omitted due to overflow/underflow checks
  SomeWord* = uint16|uint32|uint64
    # Type class for a multi-byte integer
  LittleEndian*[T: SomeWord] {.packed.} = object
    # Type containing a word in little-endian byte order
    data: T

  # not using distinct T since nim has some issue with that
  # we could provide BigEndian[T] as well but it wouldn't be used by this library

template correct[T: SomeWord](val: T): T =
  when willCorrect:
    # native endian is big endian, return the byte swapped val
    when nimvm:
      # allows for compile-time evalulation
      bswapReference(val)
    else:
      bswapBuiltin(val)
  else:
    # native endian is little endian, no need to byte swap
    val

func toLE*[T: SomeWord](val: T): LittleEndian[T] {.inline.} =
  # Convert some word to little endian representation (LE).
  LittleEndian[T](data: correct(val))
  # when `LittleEndian[T]` is `distinct T`, this fails:
  #   correct(val).LittleEndian[T]

func toNE*[T: SomeWord](val: LittleEndian[T]): T {.inline.} =
  # Convert the word, in little endian representation, to native endian (NE).
  correct(val.data)

{.pop.}
