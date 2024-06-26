##[
.. include:: warning.rst
]##

template ptrArith*(body: untyped) =
  #
  # Provides pointer arithmetic operators for the enclosing body.
  # Be sure you know what you're doing! Code within this body is
  # unsafe.
  #

  # {.used.} prevents compiler warnings if you don't use all of the operators
  # in a body ;)

  template `+`[T](p: ptr T; off: int): ptr T {.used.} =
    cast[ptr T](cast[int](p) +% off * sizeof(T))

  template `+=`[T](p: ptr T; off: int) {.used.} =
    p = p + off
  
  template `-`[T](p: ptr T; off: int): ptr T {.used.} =
    cast[ptr T](cast[int](p) -% off * sizeof(T))
  
  template `-=`[T](p: ptr T; off: int) {.used.} =
    p = p - off
  
  template `[]`[T](p: ptr T; off: int): T {.used.} =
    (p + off)[]
  
  template `[]=`[T](p: ptr T; off: int; val: T) {.used.} =
    (p + off)[] = val

  template inc[T](p: var ptr T) {.used.} = p += 1
  
  template dec[T](p: var ptr T) {.used.} = p -= 1

  body
