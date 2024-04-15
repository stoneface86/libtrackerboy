##[

Module contains common types used throughout the library. This module is
exported by other modules so you typically do not need to import it yourself.

]##

type

  ChannelId* = enum
    ## Channel identifier. Used to specify a hardware channel of the game
    ## boy APU
    ##
    ch1
    ch2
    ch3
    ch4

  Tristate* = enum
    ## Enum of a generic state with three possible values, off/on and a
    ## transitional state.
    ##
    triOff    # "off" state
    triTrans  # transitional state, off -> on / on -> off
    triOn     # "on" state

  PcmF32* = float32
    ## 32-bit floating point PCM sample
    ##

  Pcm* = PcmF32
    ## Type alias for the PCM type used in this library
    ##

  ByteIndex* = range[0..255]
    ## Index type using the range of a uint8 (0-255)
    ## 
  
  PositiveByte* = range[1..256]
    ## Positive type using the range of a uint8 (1-256)
    ##

  Immutable*[T] = distinct T
    ## Wrapper type that forces immutability on T. Useful for `ref` or `ptr`
    ## types. Accessing the source is done through the `[]` overload proc.
    ## Both value and ref semantics can be used. When the source is a `ref`
    ## or `ptr`, accessing the source will dereference the ref/ptr.
    ##

  FixedSeq*[N: static int; T] = object
    ## Provides a `seq`-like data structure that only has a fixed capacity, `N`.
    ## Useful when you have a fixed number of items to store but you want to
    ## convenience of a `seq` with `array` style storage.
    ##
    data*: array[N, T]
      ## Storage location of items added to this seq.
      ##
    len*: int
      ## The length of the seq, or the number of items added to it. Must be in
      ## range `0..N`.
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
  ## Same as `i == lhs`
  ##
  i == lhs

template `==`*[T: ptr|ref](lhs: nil.typeof; rhs: Immutable[T]): bool =
  ## Same as `rhs.isNil()`
  ##
  rhs == lhs

template `==`*[T](a, b: Immutable[T]; ): bool =
  ## Test if the two immutables are equivalent. This just calls the `==` proc
  ## for T.
  ## 
  cast[T](a) == cast[T](b)

proc add*[N, T](s: var FixedSeq[N, T]; item: sink T) =
  ## Adds an item to the end of the quick list. An error will occur the list is
  ## at maximum capacity.
  ##
  s.data[s.len] = item
  inc s.len

template capacity*[N, T](s: FixedSeq[N, T]|typedesc[FixedSeq[N, T]]): int =
  ## Gets the capacity, or `q.data.len`, of this FixedSeq.
  ##
  N

template `[]`*[N, T](s: FixedSeq[N, T]; i: int): T =
  ## Access the `i`th element in the FixedSeq. 
  ##
  s.data[i]

iterator items*[N, T](s: FixedSeq[N, T]): T =
  ## Iterates all items in the FixedSeq.
  ##
  for i in 0..<s.len:
    yield s.data[i]

