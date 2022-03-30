##
## Module contains common types used throughout the library.
## 

type
    InvalidOperationDefect* = object of Defect
        ## Defect class for any operation that cannot be performed.

    CRef*[T] = object
        ## CRef: Const Ref
        ## Ref wrapper providing immutable access to the reference
        ## Inspired by C++'s `std::shared_ptr<const T>`
        ## Should be functionally similar to a `ref T` (minus the implicit derefencing)
        data: ref T

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
