
import ../testing
import libtrackerboy/common

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
