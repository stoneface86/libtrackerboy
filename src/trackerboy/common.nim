##[

Module contains common types used throughout the library. This module is
exported by other modules so you typically do not need to import it yourself.

]##

import std/bitops

type
    InvalidOperationDefect* = object of Defect
        ## Defect class for any operation that cannot be performed.

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

    Immutable*[T] = object
        ## Container object that only provides immutable access to its source.
        ## Accessing the source is done through the [] overload proc. Both
        ## value and ref semantics can be used. When the source is a ref or
        ## ptr, accessing the source will dereference the ref/ptr.
        src: T

    Shallow*[T] {.shallow.} = object
        ## Wrapper type to allow shallow copying on T. Suitable for avoiding
        ## wasteful copies being made when viewing data.
        src*: T
            ## The source data. When a Shallow[T] object is copied, the compiler
            ## may make a shallow copy (ie only copying the pointer for seqs).

    EqRef*[T] = object
        ## EqRef: Deep equality ref
        ## 
        ## Ref wrapper type that changes the equality operator by testing for
        ## deep equality.
        src*: ref T
            ## The source reference of the wrapper

func toShallow*[T](src: sink T): Shallow[T] {.inline.} =
    ## Converts a value to a Shallow. The compiler is free to make shallow
    ## copies of the returned object.
    Shallow[T](src: src)

func toImmutable*[T](src: sink T): Immutable[T] =
    ## Converts a value to an Immutable. Note that a copy of the value might
    ## be made.
    Immutable[T](src: src)

func `[]`*[T](i: Immutable[(ptr T) or (ref T)]): lent T =
    ## Access the Immutable's ref/ptr source. The source is dereferenced and
    ## is returned.
    runnableExamples:
        let myref = new(int)
        myref[] = 2
        let immutableRef = myref.toImmutable
        assert immutableRef[] == myref[]
        assert not compiles(immutableRef[] = 3)
    i.src[]

func `[]`*[T: not ptr|ref](i: Immutable[T]): lent T =
    ## Access the Immutable's value source. Lent is used so a copy can be
    ## avoided.
    runnableExamples:
        let myval = 2
        let immutableVal = myval.toImmutable
        assert immutableVal[] == myval
        assert not compiles(immutableVal[] = 3)
    i.src

func isNil*[T](i: Immutable[(ptr T) or (ref T)]): bool =
    ## Test if the Immutable source is nil.
    i.src.isNil()

func `==`*[T](i: Immutable[T], rhs: T): bool =
    ## Test if the Immutable's source is equivalent to the given value
    i.src == rhs

template `==`*[T](lhs: T, i: Immutable[T]): bool =
    i == lhs

template `==`*[T: ptr|ref](lhs: nil.typeof, rhs: Immutable[T]): bool =
    rhs == lhs

func deepEquals*[T](a, b: ref T): bool =
    ## Deep equality test for two refs. Returns true if either:
    ## - they are both nil
    ## - they are not both nil and their referenced data is equivalent
    runnableExamples:
        var a, b: ref int
        assert a.deepEquals(b)      # both are nil
        a = new(int)
        b = new(int)
        a[] = 2
        b[] = 3
        assert not a.deepEquals(b)  # both are not nil, but the referenced data are not the same
        b[] = a[]
        assert a.deepEquals(b)      # both are not nil and the referenced data are the same
        b = nil
        assert not a.deepEquals(b)  # one of the refs is nil

    if a.isNil:
        # return true if both are nil
        b.isNil
    elif b.isNil:
        # lhs is not nil but rhs is nil
        false
    else:
        # check if the referenced data is equal (deep equality)
        a[] == b[]

func toEqRef*[T](val: ref T): EqRef[T] =
    ## Converts a ref to an EqRef
    EqRef[T](src: val)

template `==`*[T](lhs, rhs: EqRef[T]): bool =
    ## Equality test using deepEquals
    runnableExamples:
        var a, b: EqRef[int]
        assert a == b
    lhs.src.deepEquals(rhs.src)

func pansLeft*(mode: MixMode): bool {.inline.} =
    ## Determine whether the mode pans left, returns `true` when mode is
    ## `mixLeft` or `mixMiddle`
    testBit(ord(mode), 0)

func pansRight*(mode: MixMode): bool {.inline.} =
    ## Determine whether the mode pans right, returns `true` when mode is
    ## `mixRight` or `mixMiddle`
    testBit(ord(mode), 1)
