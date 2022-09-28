
# Package

version     = "0.0.1"
author      = "stoneface"
description = "libtrackerboy unit tests"
license     = "MIT"
binDir      = "../bin"
bin         = @["tester"]

# Dependencies

requires "nim >= 1.6.0"
requires "unittest2"

before install:
    raise newException(AssertionDefect, "cannot install this package!")
