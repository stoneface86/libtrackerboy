
import libtrackerboy/private/rgbasm

import unittest2

suite "rgbasm":

  test "hex literal":
    check:
      asmHexLiteral(42u8) == "$2A"
      asmHexLiteral(42u16) == "$002A"
      asmHexLiteral(42u32) == "$0000002A"

  test "string literal":
    check:
      asmString("test") == "\"test\""
      asmString("back\\slash") == "\"back\\\\slash\""
      asmString("whitespace\n\t\r") == "\"whitespace\\n\\t\\r\""
      asmString("\"quoted\"") == "\"\\\"quoted\\\"\""

  test "encode string":
    check:
      asmEncode("test") == "    DB \"test\""

  test "encode integers (single)":
    check:
      asmEncode(32u8)  == "    DB $20"
      asmEncode(32u16) == "    DW $0020"
      asmEncode(32u32) == "    DL $00000020"

  test "encode integers (array)":
    check:
      asmEncode([1u8, 2, 3, 4]) == "    DB $01, $02, $03, $04"
      asmEncode([1u16, 2, 3, 4]) == "    DW $0001, $0002, $0003, $0004"
      asmEncode([1u32, 2, 3, 4, 5, 6, 0]) == "    DL $00000001, $00000002, $00000003, $00000004, $00000005, $00000006, \\\n       $00000000"

  test "encode object":
    type
      Foo {.packed.} = object
        x: uint8
        y: uint8
        bar: uint16
        biz: uint32
    let foo = Foo(x: 0x11, y: 0x23, bar: 0xFFFF, biz: 0x67676767)
    check asmEncode(foo) == "    DB $11, $23, $FF, $FF, $67, $67, $67, $67"

  test "ds command":
    check:
      asmDs(23)   == "    DS 23"
      asmDs(1024) == "    DS 1024"

  test "comment":
    check:
      asmComment("test") == "    ; test"
      asmComment("test", false) == "; test"
