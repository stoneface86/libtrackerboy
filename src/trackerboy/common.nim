##
## Module contains common types used throughout the library.
## 

import std/bitops

const
    ch1* = 0
    ch2* = 1
    ch3* = 2
    ch4* = 3

type
    InvalidOperationDefect* = object of Defect
        ## Defect class for any operation that cannot be performed.

    CRef*[T] = object
        ## CRef: Const Ref
        ## Ref wrapper providing immutable access to the reference
        ## Inspired by C++'s `std::shared_ptr<const T>`
        ## Should be functionally similar to a `ref T` (minus the implicit derefencing)
        data: ref T

    PcmF32* = float32
        ## 32-bit floating point PCM sample

    Pcm* = PcmF32
        ## Type alias for the PCM type used in this library

    ChannelId* = range[ch1..ch4]
        ## Integer ID type for a channel. A ChannelId of 0 is CH1, 1 is CH2,
        ## 2 is CH3 and 3 is CH4.

    ByteIndex* = range[low(uint8).int..high(uint8).int]
        ## Index type using the range of a uint8 (0-255)
    
    PositiveByte* = range[1..high(uint8).int+1]
        ## Positive type using the range of a uint8 (1-256)

    MixMode* = enum
        ## Enum of possible mix operations: mute, left-only, right-only or
        ## middle (both).
        mixMute     = 0
        mixLeft     = 1
        mixRight    = 2
        mixMiddle   = mixLeft.ord or mixRight.ord

    DeepEqualsRef*[T] = object
        # Ref wrapper type providing an == overload that compares the value of
        # the ref
        data*: ref T

func toCRef*[T](src: sink ref T): CRef[T] {.inline.} =
    ## Convert a ref to a CRef
    result = CRef[T](data: src)

func `[]`*[T](cref: CRef[T]): lent T {.inline.} =
    ## Dereference operator for the CRef. Just like plain refs, does not check for nil!
    cref.data[]

func isRef*[T](cref: CRef[T], data: ref T): bool {.inline.} =
    ## Check if the CRef's reference is equal to the given one
    cref.data == data

template `==`*[T](cref: CRef[T], data: ref T): bool =
    cref.isRef(data)

template `==`*[T](data: ref T, cref: CRef[T]): bool =
    cref.isRef(data)

template noRef*(T: typedesc): CRef[T] =
    ## returns a CRef of type T with no reference set (nil). Same as doing
    ## `nil.toCRef[T]`
    toCRef[T](nil)

func deepEqualsRef*[T](val: ref T): DeepEqualsRef[T] {.inline.} =
    DeepEqualsRef[T](data: val)

func `==`*[T](lhs, rhs: DeepEqualsRef[T]): bool =
    if lhs.data.isNil:
        rhs.data.isNil
    elif rhs.data.isNil:
        false
    else:
        lhs.data[] == rhs.data[]

func pansLeft*(mode: MixMode): bool {.inline.} =
    testBit(ord(mode), 0)

func pansRight*(mode: MixMode): bool {.inline.} =
    testBit(ord(mode), 1)
