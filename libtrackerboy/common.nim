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

  iref*[T] = distinct ref T
    ## Immutable reference type. This is a wrapper for a `ref T` that only
    ## allows immutable access to the referenced data.
    ##

  iptr*[T] = distinct ptr T
    ## Immutable pointer type. Like [iref], this is a wrapper for `ptr T` that
    ## only allows immutable access to the referenced data.
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

# iref

template get[T](x: iref[T]): ref T =
  cast[ref T](x)

template get[T](x: iptr[T]): ptr T =
  cast[ptr T](x)

template immutable*[T](x: ref T): iref[T] =
  ## Converts a `ref` to an [iref], an immutable ref.
  ##
  iref[T](x)

template immutable*[T](x: ptr T): iptr[T] =
  ## Converts a `ptr` to an [iptr], an immutable ptr.
  ##
  iptr[T](x)

template `==`*[T](x, y: iref[T]; ): bool =
  `==`(get(x), get(y))

template `==`*[T](x, y: iptr[T]; ): bool =
  `==`(get(x), get(y))

template `==`*[T](x: ref T; y: iref[T]): bool =
  `==`(x, get(y))

template `==`*[T](x: ptr T; y: iptr[T]): bool =
  `==`(x, get(y))

template `==`*[T](x: iref[T]; y: ref T): bool =
  `==`(y, x)

template `==`*[T](x: iptr[T]; y: ptr T): bool =
  `==`(y, x)

template isNil*[T](x: iref[T]): bool =
  isNil(get(x))

template isNil*[T](x: iptr[T]): bool =
  isNil(get(x))

template `==`*[T](x: iref[T]; y: typeOf(nil)): bool =
  isNil(get(x))

template `==`*[T](x: iptr[T]; y: typeOf(nil)): bool =
  isNil(get(x))

template `==`*[T](x: typeOf(nil); y: iref[T]): bool =
  isNil(get(y))

template `==`*[T](x: typeOf(nil); y: iptr[T]): bool =
  isNil(get(y))

template `[]`*[T](x: iref[T]): lent T =
  ## Dereference the [iref].
  ##
  runnableExamples:
    let myref = new(int)
    myref[] = 2
    let immutableRef = immutable(myref)
    assert immutableRef[] == 2
    assert not compiles(immutableRef[] = 3)
  get(x)[]

template `[]`*[T](x: iptr[T]): lent T =
  ## Dereference the [iptr].
  ##
  runnableExamples:
    var x = 2
    let ptrX = immutable(addr(x))
    assert ptrX[] == 2
    assert not compiles(ptrX[] = 3)
  get(x)[]


# FixedSeq

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

