##[

Module contains common types used throughout the library. This module is
exported by other modules so you typically do not need to import it yourself.

]##

import std/bitops

type
    InvalidOperationDefect* = object of Defect
        ## Defect class for any operation that cannot be performed.

    CRef*[T] = object
        ## CRef: Const Ref
        ## 
        ## Ref wrapper providing immutable access to the ref's data
        ## Inspired by C++'s `std::shared_ptr<const T>`
        ## Should be functionally similar to a `ref T` (minus the implicit derefencing)
        src: ref T

    ChannelId* = enum
        ch1
        ch2
        ch3
        ch4

    PcmF32* = float32
        ## 32-bit floating point PCM sample

    Pcm* = PcmF32
        ## Type alias for the PCM type used in this library

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

    EqRef*[T] = object
        ## EqRef: Deep equality ref
        ## 
        ## Ref wrapper type that changes the equality operator by testing for
        ## deep equality.
        src*: ref T
            ## The source reference of the wrapper

func toCRef*[T](src: sink ref T): CRef[T] {.inline.} =
    ## Convert a ref to a CRef
    result = CRef[T](src: src)

func `[]`*[T](cref: CRef[T]): lent T {.inline.} =
    ## Dereference operator for the CRef. Just like plain refs, does not check
    ## for nil!
    runnableExamples:
        let myref = new(int)
        myref[] = 2
        let mycref = myref.toCRef
        assert myref[] == mycref[]
        assert not compiles(mycref[] = 3)
    cref.src[]

func isRef*[T](cref: CRef[T], data: ref T): bool {.inline.} =
    ## Check if the CRef's reference is equal to the given one
    runnableExamples:
        let myref = new int
        let mycref = myref.toCRef
        assert mycref.isRef(myref)
    cref.src == data

template `==`*[T](cref: CRef[T], data: ref T): bool =
    ## Shortcut for `isRef<#isRef,CRef[T],ref T>`_ using the `==` operator
    runnableExamples:
        let cref = default(CRef[int])
        assert cref == nil
    cref.isRef(data)

template `==`*[T](data: ref T, cref: CRef[T]): bool =
    ## Shortcut for `isRef<#isRef,CRef[T],ref T>`_ using the `==` operator
    runnableExamples:
        let cref = default(CRef[int])
        assert nil == cref
    cref.isRef(data)

template noRef*(T: typedesc): CRef[T] =
    ## returns a CRef of type T with no reference set (nil). Same as doing
    ## `nil.toCRef[T]`
    runnableExamples:
        assert noRef(int) == toCRef[int](nil)
    toCRef[T](nil)

func isNil*[T](cref: CRef[T]): bool =
    ## Overload for the system module's `isNil`. Returns `true` if the cref's
    ## source reference is `nil`
    cref.src.isNil()

func toEqRef*[T](val: ref T): EqRef[T] {.inline.} =
    EqRef[T](src: val)

func `==`*[T](lhs, rhs: EqRef[T]): bool =
    ## Equality test for the given EqRefs. The refs are equal if either:
    ## - they are both nil
    ## - they are not both nil and their referenced data is equivalent
    runnableExamples:
        var a, b: EqRef[int]
        assert a == b   # both are nil
        a.src = new(int)
        b.src = new(int)
        a.src[] = 2
        b.src[] = 3
        assert a != b   # both are not nil, but the referenced data are not the same
        b.src[] = a.src[]
        assert a == b   # both are not nil and the referenced data are the same
        b.src = nil
        assert a != b   # one of the refs is nil

    if lhs.src.isNil:
        # return true if both are nil
        rhs.src.isNil
    elif rhs.src.isNil:
        # lhs is not nil but rhs is nil
        false
    else:
        # check if the referenced data is equal (deep equality)
        lhs.src[] == rhs.src[]

func pansLeft*(mode: MixMode): bool {.inline.} =
    ## Determine whether the mode pans left, returns `true` when mode is
    ## `mixLeft` or `mixMiddle`
    testBit(ord(mode), 0)

func pansRight*(mode: MixMode): bool {.inline.} =
    ## Determine whether the mode pans right, returns `true` when mode is
    ## `mixRight` or `mixMiddle`
    testBit(ord(mode), 1)
