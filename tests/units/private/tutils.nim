
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

testclass "Shallow"


func sameBuffer(lhs, rhs: seq|string): bool =
    if lhs.len > 0 and rhs.len > 0:
        result = lhs[0].unsafeAddr == rhs[0].unsafeAddr

type
    Foo = object
        items: seq[int]
        str: string
        num: int

dtest "string":
    let str = "test".toShallow
    let strCopy = str

    check:
        str == strCopy
        sameBuffer(str.src, strCopy.src)

dtest "seq[int]":
    let first = @[1,2,3].toShallow
    let copy = first

    check:
        first == copy
        sameBuffer(first.src, copy.src)

dtest "Foo":
    let foo = Foo(items: @[1, 2, 3], str: "foo", num: 5).toShallow
    let fooCopy = foo

    check:
        foo == fooCopy
        sameBuffer(foo.src.items, fooCopy.src.items)
        sameBuffer(foo.src.str, fooCopy.src.str)
        foo.src.num == fooCopy.src.num
