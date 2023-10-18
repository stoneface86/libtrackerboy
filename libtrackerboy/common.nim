##[

Module contains common types used throughout the library. This module is
exported by other modules so you typically do not need to import it yourself.

]##

import std/bitops

type

  ChannelId* = enum
    ## Channel identifier. Used to specify a hardware channel of the game
    ## boy APU
    ##
    ch1
    ch2
    ch3
    ch4

  PcmF32* = float32
    ## 32-bit floating point PCM sample
    ##

  Pcm* = PcmF32
    ## Type alias for the PCM type used in this library
    ##

  ByteIndex* = range[low(uint8).int..high(uint8).int]
    ## Index type using the range of a uint8 (0-255)
    ## 
  
  PositiveByte* = range[1..high(uint8).int+1]
    ## Positive type using the range of a uint8 (1-256)
    ##

  MixMode* = enum
    ## Enum of possible mix operations: mute, left-only, right-only or
    ## middle (both).
    ##
    mixMute     = 0
    mixLeft     = 1
    mixRight    = 2
    mixMiddle   = mixLeft.ord or mixRight.ord

  Immutable*[T] = distinct T
    ## Wrapper type that forces immutability on T. Useful for `ref` or `ptr`
    ## types. Accessing the source is done through the [] overload proc.
    ## Both value and ref semantics can be used. When the source is a `ref`
    ## or `ptr`, accessing the source will dereference the ref/ptr.
    ##

template toImmutable*[T](s: T): Immutable[T] =
  ## Converts a value to an Immutable. Note that a copy of the value might
  ## be made.
  ##
  Immutable[T](s)

template getType[T](_: Immutable[T]): untyped = T

template `[]`*[T](i: Immutable[(ptr T) or (ref T)]): lent T =
  ## Access the Immutable's ref/ptr source. The source is dereferenced and
  ## is returned.
  ##
  runnableExamples:
    let myref = new(int)
    myref[] = 2
    let immutableRef = myref.toImmutable
    assert immutableRef[] == myref[]
    assert not compiles(immutableRef[] = 3)
  cast[getType(i)](i)[]

template `[]`*[T: not ptr|ref](i: Immutable[T]): lent T =
  ## Access the Immutable's value source.
  ##
  runnableExamples:
    let myval = 2
    let immutableVal = myval.toImmutable
    assert immutableVal[] == myval
    assert not compiles(immutableVal[] = 3)
  cast[T](i)

template isNil*[T](i: Immutable[(ptr T) or (ref T)]): bool =
  ## Test if the Immutable source is nil.
  ##
  cast[getType(i)](i).isNil

template `==`*[T](i: Immutable[T]; rhs: T): bool =
  ## Test if the Immutable's source is equivalent to the given value
  ##
  cast[T](i) == rhs

template `==`*[T](lhs: T; i: Immutable[T]): bool =
  i == lhs

template `==`*[T: ptr|ref](lhs: nil.typeof; rhs: Immutable[T]): bool =
  rhs == lhs

{. push inline, raises: [] .}

func pansLeft*(mode: MixMode): bool =
  ## Determine whether the mode pans left, returns `true` when mode is
  ## `mixLeft` or `mixMiddle`
  testBit(ord(mode), 0)

func pansRight*(mode: MixMode): bool =
  ## Determine whether the mode pans right, returns `true` when mode is
  ## `mixRight` or `mixMiddle`
  testBit(ord(mode), 1)

{. pop .}
