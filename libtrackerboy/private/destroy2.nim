##[

.. include:: warning.rst

]##

#
# destroy2.nim
# 
# Allows writing Nim major 2 style `=destroy` hooks that work with Nim major
# 1. Nim major 2 changed the signature of the `=destroy` to take a single `T`
# argument instead of `var T`. When using the old signature Nim will complain
# with a warning, but will still compile it normally. Use this module to help
# with the migration to 2 by writing your `=destroy` hooks in the newer format.
# 
# This module provides a `destroy2` macro that can be used like a pragma. The
# macro changes the proc signature when `NimMajor` is less than 2, so that the
# first argument is a `var T` instead of `T`. When compiling with Nim 2 and up,
# the proc is left unchanged. This way you can write your destructors in the
# new format and it will compile without warnings on both Nim 1 and 2.
# 
# Author: Brennan Ringey (@stoneface86)
#

# 
# This is free and unencumbered software released into the public domain.
# 
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
# 
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
# 
# For more information, please refer to <https://unlicense.org>
#

const
  destroyTakesVarT* = NimMajor < 2
    ## Is true if the first parameter to `=destroy` procs are of `var T`.
    ##

when destroyTakesVarT:
  import std/macros

macro destroy2*(fn) =
  ## Nim 2.0.0 changes the =destroy hook to take a `T` parameter instead of
  ## `var T`. This macro rewrites the first parameter type to `var T` on Nim
  ## versions before 2.0.0, this way you only need to write a single `=destroy`
  ## hook.
  ##
  result = fn
  when destroyTakesVarT:
    # add var T
    let
      arg = fn.params[1]
      dTy = arg[1]
    arg[1] = newTree(nnkVarTy, dTy)
