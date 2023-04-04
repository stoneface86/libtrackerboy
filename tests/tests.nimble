
# Package

version     = "0.0.1"
author      = "stoneface"
description = "libtrackerboy unit tests"
license     = "MIT"
binDir      = "../bin"
bin         = @["tests", "endianTests"]

# Dependencies

requires "nim >= 1.6.0"
requires "unittest2 >= 0.0.6"

before install:
  raise newException(AssertionDefect, "cannot install this package!")
